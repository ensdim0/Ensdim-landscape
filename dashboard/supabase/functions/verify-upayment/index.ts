// verify-upayment — marks a payment as paid after WebView redirect.
// Called from Flutter after the UPayments return URL is intercepted.
//
// Logic:
//   1. If trackId provided → call UPayments status API server-to-server and
//      trust ONLY that response (never the client-supplied resultFromUrl —
//      a caller with just the anon key + a paymentId could otherwise forge
//      "paid" with no real payment).
//   2. Update DB: gateway_status='paid', payment_method='gateway', payment_date=today.
//   3. Notify client (push + in-app) and all admins (in-app) — mirrors
//      upayment-webhook so confirmation isn't missed if the webhook is delayed/down.
//
// This is a convenience double-check for the client UI right after redirect —
// upayment-webhook (server-to-server, HMAC-verified) remains the authoritative
// source of truth for marking payments paid.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Sandbox/production is admin-configurable at runtime (see get_upayments_sandbox_mode RPC,
// toggled from the "بوابة الدفع" switch in the dashboard). UPAYMENTS_SANDBOX below is only
// the fallback used if that DB read fails.
const UPAYMENTS_SANDBOX_ENV   = Deno.env.get("UPAYMENTS_SANDBOX") === "true";
const UPAYMENTS_API_TOKEN_ENV = Deno.env.get("UPAYMENTS_API_TOKEN") ?? "";
const SUPABASE_URL  = Deno.env.get("SUPABASE_URL")             ?? "";
const SERVICE_KEY   = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const FEE_AMOUNT    = parseFloat(Deno.env.get("UPAYMENTS_FEE_AMOUNT") ?? "0.13");
const NOTIFICATION_SECRET = Deno.env.get("NOTIFICATION_SECRET") ?? "";

