// Supabase Edge Function: notify-payment-now
// Called by the dashboard right after an admin schedules a payment, so the
// client gets the right reminder (due-3/due-1/due-today/late) immediately
// instead of waiting for the next daily cron run (generate-payment-reminders),
// which could be up to 24h away and would miss the exact day-3 window for
// payments scheduled the same day with due_date = today+3.
//
// SECURITY: only an admin of the payment's own tenant may trigger this (it
// sends a real push notification and can create a real UPayments charge
// link) — a valid user JWT is required and checked against the payment's
// tenant_id, mirroring create-upayment-charge/admin-update-user.
//
// Required Supabase secrets:
//   NOTIFICATION_SECRET, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (injected automatically)

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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

function getCors(origin: string | null) {
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
  const cors = getCors(req.headers.get("origin"));

  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  let paymentId: string;
  try {
    const body = await req.json();
    paymentId  = body.paymentId as string;
    if (!paymentId) throw new Error("missing paymentId");
  } catch (e) {
    return new Response(`Bad Request: ${(e as Error).message}`, { status: 400, headers: cors });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false },
  });

  // ── Authentication / authorization: caller must be an admin of the
  // tenant that owns this payment ─────────────────────────────────────────────
  const accessToken = extractBearerToken(req.headers.get("Authorization") ?? req.headers.get("authorization"));
  if (!accessToken) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401, headers: { ...cors, "Content-Type": "application/json" } });
  }

  const { data: { user: callerUser }, error: authError } = await supabase.auth.getUser(accessToken);
  if (authError || !callerUser) {
    return new Response(JSON.stringify({ error: "Unauthorized", message: authError?.message ?? "Invalid or expired access token" }), {
      status: 401, headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  const appMetadataRole = String((callerUser as any)?.app_metadata?.role ?? "").toLowerCase();
  let hasAdminRole = appMetadataRole === "admin";
  if (!hasAdminRole) {
    const { data: adminRoleRow } = await supabase.from("roles").select("id").eq("name", "admin").maybeSingle();
    if (adminRoleRow) {
      const { data: callerAdminRole } = await supabase
        .from("user_roles").select("user_id")
        .eq("user_id", callerUser.id).eq("role_id", adminRoleRow.id)
        .maybeSingle();
      hasAdminRole = Boolean(callerAdminRole);
    }
  }
  if (!hasAdminRole) {
    return new Response(JSON.stringify({ error: "Forbidden" }), { status: 403, headers: { ...cors, "Content-Type": "application/json" } });
  }

  const { data: callerProfile } = await supabase.from("users").select("tenant_id").eq("id", callerUser.id).maybeSingle();
  const callerTenantId = callerProfile?.tenant_id ?? null;

  const { data: paymentRow } = await supabase.from("contract_payments").select("id, tenant_id").eq("id", paymentId).maybeSingle();
  if (!paymentRow || !callerTenantId || paymentRow.tenant_id !== callerTenantId) {
    return new Response(JSON.stringify({ error: "Forbidden" }), { status: 403, headers: { ...cors, "Content-Type": "application/json" } });
  }

  const { data: result, error } = await supabase.rpc("evaluate_payment_due_notification", {
    p_payment_id: paymentId,
  });

  if (error) {
    console.error("[notify-payment-now] evaluate error:", error.message);
    return new Response(JSON.stringify({ ok: false, error: error.message }), {
      status: 500, headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  if (result?.type && result?.client_id) {
    await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
      method: "POST",
      headers: {
        "Content-Type":          "application/json",
        "Authorization":         `Bearer ${SUPABASE_SERVICE_KEY}`,
        "x-notification-secret": NOTIFICATION_SECRET,
      },
      body: JSON.stringify({
        clientId:    result.client_id,
        notifType:   result.type,
        paymentId,
        paymentType: "contract",
        amount:      result.amount,
        contractId:  result.contract_id,
      }),
    }).catch((e) => console.warn("[notify-payment-now] push failed:", e));

    // Already within the ≤3-day reminder window (or late) — generate the
    // UPayments link now too, same as the daily cron would. silent:true
    // because we just sent the reminder push above; no need for a second one.
    await fetch(`${SUPABASE_URL}/functions/v1/create-upayment-charge`, {
      method: "POST",
      headers: {
        "Content-Type":  "application/json",
        "Authorization": `Bearer ${SUPABASE_SERVICE_KEY}`,
      },
      body: JSON.stringify({
        paymentId,
        paymentType: "contract",
        silent:      true,
      }),
    }).catch((e) => console.warn("[notify-payment-now] charge creation failed:", e));
  }

  return new Response(JSON.stringify({ ok: true, type: result?.type ?? null }), {
    status: 200, headers: { ...cors, "Content-Type": "application/json" },
  });
});
