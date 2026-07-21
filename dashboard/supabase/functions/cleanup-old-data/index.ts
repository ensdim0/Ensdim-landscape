// Supabase Edge Function: cleanup-old-data
// Daily cron function that calls public.cleanup_old_data() to purge:
//  - read notifications older than 90 days
//  - audit_logs older than 180 days
// Keeps the `notifications`/`audit_logs` tables from growing unbounded
// against the Free tier's 500MB database allowance.
//
// Schedule in Supabase Dashboard: 0 3 * * *  (03:00 UTC = 06:00 KWT)
//
// SECURITY: this endpoint has no other authentication, so it's gated by a
// shared secret the Dashboard cron job must send as `x-cron-secret` — set the
// SAME value as the CRON_SECRET Supabase secret and the private.app_config
// 'cron_secret' row (see 2026-08-01_cron_secret_config.sql).
//
// Required Supabase secrets:
//   CRON_SECRET, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (injected automatically)

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CRON_SECRET          = Deno.env.get("CRON_SECRET")          ?? "";
const SUPABASE_URL         = Deno.env.get("SUPABASE_URL")         ?? "";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

serve(async (req: Request): Promise<Response> => {
  if (!CRON_SECRET || req.headers.get("x-cron-secret") !== CRON_SECRET) {
    return new Response("Unauthorized", { status: 401 });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  const { error } = await supabase.rpc("cleanup_old_data");
  if (error) {
    console.error("[cleanup-old-data] error:", error.message);
  } else {
    console.log("[cleanup-old-data] done");
  }

  return new Response(JSON.stringify({ ok: !error }), {
    status: error ? 500 : 200,
    headers: { "Content-Type": "application/json" },
  });
});
