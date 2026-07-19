// Supabase Edge Function: create-upayment-charge
// Creates a UPayments hosted-page charge for a contract or standalone-task payment.
// Called from the admin dashboard ("إرسال الآن") or internally by generate-payment-reminders.
//
// Sandbox/production is toggled at runtime from the dashboard (see get_upayments_sandbox_mode
// RPC) rather than requiring a redeploy. UPAYMENTS_SANDBOX below is only the fallback used if
// that DB read fails.
//
// Required Supabase secrets:
//   UPAYMENTS_API_TOKEN    — production token (from UPayments merchant dashboard)
//   UPAYMENTS_SANDBOX      — fallback only; set to "true" to default to sandbox (test token = jtest123 auto-used)
//   UPAYMENTS_RETURN_URL, UPAYMENTS_CANCEL_URL, UPAYMENTS_WEBHOOK_URL
//   UPAYMENTS_FEE_AMOUNT   — flat commission per payment, KWD, e.g. "0.13"
//   NOTIFICATION_SECRET,
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (injected automatically)

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const UPAYMENTS_SANDBOX_ENV     = Deno.env.get("UPAYMENTS_SANDBOX") === "true";
const UPAYMENTS_API_TOKEN_ENV   = Deno.env.get("UPAYMENTS_API_TOKEN") ?? "";
const UPAYMENTS_NWL_TOKEN_ENV   = Deno.env.get("UPAYMENTS_NWL_TOKEN") ?? "";
const UPAYMENTS_GATEWAY_SRC_ENV = Deno.env.get("UPAYMENTS_GATEWAY_SRC") ?? "cc";
const UPAYMENTS_RETURN_URL = Deno.env.get("UPAYMENTS_RETURN_URL") ?? "";
const UPAYMENTS_CANCEL_URL = Deno.env.get("UPAYMENTS_CANCEL_URL") ?? "";
const UPAYMENTS_WEBHOOK_URL = Deno.env.get("UPAYMENTS_WEBHOOK_URL") ?? "";
const UPAYMENTS_FEE_AMOUNT = parseFloat(Deno.env.get("UPAYMENTS_FEE_AMOUNT") ?? "0.13");
const NOTIFICATION_SECRET  = Deno.env.get("NOTIFICATION_SECRET")  ?? "";
const SUPABASE_URL         = Deno.env.get("SUPABASE_URL")         ?? "";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // ── Parse body ─────────────────────────────────────────────────────────────
  let paymentId: string;
  let paymentType: "contract" | "standalone";
  let amount: number;
  let clientUserId: string;
  let contractId: string | undefined;
  let taskId: string | undefined;
  let gatewaySrc: string | undefined;
  let silent: boolean;

  try {
    const body = await req.json();
    paymentId    = body.paymentId   as string;
    paymentType  = body.paymentType as "contract" | "standalone";
    amount       = body.amount      as number;
    clientUserId = body.clientUserId as string;
    contractId   = body.contractId  as string | undefined;
    taskId       = body.taskId      as string | undefined;
    // Set by the client app when the client themselves taps "ادفع الآن" —
    // they're already looking at the screen, so skip the push notification
    // (avoids re-notifying them every time they retry the payment link).
    silent       = body.silent === true;
    // Caller-provided gateway method; final default resolved below once sandbox mode is known
    gatewaySrc   = body.gatewaySrc as string | undefined;

    if (!paymentId || !paymentType || !amount || !clientUserId) {
      throw new Error("missing required fields");
    }
  } catch (e) {
    return new Response(`Bad Request: ${(e as Error).message}`, {
      status: 400,
      headers: corsHeaders,
    });
  }

  // Must disable session persistence so the service role key is used as-is
  // (without this, supabase-js may fall back to anon and hit RLS)
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false },
  });

  // Fee amount is admin-configurable at runtime (see get_upayments_fee_amount RPC).
  // Fall back to the env-var default if the read fails for any reason.
  let gatewayFeeAmountSetting = UPAYMENTS_FEE_AMOUNT;
  try {
    const { data: feeAmountData } = await supabase.rpc("get_upayments_fee_amount");
    if (typeof feeAmountData === "number") gatewayFeeAmountSetting = feeAmountData;
  } catch (e) {
    console.warn("[create-upayment-charge] get_upayments_fee_amount failed, using env default:", e);
  }

  // Sandbox/production is admin-configurable at runtime (see get_upayments_sandbox_mode RPC).
  // Fall back to the env-var default if the read fails for any reason.
  let isSandbox = UPAYMENTS_SANDBOX_ENV;
  try {
    const { data: sandboxData } = await supabase.rpc("get_upayments_sandbox_mode");
    if (typeof sandboxData === "boolean") isSandbox = sandboxData;
  } catch (e) {
    console.warn("[create-upayment-charge] get_upayments_sandbox_mode failed, using env default:", e);
  }

  // White-label token (requires paymentGateway.src per request)
  const UPAYMENTS_WL_TOKEN  = isSandbox ? (UPAYMENTS_API_TOKEN_ENV || "jtest123") : UPAYMENTS_API_TOKEN_ENV;
  // Non-white-label token (hosted page shows all methods — no paymentGateway needed)
  const UPAYMENTS_NWL_TOKEN = isSandbox ? "jtest123" : (UPAYMENTS_NWL_TOKEN_ENV || UPAYMENTS_WL_TOKEN);
  const UPAYMENTS_API_URL   = isSandbox
    ? "https://sandboxapi.upayments.com/api/v1/charge"
    : "https://uapi.upayments.com/api/v1/charge";
  const resolvedGatewaySrc  = gatewaySrc ?? (isSandbox ? "cc" : UPAYMENTS_GATEWAY_SRC_ENV);

  // ── Fetch client info ───────────────────────────────────────────────────────
  const { data: userRow } = await supabase
    .from("users")
    .select("name, email, phone")
    .eq("id", clientUserId)
    .maybeSingle();

  const customerName   = (userRow?.name   as string | null)  ?? "العميل";
  const customerEmail  = (userRow?.email  as string | null)  ?? "";
  const customerMobile = (userRow?.phone  as string | null)  ?? "";

  // ── Call UPayments Add Charge API ──────────────────────────────────────────
  // UPayments limits reference.id and order.id to 35 chars max.
  // UUID (36 chars with hyphens) → strip hyphens → 32 chars ✓
  const shortRef = paymentId.replace(/-/g, "");
  // order.id must be unique per attempt — appending a 3-char base-36 timestamp
  // suffix prevents uPayments from rejecting retries as duplicate orders.
  // reference.id stays as the clean UUID so the webhook can always find the payment.
  const orderRef = shortRef.substring(0, 29) + Date.now().toString(36).slice(-3);

  // If no gatewaySrc provided → non-white-label mode (UPayments shows all methods)
  // If gatewaySrc provided → white-label mode (specific method forced)
  gatewaySrc = resolvedGatewaySrc;
  const useWhiteLabel = Boolean(gatewaySrc);
  const apiToken = useWhiteLabel ? UPAYMENTS_WL_TOKEN : UPAYMENTS_NWL_TOKEN;

  const chargePayload: Record<string, unknown> = {
    products: [
      {
        name:        "دفعة عقد",
        description: contractId ? `عقد` : "دفعة",
        price:       amount,
        quantity:    1,
      },
    ],
    order: {
      id:          orderRef,
      description: "دفعة عقد",
      currency:    "KWD",
      amount:      amount,
      language:    "ar",
    },
    customer: {
      uniqueId: clientUserId.replace(/-/g, "").substring(0, 35),
      name:     customerName  || "عميل",
      email:    customerEmail || "noreply@ensdim.local",
      mobile:   customerMobile || "",
    },
    returnUrl:       UPAYMENTS_RETURN_URL,
    cancelUrl:       UPAYMENTS_CANCEL_URL,
    notificationUrl: UPAYMENTS_WEBHOOK_URL,
    reference: {
      id: shortRef,
    },
    language:   "ar",
    isSaveCard: false,
    // paymentGateway only for white-label (specific src required)
    ...(useWhiteLabel ? { paymentGateway: { src: gatewaySrc } } : {}),
  };

  let paymentUrl: string;
  let orderId: string;
  let sessionId: string = "";

  try {
    console.log(`[create-upayment-charge] ${isSandbox ? "SANDBOX" : "PRODUCTION"} → ${UPAYMENTS_API_URL}`);
    console.log("[create-upayment-charge] service key length:", SUPABASE_SERVICE_KEY.length);

    const upRes = await fetch(UPAYMENTS_API_URL, {
      method: "POST",
      headers: {
        Authorization:  `Bearer ${apiToken}`,
        "Content-Type": "application/json",
        Accept:         "application/json",
      },
      body: JSON.stringify(chargePayload),
    });

    const upData = await upRes.json();
    console.log("[create-upayment-charge] UPayments response:", JSON.stringify(upData));

    if (!upRes.ok || upData?.status === false) {
      const errMsg = upData?.message ?? upData?.error ?? JSON.stringify(upData);
      console.error("[create-upayment-charge] UPayments error:", upRes.status, errMsg);
      return new Response(`UPayments API error: ${errMsg}`, {
        status: 502,
        headers: corsHeaders,
      });
    }

    // UPayments v1 response shape:
    // { status: true, message: "...", data: { collectId: "...", link: "https://...", session_id: "..." } }
    paymentUrl = upData?.data?.link      ?? upData?.link      ?? upData?.paymentURL ?? "";
    orderId    = upData?.data?.collectId ?? upData?.data?.id  ?? upData?.id         ?? "";
    sessionId  = upData?.data?.session_id ?? upData?.session_id ?? "";

    if (!paymentUrl) {
      throw new Error("no payment URL in UPayments response: " + JSON.stringify(upData));
    }
  } catch (e) {
    console.error("[create-upayment-charge] fetch error:", e);
    return new Response(`Failed to create charge: ${(e as Error).message}`, {
      status: 500,
      headers: corsHeaders,
    });
  }

  // ── Calculate fee ───────────────────────────────────────────────────────────
  const gatewayFeeAmount = gatewayFeeAmountSetting;

  // ── Update payment row ──────────────────────────────────────────────────────
  const table = paymentType === "contract" ? "contract_payments" : "standalone_task_payments";
  const { error: updateErr } = await supabase.from(table).update({
    payment_gateway_url:      paymentUrl,
    payment_gateway_order_id: orderId,
    gateway_status:           "pending",
    gateway_fee_amount:       gatewayFeeAmount,
    ...(sessionId ? { gateway_session_id: sessionId } : {}),
  }).eq("id", paymentId);

  if (updateErr) {
    console.error("[create-upayment-charge] DB update error:", updateErr.message);
    return new Response(`DB update failed: ${updateErr.message}`, {
      status: 500,
      headers: corsHeaders,
    });
  }

  // ── Send FCM push to client (skip if the client initiated this themselves) ──
  if (!silent) {
    const notifPayload: Record<string, string | number> = {
      clientId:    clientUserId,
      notifType:   "payment_request",
      paymentId:   paymentId,
      paymentType: paymentType,
      amount:      amount,
    };
    if (contractId) notifPayload["contractId"] = contractId;
    if (taskId)     notifPayload["taskId"]     = taskId;

    await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
      method: "POST",
      headers: {
        "Content-Type":          "application/json",
        "Authorization":         `Bearer ${SUPABASE_SERVICE_KEY}`,
        "x-notification-secret": NOTIFICATION_SECRET,
      },
      body: JSON.stringify(notifPayload),
    }).catch((e) => console.warn("[create-upayment-charge] push notification failed:", e));
  }

  return new Response(JSON.stringify({ paymentUrl, orderId, sessionId, gatewayFeeAmount }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
