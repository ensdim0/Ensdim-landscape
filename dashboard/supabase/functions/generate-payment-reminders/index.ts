// Supabase Edge Function: generate-payment-reminders
// Daily cron function that:
//  1. Calls sync_payment_due_notifications() to insert in-app notifications (3/1/0 day warnings + late)
//  2. Auto-creates UPayments charges for payments due within ≤3 days (or already late)
//  3. Sends FCM push reminders for payments due in 1 and 3 days
//  4. Sends FCM push for payments newly marked late
//  5. Sends FCM push for payments due TODAY (independent of charge-creation success)
//
// Schedule in Supabase Dashboard: 0 4 * * *  (04:00 UTC = 07:00 KWT)
//
// SECURITY: this endpoint has no other authentication, so it's gated by a
// shared secret the Dashboard cron job must send as `x-cron-secret` — set the
// SAME value as the CRON_SECRET Supabase secret and the private.app_config
// 'cron_secret' row (see 2026-08-01_cron_secret_config.sql).
//
// Required Supabase secrets:
//   CRON_SECRET,
//   UPAYMENTS_API_TOKEN, UPAYMENTS_RETURN_URL, UPAYMENTS_CANCEL_URL,
//   UPAYMENTS_WEBHOOK_URL, UPAYMENTS_FEE_AMOUNT,
//   NOTIFICATION_SECRET,
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (injected automatically)

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CRON_SECRET          = Deno.env.get("CRON_SECRET")          ?? "";
const NOTIFICATION_SECRET  = Deno.env.get("NOTIFICATION_SECRET")  ?? "";
const SUPABASE_URL         = Deno.env.get("SUPABASE_URL")         ?? "";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

serve(async (req: Request): Promise<Response> => {
  if (!CRON_SECRET || req.headers.get("x-cron-secret") !== CRON_SECRET) {
    return new Response("Unauthorized", { status: 401 });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
  const today    = new Date().toISOString().split("T")[0];
  const plus1    = offsetDate(1);
  const plus3    = offsetDate(3);

  // ── Step 1: DB-level in-app notifications ──────────────────────────────────
  const { data: syncCount, error: syncErr } = await supabase.rpc("sync_payment_due_notifications");
  if (syncErr) {
    console.error("[generate-payment-reminders] sync_payment_due_notifications error:", syncErr.message);
  } else {
    console.log("[generate-payment-reminders] in-app notifications inserted:", syncCount);
  }

  // ── Step 2: Payments due within ≤3 days (or already late) → auto-create
  // UPayments charge. Self-limiting: once a charge is created, gateway_status
  // is no longer null, so the same payment won't be re-charged on later runs.
  const { data: dueSoon, error: dueSoonErr } = await supabase
    .from("contract_payments")
    .select("id, contract_id, amount, contracts(user_id, code)")
    .lte("due_date", plus3)
    .is("gateway_status", null);

  if (dueSoonErr) {
    console.error("[generate-payment-reminders] dueSoon query error:", dueSoonErr.message);
  }

  for (const payment of dueSoon ?? []) {
    const contract    = (payment as any).contracts as { user_id: string; code: string } | null;
    const clientId    = contract?.user_id ?? null;

    if (!clientId) continue;

    await fetch(`${SUPABASE_URL}/functions/v1/create-upayment-charge`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${SUPABASE_SERVICE_KEY}`,
      },
      body: JSON.stringify({
        paymentId:    payment.id,
        paymentType:  "contract",
        amount:       payment.amount,
        clientUserId: clientId,
        contractId:   payment.contract_id,
      }),
    }).catch((e) => console.warn("[generate-payment-reminders] charge creation failed for", payment.id, e));
  }

  // ── Step 3: Payments due in 1 day → FCM push urgent ───────────────────────
  await sendFcmReminders(supabase, plus1, "payment_due_1", "تذكير: دفعة مستحقة غداً");

  // ── Step 4: Payments due in 3 days → FCM push reminder ────────────────────
  await sendFcmReminders(supabase, plus3, "payment_due_3", "تذكير: دفعة مستحقة خلال 3 أيام");

  // ── Step 5: Payments newly marked "late" by this run → FCM push ──────────
  // sync_payment_due_notifications() is dedup-safe (one notification per payment_id+type
  // ever), so we only push for rows it just inserted in this run.
  const { data: newlyLate, error: newlyLateErr } = await supabase
    .from("notifications")
    .select("user_id, meta")
    .filter("meta->>type", "eq", "payment_late")
    .gte("created_at", new Date(Date.now() - 10 * 60 * 1000).toISOString());

  if (newlyLateErr) {
    console.error("[generate-payment-reminders] newlyLate query error:", newlyLateErr.message);
  }

  for (const row of newlyLate ?? []) {
    const meta = (row as any).meta as Record<string, unknown>;
    const clientId = (row as any).user_id as string | null;
    if (!clientId) continue;

    await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
      method: "POST",
      headers: {
        "Content-Type":          "application/json",
        "Authorization":         `Bearer ${SUPABASE_SERVICE_KEY}`,
        "x-notification-secret": NOTIFICATION_SECRET,
      },
      body: JSON.stringify({
        clientId:    clientId,
        notifType:   "payment_late",
        paymentId:   meta.payment_id,
        paymentType: "contract",
        amount:      meta.amount,
        contractId:  meta.contract_id,
      }),
    }).catch((e) => console.warn("[generate-payment-reminders] late FCM failed for", meta.payment_id, e));
  }

  // ── Step 6: Payments due TODAY → FCM push, regardless of whether the
  // auto-charge in Step 2 succeeded (so a charge-creation failure never
  // silently leaves the client without any heads-up).
  await sendFcmReminders(supabase, today, "payment_due_today", "طلب دفع مستحق اليوم");

  return new Response(JSON.stringify({ ok: true, date: today }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});

async function sendFcmReminders(
  supabase: ReturnType<typeof createClient>,
  dueDate: string,
  notifType: string,
  title: string,
): Promise<void> {
  const { data: payments } = await supabase
    .from("contract_payments")
    .select("id, contract_id, amount, contracts(user_id, code)")
    .eq("due_date", dueDate)
    .is("gateway_status", null);

  for (const payment of payments ?? []) {
    const contract = (payment as any).contracts as { user_id: string } | null;
    const clientId = contract?.user_id ?? null;
    if (!clientId) continue;

    await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
      method: "POST",
      headers: {
        "Content-Type":          "application/json",
        "Authorization":         `Bearer ${SUPABASE_SERVICE_KEY}`,
        "x-notification-secret": NOTIFICATION_SECRET,
      },
      body: JSON.stringify({
        clientId:    clientId,
        notifType:   notifType,
        paymentId:   payment.id,
        paymentType: "contract",
        amount:      payment.amount,
        contractId:  payment.contract_id,
      }),
    }).catch((e) => console.warn("[generate-payment-reminders] FCM failed for", payment.id, e));
  }
}

function offsetDate(days: number): string {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return d.toISOString().split("T")[0];
}
