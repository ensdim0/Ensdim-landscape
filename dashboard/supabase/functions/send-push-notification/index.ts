// Supabase Edge Function: send-push-notification
// Handles multiple notification types for supervisors AND clients:
//
//   Supervisor types (existing):
//     - { supervisorId, lineId }              → line_assigned
//     - { supervisorId, taskId }              → standalone_task_assigned
//     - { supervisorId, visitId, contractId, noteType: 'supervisor_note' }
//
//   Client types (new — payment):
//     - { clientId, notifType: 'payment_request',   paymentId, paymentType, amount, contractId? }
//     - { clientId, notifType: 'payment_due_1',      paymentId, amount }
//     - { clientId, notifType: 'payment_due_3',      paymentId, amount }
//     - { clientId, notifType: 'payment_due_today',  paymentId, amount }
//     - { clientId, notifType: 'payment_late',       paymentId, amount }
//     - { clientId, notifType: 'payment_confirmed',  paymentId, amount }
//
// Required Supabase secrets:
//   NOTIFICATION_SECRET, FCM_PROJECT_ID, FCM_SERVICE_ACCOUNT
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (injected automatically)

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const NOTIFICATION_SECRET      = Deno.env.get("NOTIFICATION_SECRET")      ?? "";
const FCM_PROJECT_ID           = Deno.env.get("FCM_PROJECT_ID")           ?? "";
const FCM_SERVICE_ACCOUNT_JSON = Deno.env.get("FCM_SERVICE_ACCOUNT")      ?? "";
const SUPABASE_URL             = Deno.env.get("SUPABASE_URL")             ?? "";
const SUPABASE_SERVICE_KEY     = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

serve(async (req: Request): Promise<Response> => {
  // ── Auth ───────────────────────────────────────────────────────────────────
  const incomingSecret = req.headers.get("x-notification-secret");
  if (!NOTIFICATION_SECRET || incomingSecret !== NOTIFICATION_SECRET) {
    return new Response("Unauthorized", { status: 401 });
  }

  // ── Parse body ─────────────────────────────────────────────────────────────
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return new Response("Bad Request: invalid JSON", { status: 400 });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  // ── Route to correct handler ───────────────────────────────────────────────
  if (body.clientId) {
    return await handleClientNotification(body, supabase);
  }
  return await handleSupervisorNotification(body, supabase);
});

// ════════════════════════════════════════════════════════════════════════════
// CLIENT — Payment notifications
// ════════════════════════════════════════════════════════════════════════════

async function handleClientNotification(
  body: Record<string, unknown>,
  supabase: ReturnType<typeof createClient>,
): Promise<Response> {
  const clientId    = body.clientId   as string;
  const notifType   = (body.notifType ?? "payment_request") as string;
  const paymentId   = body.paymentId  as string | undefined;
  const amount      = body.amount     as number | undefined;
  const contractId  = body.contractId as string | undefined;
  const paymentType = body.paymentType as string | undefined;

  if (!clientId) {
    return new Response("Bad Request: clientId required", { status: 400 });
  }

  // Fetch client FCM token
  const { data: tokenRow } = await supabase
    .from("device_tokens")
    .select("token")
    .eq("user_id", clientId)
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (!tokenRow?.token) {
    console.warn("[send-push-notification] no device token for client:", clientId);
    return new Response("No device token for client", { status: 200 });
  }

  const amountLabel = amount != null ? ` ${(amount as number).toFixed(3)} KWD` : "";

  let title: string;
  let notifBody: string;
  const dataPayload: Record<string, string> = {
    type:        notifType,
    paymentId:   paymentId   ?? "",
    paymentType: paymentType ?? "contract",
    contractId:  contractId  ?? "",
  };

  switch (notifType) {
    case "payment_request":
    case "payment_due_today":
      title     = "طلب دفع — مستحق اليوم";
      notifBody = `مبلغ${amountLabel} مستحق الآن — اضغط للدفع`;
      break;
    case "payment_due_1":
      title     = "تذكير: دفعة مستحقة غداً";
      notifBody = `مبلغ${amountLabel} مستحق غداً`;
      break;
    case "payment_due_3":
      title     = "تذكير: دفعة مستحقة خلال 3 أيام";
      notifBody = `مبلغ${amountLabel} مستحق خلال 3 أيام`;
      break;
    case "payment_late":
      title     = "تنبيه: دفعة متأخرة";
      notifBody = `مبلغ${amountLabel} متأخر عن السداد — يرجى الدفع الآن`;
      break;
    case "payment_confirmed":
      title     = "تم استلام دفعتك بنجاح ✓";
      notifBody = `تم تأكيد دفع مبلغ${amountLabel} بنجاح`;
      break;
    default:
      title     = "إشعار دفع";
      notifBody = `مبلغ${amountLabel}`;
  }

  return await sendFCM(tokenRow.token as string, title, notifBody, dataPayload);
}

// ════════════════════════════════════════════════════════════════════════════
// SUPERVISOR — Existing notification types (unchanged)
// ════════════════════════════════════════════════════════════════════════════

