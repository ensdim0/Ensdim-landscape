// Supabase Edge Function: create-upayment-charge
// Creates a UPayments hosted-page charge for a contract or standalone-task payment.
// Called from the admin dashboard ("إرسال الآن") or internally by generate-payment-reminders.
//
// Sandbox/production is toggled at runtime from the dashboard (see get_upayments_sandbox_mode
// RPC) rather than requiring a redeploy. UPAYMENTS_SANDBOX below is only the fallback used if
// that DB read fails.
//
// SECURITY: three legitimate caller classes are accepted —
//   1. Internal service-to-service calls (generate-payment-reminders, notify-payment-now)
//      authenticate with Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>.
//   2. The client themselves paying their own payment (mobile app) — a normal user JWT
//      whose auth.uid() matches the payment's real owning client, verified server-side.
//   3. An admin/supervisor of the tenant that owns the payment (dashboard "إرسال الآن").
// `amount` and the recipient client are always re-derived from the DB row — the request
// body is never trusted for either, closing the amount-tampering / notification-spoofing
// hole that existed when this function had no auth check at all.
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

// ── CORS (origin allowlist, same pattern as admin-update-user) ────────────────
const rawAllowedOrigins = (Deno.env.get("ALLOWED_ORIGINS") ?? "").trim();
const hasExplicitAllowedOrigins = rawAllowedOrigins.length > 0;
const allowedOrigins = (hasExplicitAllowedOrigins
  ? rawAllowedOrigins
  : "http://localhost:5173,http://localhost:3000")
  .split(",")
  .map((origin) => origin.trim())
  .filter(Boolean);

function isLocalDevOrigin(origin: string): boolean {
  try {
    const parsed = new URL(origin);
    return parsed.protocol === "http:"
      && (parsed.hostname === "localhost" || parsed.hostname === "127.0.0.1" || parsed.hostname === "[::1]" || parsed.hostname === "::1");
  } catch {
    return false;
  }
}

function isAllowedOrigin(origin: string | null): boolean {
  if (!origin) return false;
  if (isLocalDevOrigin(origin)) return true;
  if (allowedOrigins.includes("*") || allowedOrigins.includes(origin)) return true;
  if (!hasExplicitAllowedOrigins) {
    try {
      const parsed = new URL(origin);
      const isLocalhost = (parsed.hostname === "localhost" || parsed.hostname === "127.0.0.1") && parsed.protocol === "http:";
      return parsed.protocol === "https:" || isLocalhost;
    } catch {
      return false;
    }
  }
  return false;
}

