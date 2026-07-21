// Supabase Edge Function: cleanup-old-data
// Daily cron function that calls public.cleanup_old_data() to purge:
//  - read notifications older than 90 days
//  - audit_logs older than 180 days
// Keeps the `notifications`/`audit_logs` tables from growing unbounded
// against the Free tier's 500MB database allowance.
//
// Schedule in Supabase Dashboard: 0 3 * * *  (03:00 UTC = 06:00 KWT)
//
// Required Supabase secrets:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (injected automatically)

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL         = Deno.env.get("SUPABASE_URL")         ?? "";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

serve(async (_req: Request): Promise<Response> => {
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
