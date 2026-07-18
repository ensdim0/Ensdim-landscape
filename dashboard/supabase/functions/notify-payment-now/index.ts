// Supabase Edge Function: notify-payment-now
// Called by the dashboard right after an admin schedules a payment, so the
// client gets the right reminder (due-3/due-1/due-today/late) immediately
// instead of waiting for the next daily cron run (generate-payment-reminders),
// which could be up to 24h away and would miss the exact day-3 window for
// payments scheduled the same day with due_date = today+3.
//
// Required Supabase secrets:
//   NOTIFICATION_SECRET, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (injected automatically)

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const NOTIFICATION_SECRET  = Deno.env.get("NOTIFICATION_SECRET")  ?? "";
const SUPABASE_URL         = Deno.env.get("SUPABASE_URL")         ?? "";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const cors = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  let paymentId: string;
  try {
    const body = await req.json();
    paymentId  = body.paymentId as string;
    if (!paymentId) throw new Error("missing paymentId");
  } catch (e) {
    return new Response(`Bad Request: ${(e as Error).message}`, { status: 400, headers: cors });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

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
        paymentType:  "contract",
        amount:       result.amount,
        clientUserId: result.client_id,
        contractId:   result.contract_id,
        silent:       true,
      }),
    }).catch((e) => console.warn("[notify-payment-now] charge creation failed:", e));
  }

  return new Response(JSON.stringify({ ok: true, type: result?.type ?? null }), {
    status: 200, headers: { ...cors, "Content-Type": "application/json" },
  });
});