function getCorsHeaders(origin: string | null) {
  return {
    "Access-Control-Allow-Origin":  isAllowedOrigin(origin) ? origin! : "null",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}

function extractBearerToken(headerValue: string | null): string {
  if (!headerValue) return "";
  const match = headerValue.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() ?? "";
}

serve(async (req: Request): Promise<Response> => {
  const corsHeaders = getCorsHeaders(req.headers.get("origin"));

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // ── Parse body ─────────────────────────────────────────────────────────────
  // Only paymentId/paymentType/silent/gatewaySrc come from the caller — amount,
  // clientUserId, contractId/taskId are always re-derived from the DB below.
  let paymentId: string;
  let paymentType: "contract" | "standalone";
  let silent: boolean;
  let gatewaySrc: string | undefined;

  try {
    const body = await req.json();
    paymentId    = body.paymentId   as string;
    paymentType  = body.paymentType as "contract" | "standalone";
    // Set by the client app when the client themselves taps "ادفع الآن" —
    // they're already looking at the screen, so skip the push notification
    // (avoids re-notifying them every time they retry the payment link).
    silent       = body.silent === true;
    // Caller-provided gateway method; final default resolved below once sandbox mode is known
    gatewaySrc   = body.gatewaySrc as string | undefined;

    if (!paymentId || !paymentType) {
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

  // ── Load the real payment row — amount/tenant/status/owner all come from
  // here, never from the request body ─────────────────────────────────────────
  const paymentTable = paymentType === "contract" ? "contract_payments" : "standalone_task_payments";
  const ownerColumn   = paymentType === "contract" ? "contract_id" : "task_id";
  const { data: paymentRow, error: paymentLookupErr } = await supabase
    .from(paymentTable)
    .select(`id, amount, tenant_id, gateway_status, ${ownerColumn}`)
    .eq("id", paymentId)
    .maybeSingle();

  if (paymentLookupErr || !paymentRow) {
    return new Response("Not Found: payment does not exist", { status: 404, headers: corsHeaders });
  }
  if (paymentRow.gateway_status === "paid") {
    return new Response("Conflict: payment is already paid", { status: 409, headers: corsHeaders });
  }

  const amount     = Number(paymentRow.amount);
  const tenantId   = (paymentRow.tenant_id as string | null) ?? null;
  const contractId = paymentType === "contract"    ? (paymentRow as any).contract_id as string : undefined;
  const taskId     = paymentType === "standalone"  ? (paymentRow as any).task_id     as string : undefined;

  // Resolve the payment's real owning client from the contract/task, never
  // from the request body.
  let realClientUserId: string | null = null;
  if (paymentType === "contract" && contractId) {
    const { data: contractRow } = await supabase.from("contracts").select("user_id").eq("id", contractId).maybeSingle();
    realClientUserId = (contractRow?.user_id as string | null) ?? null;
  } else if (paymentType === "standalone" && taskId) {
    const { data: taskRow } = await supabase.from("standalone_tasks").select("client_id").eq("id", taskId).maybeSingle();
    realClientUserId = (taskRow?.client_id as string | null) ?? null;
  }
  if (!realClientUserId) {
    return new Response("Not Found: payment has no associated client", { status: 404, headers: corsHeaders });
  }

  // ── Authentication / authorization ──────────────────────────────────────────
  const authHeader   = req.headers.get("Authorization") ?? req.headers.get("authorization");
  const accessToken  = extractBearerToken(authHeader);
  const isInternalCall = Boolean(SUPABASE_SERVICE_KEY) && accessToken === SUPABASE_SERVICE_KEY;

  if (!isInternalCall) {
    if (!accessToken) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: { user: callerUser }, error: authError } = await supabase.auth.getUser(accessToken);
    if (authError || !callerUser) {
      return new Response(JSON.stringify({ error: "Unauthorized", message: authError?.message ?? "Invalid or expired access token" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const isSelf = callerUser.id === realClientUserId;

    if (!isSelf) {
      // Not the payment's own client — must be an admin of the same tenant.
      const appMetadataRole = String((callerUser as any)?.app_metadata?.role ?? "").toLowerCase();
      let hasAdminRole = appMetadataRole === "admin";

      if (!hasAdminRole) {
        const { data: adminRoleRow } = await supabase.from("roles").select("id").eq("name", "admin").maybeSingle();
        if (adminRoleRow) {
          const { data: callerAdminRole } = await supabase
            .from("user_roles")
            .select("user_id")
            .eq("user_id", callerUser.id)
            .eq("role_id", adminRoleRow.id)
            .maybeSingle();
          hasAdminRole = Boolean(callerAdminRole);
        }
      }

      const { data: callerProfile } = await supabase.from("users").select("tenant_id").eq("id", callerUser.id).maybeSingle();
      const callerTenantId = callerProfile?.tenant_id ?? null;

      if (!hasAdminRole || !callerTenantId || callerTenantId !== tenantId) {
        return new Response(JSON.stringify({ error: "Forbidden" }), {
          status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }
  }

  let tenantCreds: {
    api_token: string | null; nwl_token: string | null; gateway_src: string | null;
    webhook_secret: string | null; return_url: string | null; cancel_url: string | null;
  } | null = null;

  if (tenantId) {
    const { data: credsData } = await supabase.rpc("get_tenant_payment_credentials", { p_tenant_id: tenantId });
    tenantCreds = Array.isArray(credsData) ? (credsData[0] ?? null) : credsData;
  }

  // Fee amount is admin-configurable at runtime (see get_upayments_fee_amount RPC).
  // Fall back to the env-var default if the read fails for any reason.
  let gatewayFeeAmountSetting = UPAYMENTS_FEE_AMOUNT;
  try {
    const { data: feeAmountData } = await supabase.rpc("get_upayments_fee_amount", { p_tenant_id: tenantId });
    if (typeof feeAmountData === "number") gatewayFeeAmountSetting = feeAmountData;
  } catch (e) {
    console.warn("[create-upayment-charge] get_upayments_fee_amount failed, using env default:", e);
  }

  // Sandbox/production is admin-configurable at runtime (see get_upayments_sandbox_mode RPC).
  // Fall back to the env-var default if the read fails for any reason.
  let isSandbox = UPAYMENTS_SANDBOX_ENV;
  try {
    const { data: sandboxData } = await supabase.rpc("get_upayments_sandbox_mode", { p_tenant_id: tenantId });
    if (typeof sandboxData === "boolean") isSandbox = sandboxData;
  } catch (e) {
    console.warn("[create-upayment-charge] get_upayments_sandbox_mode failed, using env default:", e);
  }

  const tenantApiToken = tenantCreds?.api_token || null;
  const tenantNwlToken = tenantCreds?.nwl_token || null;

  // White-label token (requires paymentGateway.src per request)
  const UPAYMENTS_WL_TOKEN  = isSandbox
    ? (tenantApiToken || UPAYMENTS_API_TOKEN_ENV || "jtest123")
    : (tenantApiToken || UPAYMENTS_API_TOKEN_ENV);
  // Non-white-label token (hosted page shows all methods — no paymentGateway needed)
  const UPAYMENTS_NWL_TOKEN = isSandbox
    ? "jtest123"
    : (tenantNwlToken || UPAYMENTS_NWL_TOKEN_ENV || UPAYMENTS_WL_TOKEN);
  const UPAYMENTS_API_URL   = isSandbox
    ? "https://sandboxapi.upayments.com/api/v1/charge"
    : "https://uapi.upayments.com/api/v1/charge";
  const resolvedGatewaySrc  = gatewaySrc ?? (isSandbox ? "cc" : (tenantCreds?.gateway_src || UPAYMENTS_GATEWAY_SRC_ENV));
  const resolvedReturnUrl   = tenantCreds?.return_url || UPAYMENTS_RETURN_URL;
  const resolvedCancelUrl   = tenantCreds?.cancel_url || UPAYMENTS_CANCEL_URL;
  // Tag the webhook URL with the tenant id so upayment-webhook knows which
  // tenant's secret to verify the HMAC signature with, before it can trust
  // anything else in the incoming request.
  const resolvedWebhookUrl = tenantId
    ? `${UPAYMENTS_WEBHOOK_URL}${UPAYMENTS_WEBHOOK_URL.includes("?") ? "&" : "?"}tenant_id=${encodeURIComponent(tenantId)}`
    : UPAYMENTS_WEBHOOK_URL;

  // ── Fetch client info ───────────────────────────────────────────────────────
  const { data: userRow } = await supabase
    .from("users")
    .select("name, email, phone")
    .eq("id", realClientUserId)
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
      uniqueId: realClientUserId.replace(/-/g, "").substring(0, 35),
      name:     customerName  || "عميل",
      email:    customerEmail || "noreply@ensdim.local",
      mobile:   customerMobile || "",
    },
    returnUrl:       resolvedReturnUrl,
    cancelUrl:       resolvedCancelUrl,
    notificationUrl: resolvedWebhookUrl,
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

  // ── Update payment row (only if still pending — guards against a race with
  // a webhook that just marked it paid while the UPayments call was in flight) ──
  const { error: updateErr } = await supabase.from(paymentTable).update({
    payment_gateway_url:      paymentUrl,
    payment_gateway_order_id: orderId,
    gateway_status:           "pending",
    gateway_fee_amount:       gatewayFeeAmount,
    ...(sessionId ? { gateway_session_id: sessionId } : {}),
  }).eq("id", paymentId).neq("gateway_status", "paid");

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
      clientId:    realClientUserId,
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