async function handleSupervisorNotification(
  body: Record<string, unknown>,
  supabase: ReturnType<typeof createClient>,
): Promise<Response> {
  const supervisorId = body.supervisorId as string | undefined;
  const lineId       = body.lineId       as string | undefined;
  const taskId       = body.taskId       as string | undefined;
  const visitId      = body.visitId      as string | undefined;
  const contractId   = body.contractId   as string | undefined;
  const noteType     = body.noteType     as string | undefined;

  if (!supervisorId || (!lineId && !taskId && !visitId)) {
    return new Response(
      "Bad Request: supervisorId and (lineId, taskId, or visitId) required",
      { status: 400 },
    );
  }

  const { data: tokenRow, error: tokenErr } = await supabase
    .from("device_tokens")
    .select("token")
    .eq("user_id", supervisorId)
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (tokenErr) {
    console.error("[send-push-notification] token lookup error:", tokenErr.message);
    return new Response("Internal error", { status: 500 });
  }
  if (!tokenRow?.token) {
    return new Response("No device token for supervisor", { status: 200 });
  }

  let title: string;
  let notifBody: string;
  let dataPayload: Record<string, string>;

  if (taskId) {
    const { data: task } = await supabase
      .from("standalone_tasks")
      .select("title, task_date")
      .eq("id", taskId)
      .maybeSingle();

    const taskTitle = (task?.title    as string | null) ?? "مهمة جديدة";
    const taskDate  = (task?.task_date as string | null)
      ? ` – ${task!.task_date}`
      : "";

    title     = "مهمة جديدة";
    notifBody = `تم تعيينك على مهمة: ${taskTitle}${taskDate}`;
    dataPayload = { type: "standalone_task_assigned", taskId };
  } else if (noteType === "supervisor_note" && visitId) {
    title     = "ملاحظة جديدة على زيارة";
    notifBody = "أضاف المسؤول ملاحظة على إحدى زياراتك";
    dataPayload = {
      type:       "supervisor_note",
      visitId,
      contractId: contractId ?? "",
    };
  } else {
    const { data: line } = await supabase
      .from("geographic_lines")
      .select("name")
      .eq("id", lineId!)
      .maybeSingle();

    const lineName = (line?.name as string | null) ?? "خط جديد";
    title     = "تعيين خط جديد";
    notifBody = `تم تعيينك في خط: ${lineName}`;
    dataPayload = { type: "line_assigned", lineId: lineId! };
  }

  return await sendFCM(tokenRow.token as string, title, notifBody, dataPayload);
}

// ════════════════════════════════════════════════════════════════════════════
// Shared FCM send helper
// ════════════════════════════════════════════════════════════════════════════

async function sendFCM(
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<Response> {
  const fcmAccessToken = await getFCMAccessToken(FCM_SERVICE_ACCOUNT_JSON);
  if (!fcmAccessToken) {
    console.error("[send-push-notification] failed to obtain FCM access token");
    return new Response("FCM auth failed", { status: 500 });
  }

  const fcmResponse = await fetch(
    `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization:  `Bearer ${fcmAccessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data,
          android: {
            priority: "high",
            notification: {
              channel_id: "payment_notifications",
              sound:      "default",
            },
          },
          apns: {
            headers: { "apns-priority": "10" },
            payload: {
              aps: {
                alert: { title, body },
                sound: "default",
                badge: 1,
                "content-available": 1,
              },
            },
          },
        },
      }),
    },
  );

  if (!fcmResponse.ok) {
    const errBody = await fcmResponse.text();
    console.error("[send-push-notification] FCM error:", fcmResponse.status, errBody);
    return new Response("FCM send failed", { status: 500 });
  }

  return new Response("OK", { status: 200 });
}

// ── FCM OAuth2 helpers (unchanged from original) ───────────────────────────

async function getFCMAccessToken(serviceAccountJson: string): Promise<string | null> {
  try {
    const sa  = JSON.parse(serviceAccountJson);
    const now = Math.floor(Date.now() / 1000);

    const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
    const claims = base64url(
      JSON.stringify({
        iss:   sa.client_email,
        sub:   sa.client_email,
        aud:   "https://oauth2.googleapis.com/token",
        iat:   now,
        exp:   now + 3600,
        scope: "https://www.googleapis.com/auth/firebase.messaging",
      }),
    );

    const signingInput = `${header}.${claims}`;
    const privateKey   = await importRSAPrivateKey(sa.private_key as string);
    const sigBytes     = await crypto.subtle.sign(
      { name: "RSASSA-PKCS1-v1_5" },
      privateKey,
      new TextEncoder().encode(signingInput),
    );

    const jwt = `${signingInput}.${base64url(sigBytes)}`;

    const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
      method:  "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body:    new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion:  jwt,
      }),
    });

    if (!tokenRes.ok) {
      console.error("[getFCMAccessToken] token exchange failed:", await tokenRes.text());
      return null;
    }

    const { access_token } = await tokenRes.json();
    return (access_token as string) ?? null;
  } catch (e) {
    console.error("[getFCMAccessToken] exception:", e);
    return null;
  }
}

function base64url(input: string | ArrayBuffer): string {
  let bytes: Uint8Array;
  if (typeof input === "string") {
    bytes = new TextEncoder().encode(input);
  } else {
    bytes = new Uint8Array(input);
  }
  const base64 = btoa(String.fromCharCode(...bytes));
  return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function importRSAPrivateKey(pem: string): Promise<CryptoKey> {
  const pemBody = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const keyBytes = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    keyBytes,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}
