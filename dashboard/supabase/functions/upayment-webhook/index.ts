// Supabase Edge Function: upayment-webhook
// Receives UPayments server-to-server payment confirmation.
// Verifies HMAC-SHA256 signature, marks payment as paid, notifies users.
//
// Required Supabase secrets:
//   UPAYMENTS_WEBHOOK_SECRET,
//   NOTIFICATION_SECRET,
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (injected automatically)
//   UPAYMENTS_SANDBOX — fallback only; real mode comes from get_upayments_sandbox_mode RPC

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Sandbox/production is admin-configurable at runtime (see get_upayments_sandbox_mode RPC,
// toggled from the "بوابة الدفع" switch in the dashboard). UPAYMENTS_SANDBOX below is only
// the fallback used if that DB read fails.
const UPAYMENTS_SANDBOX_ENV    = Deno.env.get("UPAYMENTS_SANDBOX") === "true";
const UPAYMENTS_WEBHOOK_SECRET = Deno.env.get("UPAYMENTS_WEBHOOK_SECRET") ?? "";
const NOTIFICATION_SECRET      = Deno.env.get("NOTIFICATION_SECRET")      ?? "";
const SUPABASE_URL             = Deno.env.get("SUPABASE_URL")             ?? "";
const SUPABASE_SERVICE_KEY     = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const rawBody = await req.text();

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false },
  });

  // ── Identify which tenant this charge belongs to ───────────────────────────
  // create-upayment-charge tags notificationUrl with ?tenant_id=... for any
  // tenant with its own UPayments merchant account, so we know which secret
  // to verify the HMAC signature with BEFORE trusting anything in the body.
  // Charges created before this existed (or for tenants without their own
  // gateway configured) have no query param — those fall back to the
  // original shared env-var secret, so Ensdim's existing setup is unaffected.
  const requestUrl = new URL(req.url);
  const urlTenantId = requestUrl.searchParams.get("tenant_id");

  let webhookSecret = UPAYMENTS_WEBHOOK_SECRET;
  if (urlTenantId) {
    try {
      const { data: credsData } = await supabase.rpc("get_tenant_payment_credentials", { p_tenant_id: urlTenantId });
      const creds = Array.isArray(credsData) ? (credsData[0] ?? null) : credsData;
      if (creds?.webhook_secret) webhookSecret = creds.webhook_secret;
    } catch (e) {
      console.warn("[upayment-webhook] get_tenant_payment_credentials failed, using env default:", e);
    }
  }

  // Sandbox/production is admin-configurable at runtime (see get_upayments_sandbox_mode RPC).
  // Fall back to the env-var default if the read fails for any reason.
  let isSandbox = UPAYMENTS_SANDBOX_ENV;
  try {
    const { data: sandboxData } = await supabase.rpc("get_upayments_sandbox_mode", { p_tenant_id: urlTenantId });
    if (typeof sandboxData === "boolean") isSandbox = sandboxData;
  } catch (e) {
    console.warn("[upayment-webhook] get_upayments_sandbox_mode failed, using env default:", e);
  }

  // ── Verify HMAC-SHA256 signature ───────────────────────────────────────────
  // Sandbox: skip signature check (test environment doesn't send valid HMAC)
  if (!isSandbox) {
    const signature = req.headers.get("x-signature") ?? req.headers.get("x-upayments-signature") ?? "";
    if (webhookSecret && signature) {
      const isValid = await verifyHmac(rawBody, signature, webhookSecret);
      if (!isValid) {
        console.error("[upayment-webhook] invalid HMAC signature");
        return new Response("Unauthorized", { status: 401 });
      }
    }
  } else {
    console.log("[upayment-webhook] SANDBOX mode — skipping HMAC verification");
  }

  // ── Parse webhook body ─────────────────────────────────────────────────────
  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(rawBody);
  } catch {
    return new Response("Bad Request: invalid JSON", { status: 400 });
  }

  // Log full payload for sandbox debugging
  console.log("[upayment-webhook] payload:", rawBody.substring(0, 1000));

  // Extract fields — UPayments webhook shape (may vary — check logs):
  // { status: "success", reference: "<our paymentId>", orderId: "...", amount: "...", ... }
  const data          = (payload.data ?? payload) as Record<string, unknown>;
  const txn           = (data.transaction ?? data) as Record<string, unknown>;
  const status        = (txn.result ?? txn.status ?? data.status ?? data.paymentStatus ?? payload.status ?? "") as string;
  const reference     = (txn.reference ?? data.reference ?? data.trackId ?? payload.reference ?? "") as string;
  const orderId       = (txn.order_id ?? data.orderId ?? data.paymentId ?? data.id ?? payload.orderId ?? "") as string;
  const trackId       = (txn.track_id ?? data.trackId ?? "") as string;
  const sessionId     = (txn.session_id ?? data.session_id ?? "") as string;
  const paymentType   = (txn.payment_type ?? data.payment_type ?? data.paymentType ?? "") as string;
  const feeAmount     = parseFloat(String(txn.feeAmount ?? data.feeAmount ?? data.gatewayFee ?? payload.feeAmount ?? 0));
  const paidAmount    = parseFloat(String(txn.total_price ?? txn.total_paid_non_kwd ?? data.amount ?? payload.amount ?? 0));
  const paidDate      = new Date().toISOString().split("T")[0];

  console.log("[upayment-webhook] parsed — status:", status, "paymentType:", paymentType, "reference:", reference, "trackId:", trackId, "orderId:", orderId);

  console.log("[upayment-webhook] parsed — status:", status, "reference:", reference, "orderId:", orderId);

  if (!reference && !orderId) {
    return new Response("Bad Request: missing reference/orderId", { status: 400 });
  }

  const isPaid = ["success", "paid", "captured", "CAPTURED", "SUCCESS"].includes(status);

  // Fee amount is admin-configurable at runtime (see get_upayments_fee_amount RPC).
  // Fall back to the hardcoded 0.13 default if the read fails for any reason.
  let webhookFeeAmount = 0.13;
  try {
    const { data: feeAmountData } = await supabase.rpc("get_upayments_fee_amount", { p_tenant_id: urlTenantId });
    if (typeof feeAmountData === "number") webhookFeeAmount = feeAmountData;
  } catch (e) {
    console.warn("[upayment-webhook] get_upayments_fee_amount failed, using 0.13 default:", e);
  }

  // ── Find payment by reference (paymentId) or order_id ─────────────────────
  // reference comes as stripped UUID (32 chars, no hyphens) — restore to UUID format
  const restoredUuid = restoreUuid(reference);
  const lookupCol  = restoredUuid ? "id" : "payment_gateway_order_id";
  const lookupVal  = restoredUuid || orderId;

  // Try contract_payments first
  let paymentRow: Record<string, unknown> | null = null;
  let paymentTable = "contract_payments";

  const { data: cpRow } = await supabase
    .from("contract_payments")
    .select("id, contract_id, amount, gateway_status, tenant_id")
    .eq(lookupCol, lookupVal)
    .maybeSingle();

  if (cpRow) {
    paymentRow = cpRow as Record<string, unknown>;
  } else {
    // Try standalone_task_payments
    const { data: stRow } = await supabase
      .from("standalone_task_payments")
      .select("id, task_id, amount, gateway_status, tenant_id")
      .eq(lookupCol, lookupVal)
      .maybeSingle();

    if (stRow) {
      paymentRow = stRow as Record<string, unknown>;
      paymentTable = "standalone_task_payments";
    }
  }

  if (!paymentRow) {
    console.warn("[upayment-webhook] no payment found for reference:", lookupVal);
    // Return 200 to prevent UPayments retrying for unknown references
    return new Response("OK", { status: 200 });
  }

  if ((paymentRow.gateway_status as string) === "paid") {
    // Already processed (idempotency)
    return new Response("OK", { status: 200 });
  }

  // ── Update payment status ──────────────────────────────────────────────────
  const newGatewayStatus = isPaid ? "paid" : "failed";
  const updateData: Record<string, unknown> = {
    gateway_status:           newGatewayStatus,
    payment_gateway_order_id: orderId || paymentRow.payment_gateway_order_id,
  };

  if (isPaid) {
    updateData.payment_method         = "gateway";
    updateData.payment_date           = paidDate;
    updateData.gateway_fee_amount     = feeAmount > 0 ? feeAmount : webhookFeeAmount;
    if (paymentType)  updateData.gateway_payment_method = paymentType;
    if (trackId)      updateData.payment_gateway_order_id = trackId;  // prefer track_id as the canonical id
    if (sessionId)    updateData.gateway_session_id = sessionId;
  }

  const { error: updateErr } = await supabase
    .from(paymentTable)
    .update(updateData)
    .eq("id", paymentRow.id as string);

  if (updateErr) {
    console.error("[upayment-webhook] update error:", updateErr.message);
    return new Response("Internal Server Error", { status: 500 });
  }

  if (!isPaid) {
    return new Response("OK", { status: 200 });
  }

  // ── For standalone tasks: mark task payment_status = 'paid' ───────────────
  if (paymentTable === "standalone_task_payments" && paymentRow.task_id) {
    await supabase
      .from("standalone_tasks")
      .update({ payment_status: "paid", payment_method: "gateway" })
      .eq("id", paymentRow.task_id as string);
  }

  // ── Fetch client user_id + contract/financial summary for notifications ────
  let clientUserId: string | null = null;
  let contractCode: string | null = null;
  let clientName: string | null = null;
  let totalPaid: number = (paymentRow.amount as number) ?? 0;
  let remaining: number | null = null;

  if (paymentTable === "contract_payments" && paymentRow.contract_id) {
    const { data: contract } = await supabase
      .from("contracts")
      .select("user_id, code, total_value")
      .eq("id", paymentRow.contract_id as string)
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
      .eq("contract_id", paymentRow.contract_id as string);

    totalPaid = (contractPayments ?? [])
      .filter((p: Record<string, unknown>) => p.gateway_status === "paid" || (!p.gateway_status && !p.due_date))
      .reduce((sum: number, p: Record<string, unknown>) => sum + Number(p.amount ?? 0), 0);

    if (contract?.total_value != null) {
      remaining = Number(contract.total_value) - totalPaid;
    }
  }

  // ── Insert in-app notification for client ──────────────────────────────────
  if (clientUserId) {
    const amountLabel = (paymentRow.amount as number)?.toFixed(3) ?? "";
    await supabase.from("notifications").insert({
      user_id: clientUserId,
      title:   "تم استلام دفعتك بنجاح ✓",
      body:    `تم تأكيد دفع مبلغ ${amountLabel} KWD.`,
      meta: {
        type:        "payment_confirmed",
        payment_id:  paymentRow.id,
        contract_id: paymentRow.contract_id ?? null,
        amount:      paymentRow.amount,
      },
    });

    // FCM push to client
    await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
      method: "POST",
      headers: {
        "Content-Type":          "application/json",
        "Authorization":         `Bearer ${SUPABASE_SERVICE_KEY}`,
        "x-notification-secret": NOTIFICATION_SECRET,
      },
      body: JSON.stringify({
        clientId:    clientUserId,
        notifType:   "payment_confirmed",
        paymentId:   paymentRow.id,
        paymentType: paymentTable === "contract_payments" ? "contract" : "standalone",
        amount:      paymentRow.amount,
        contractId:  paymentRow.contract_id ?? undefined,
      }),
    }).catch((e) => console.warn("[upayment-webhook] push failed:", e));
  }

  // ── Insert in-app notification for admins of THIS payment's tenant only ────
  const { data: adminRoles } = await supabase
    .from("user_roles")
    .select("user_id, roles!inner(name), users!inner(tenant_id)")
    .eq("roles.name", "admin")
    .eq("users.tenant_id", paymentRow.tenant_id as string);

  if (adminRoles?.length) {
    const amountLabel    = ((paymentRow.amount as number) ?? 0).toFixed(3);
    const totalPaidLabel = totalPaid.toFixed(3);
    const remainingLabel = remaining != null ? remaining.toFixed(3) : null;
    const body = `العميل ${clientName ?? "غير معروف"} دفع ${amountLabel} KWD عبر الرابط${contractCode ? ` (عقد ${contractCode})` : ""} — الإجمالي المدفوع: ${totalPaidLabel} KWD${remainingLabel != null ? `، المتبقي: ${remainingLabel} KWD` : ""}.`;

    const adminNotifs = adminRoles.map((ar: Record<string, unknown>) => ({
      user_id: ar.user_id,
      title:   "دفع جديد عبر رابط",
      body,
      meta: {
        type:        "payment_received_admin",
        payment_id:  paymentRow.id,
        contract_id: paymentRow.contract_id ?? null,
        amount:      paymentRow.amount,
        total_paid:  totalPaid,
        remaining,
      },
    }));
    await supabase.from("notifications").insert(adminNotifs);
  }

  return new Response("OK", { status: 200 });
});

// ── UUID restore: "abc123..." (32 chars) → "abc123ab-c123-..." ────────────
function restoreUuid(s: string): string | null {
  if (!s) return null;
  // Already a full UUID
  if (/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s)) return s;
  // Stripped UUID (32 hex chars)
  if (/^[0-9a-f]{32}$/i.test(s)) {
    return `${s.slice(0,8)}-${s.slice(8,12)}-${s.slice(12,16)}-${s.slice(16,20)}-${s.slice(20)}`;
  }
  return null;
}

// ── HMAC-SHA256 verification ───────────────────────────────────────────────
async function verifyHmac(body: string, signature: string, secret: string): Promise<boolean> {
  try {
    const key = await crypto.subtle.importKey(
      "raw",
      new TextEncoder().encode(secret),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["verify"],
    );
    const sigBytes = hexToBytes(signature);
    return await crypto.subtle.verify(
      "HMAC",
      key,
      sigBytes,
      new TextEncoder().encode(body),
    );
  } catch {
    return false;
  }
}

function hexToBytes(hex: string): Uint8Array {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < bytes.length; i++) {
    bytes[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  }
  return bytes;
}