const cors = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUCCESS_CODES = new Set(["CAPTURED", "Y", "SUCCESS", "PAID", "DONE"]);

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  // ── Parse body ──────────────────────────────────────────────────────────────
  // Note: resultFromUrl (the return-URL result code) is intentionally NOT read
  // here — it's client-supplied and was previously trusted directly, which let
  // anyone holding a paymentId forge a "paid" result. Only trackId is used, and
  // only to look up the real status server-to-server via the UPayments API.
  let paymentId: string, paymentType: "contract" | "standalone";
  let trackId: string | undefined;

  try {
    const body    = await req.json();
    paymentId     = body.paymentId   as string;
    paymentType   = body.paymentType as "contract" | "standalone";
    trackId       = body.trackId     as string | undefined;
    if (!paymentId || !paymentType) throw new Error("missing paymentId or paymentType");
  } catch (e) {
    return new Response(`Bad Request: ${(e as Error).message}`, { status: 400, headers: cors });
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false },
  });

  const table = paymentType === "contract" ? "contract_payments" : "standalone_task_payments";

  // ── Fetch payment row ────────────────────────────────────────────────────────
  // contract_id only exists on contract_payments — not on standalone_task_payments
  const selectFields = paymentType === "contract"
    ? "id, amount, gateway_status, payment_gateway_order_id, contract_id, tenant_id"
    : "id, amount, gateway_status, payment_gateway_order_id, task_id, tenant_id";

  const { data: row } = await supabase
    .from(table)
    .select(selectFields)
    .eq("id", paymentId)
    .maybeSingle();

  if (!row) {
    return new Response(JSON.stringify({ verified: false, reason: "not found" }), {
      status: 404, headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  const tenantId = (row as any).tenant_id as string | null;

  let tenantCreds: { api_token: string | null } | null = null;
  if (tenantId) {
    const { data: credsData } = await supabase.rpc("get_tenant_payment_credentials", { p_tenant_id: tenantId });
    tenantCreds = Array.isArray(credsData) ? (credsData[0] ?? null) : credsData;
  }

  // Fee amount is admin-configurable at runtime (see get_upayments_fee_amount RPC).
  // Fall back to the env-var default if the read fails for any reason.
  let feeAmountSetting = FEE_AMOUNT;
  try {
    const { data: feeAmountData } = await supabase.rpc("get_upayments_fee_amount", { p_tenant_id: tenantId });
    if (typeof feeAmountData === "number") feeAmountSetting = feeAmountData;
  } catch (e) {
    console.warn("[verify-upayment] get_upayments_fee_amount failed, using env default:", e);
  }

  // Sandbox/production is admin-configurable at runtime (see get_upayments_sandbox_mode RPC).
  // Fall back to the env-var default if the read fails for any reason.
  let isSandbox = UPAYMENTS_SANDBOX_ENV;
  try {
    const { data: sandboxData } = await supabase.rpc("get_upayments_sandbox_mode", { p_tenant_id: tenantId });
    if (typeof sandboxData === "boolean") isSandbox = sandboxData;
  } catch (e) {
    console.warn("[verify-upayment] get_upayments_sandbox_mode failed, using env default:", e);
  }

  const API_TOKEN   = isSandbox
    ? (tenantCreds?.api_token || UPAYMENTS_API_TOKEN_ENV || "jtest123")
    : (tenantCreds?.api_token || UPAYMENTS_API_TOKEN_ENV);
  const STATUS_BASE = isSandbox
    ? "https://sandboxapi.upayments.com/api/v1/get-payment-status"
    : "https://uapi.upayments.com/api/v1/get-payment-status";

  // Already confirmed — return early
  if (row.gateway_status === "paid") {
    return new Response(JSON.stringify({ verified: true, gateway_status: "paid" }), {
      status: 200, headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  // ── Determine if paid ────────────────────────────────────────────────────────
  let isPaid    = false;
  let feeAmount = 0;
  let payMethod = "";

  // Server-to-server status check via UPayments API using trackId — the only
  // source of truth here (never trust a client-supplied result code).
  if (trackId) {
    try {
      const res  = await fetch(`${STATUS_BASE}/${encodeURIComponent(trackId)}`, {
        headers: { Authorization: `Bearer ${API_TOKEN}`, Accept: "application/json" },
      });
      const json = await res.json() as Record<string, unknown>;
      console.log(`[verify-upayment] status API:`, JSON.stringify(json).substring(0, 300));

      const txn    = (((json?.data as Record<string, unknown>)?.transaction) as Record<string, unknown>) ?? {};
      const txRes  = ((txn.result ?? txn.status ?? "") as string).toUpperCase();
      const txFee  = parseFloat(String(txn.feeAmount ?? txn.fee ?? 0));
      payMethod    = (txn.payment_type ?? txn.paymentType ?? "") as string;

      if (SUCCESS_CODES.has(txRes)) {
        isPaid    = true;
        feeAmount = txFee;
      }
    } catch (e) {
      console.warn("[verify-upayment] status API error:", e);
    }
  }

  // ── Update DB if paid ────────────────────────────────────────────────────────
  if (isPaid) {
    const amount    = row.amount as number;
    const fee       = feeAmount > 0 ? feeAmount : feeAmountSetting;
    const today     = new Date().toISOString().split("T")[0];

    const { error } = await supabase.from(table).update({
      gateway_status:     "paid",
      payment_method:     "gateway",
      payment_date:       today,
      due_date:           null,   // clear schedule date — payment is done
      gateway_fee_amount: fee,
      ...(payMethod ? { gateway_payment_method: payMethod } : {}),
    }).eq("id", paymentId);

    if (error) {
      console.error("[verify-upayment] DB update error:", error.message);
    } else {
      console.log(`[verify-upayment] marked paid: ${paymentId}`);
    }

    // For standalone: also update the task itself
    const taskId = (row.task_id as string | null) ?? "";
    if (paymentType === "standalone" && taskId) {
      await supabase.from("standalone_tasks")
        .update({ payment_status: "paid", payment_method: "gateway" })
        .eq("id", taskId);
    }

    // ── Notify client + admins (same as upayment-webhook). The "already paid"
    // early-return above on both this function and the webhook makes this
    // idempotent regardless of which path confirms the payment first. ───────
    if (!error) {
      const contractId = paymentType === "contract" ? ((row as any).contract_id as string | null) : null;
      let clientUserId: string | null = null;
      let contractCode: string | null = null;
      let clientName: string | null = null;
      let totalPaid: number = amount;
      let remaining: number | null = null;

      if (contractId) {
        const { data: contract } = await supabase
          .from("contracts")
          .select("user_id, code, total_value")
          .eq("id", contractId)
          .maybeSingle();
        clientUserId = (contract?.user_id as string | null) ?? null;
        contractCode = (contract?.code    as string | null) ?? null;

        if (clientUserId) {
          const { data: clientUser } = await supabase
            .from("users")
            .select("full_name")
            .eq("id", clientUserId)
            .maybeSingle();
          clientName = (clientUser?.full_name as string | null) ?? null;
        }

        const { data: contractPayments } = await supabase
          .from("contract_payments")
          .select("amount, gateway_status, due_date")
          .eq("contract_id", contractId);

        totalPaid = (contractPayments ?? [])
          .filter((p: Record<string, unknown>) => p.gateway_status === "paid" || (!p.gateway_status && !p.due_date))
          .reduce((sum: number, p: Record<string, unknown>) => sum + Number(p.amount ?? 0), 0);

        if (contract?.total_value != null) {
          remaining = Number(contract.total_value) - totalPaid;
        }
      }

      if (clientUserId) {
        await supabase.from("notifications").insert({
          user_id: clientUserId,
          title:   "تم استلام دفعتك بنجاح ✓",
          body:    `تم تأكيد دفع مبلغ ${amount.toFixed(3)} KWD.`,
          meta: {
            type:        "payment_confirmed",
            payment_id:  paymentId,
            contract_id: contractId,
            amount,
          },
        });

        await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
          method: "POST",
          headers: {
            "Content-Type":          "application/json",
            "Authorization":         `Bearer ${SERVICE_KEY}`,
            "x-notification-secret": NOTIFICATION_SECRET,
          },
          body: JSON.stringify({
            clientId:    clientUserId,
            notifType:   "payment_confirmed",
            paymentId,
            paymentType,
            amount,
            contractId:  contractId ?? undefined,
          }),
        }).catch((e) => console.warn("[verify-upayment] push failed:", e));
      }

      const { data: adminRoles } = await supabase
        .from("user_roles")
        .select("user_id, roles!inner(name), users!inner(tenant_id)")
        .eq("roles.name", "admin")
        .eq("users.tenant_id", tenantId as string);

      if (adminRoles?.length) {
        const totalPaidLabel = totalPaid.toFixed(3);
        const remainingLabel = remaining != null ? remaining.toFixed(3) : null;
        const body = `العميل ${clientName ?? "غير معروف"} دفع ${amount.toFixed(3)} KWD عبر الرابط${contractCode ? ` (عقد ${contractCode})` : ""} — الإجمالي المدفوع: ${totalPaidLabel} KWD${remainingLabel != null ? `، المتبقي: ${remainingLabel} KWD` : ""}.`;

        const adminNotifs = adminRoles.map((ar: Record<string, unknown>) => ({
          user_id: ar.user_id,
          title:   "دفع جديد عبر رابط",
          body,
          meta: {
            type:        "payment_received_admin",
            payment_id:  paymentId,
            contract_id: contractId,
            amount,
            total_paid:  totalPaid,
            remaining,
          },
        }));
        await supabase.from("notifications").insert(adminNotifs);
      }
    }
  }

  return new Response(JSON.stringify({
    verified:       isPaid,
    gateway_status: isPaid ? "paid" : "pending",
  }), {
    status: 200, headers: { ...cors, "Content-Type": "application/json" },
  });
});
