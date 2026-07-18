import { env } from "@core/config/env";

type LogLevel = "debug" | "info" | "warn" | "error";

const isProd = env.appEnv === "production";
const remoteUrl = env.logEndpoint ?? null;

const formatPayload = (level: LogLevel, message: string, meta?: Record<string, unknown>) => ({
  timestamp: new Date().toISOString(),
  level,
  message,
  meta: meta ?? {},
  url: typeof window !== "undefined" ? window.location.href : undefined,
  userAgent: typeof navigator !== "undefined" ? navigator.userAgent : undefined
});

const sendToRemote = (body: object) => {
  if (!remoteUrl) return;

  try {
    const payload = JSON.stringify(body);

    // Prefer sendBeacon for reliability on page unload.
    if (typeof navigator !== "undefined" && "sendBeacon" in navigator) {
      try {
        // sendBeacon doesn't allow custom headers or large payloads.
        // We still JSON.stringify for consistency.
        (navigator as any).sendBeacon(remoteUrl, payload);
        return;
      } catch {
        // fallback to fetch
      }
    }

    // Use fetch with keepalive to avoid blocking unload.
    fetch(remoteUrl, {
      method: "POST",
      keepalive: true,
      headers: {
        "Content-Type": "application/json"
      },
      body: payload
    }).catch(() => {
      // swallow network errors — telemetry must never crash the app
    });
  } catch {
    // ignore serialization errors
  }
};

export const initLogger = () => {
  if (typeof window === "undefined") return;

  // Capture global errors
  window.addEventListener("error", (ev) => {
    try {
      const payload = formatPayload("error", (ev.error && ev.error.message) || ev.message || "window error", {
        filename: (ev as any).filename,
        lineno: (ev as any).lineno,
        colno: (ev as any).colno
      });
      if (!isProd) console.error(payload);
      sendToRemote(payload);
    } catch {
      // no-op
    }
  });

  window.addEventListener("unhandledrejection", (ev) => {
    try {
      const reason = (ev as PromiseRejectionEvent).reason;
      const payload = formatPayload("error", "Unhandled promise rejection", { reason });
      if (!isProd) console.error(payload);
      sendToRemote(payload);
    } catch {
      // no-op
    }
  });
};

export const debug = (message: string, meta?: Record<string, unknown>) => {
  const payload = formatPayload("debug", message, meta);
  if (!isProd) console.debug(payload);
  if (isProd) sendToRemote(payload);
};

export const info = (message: string, meta?: Record<string, unknown>) => {
  const payload = formatPayload("info", message, meta);
  // Keep console output for observability in staging and production if needed.
  // Do not override native console methods globally.
  // eslint-disable-next-line no-console
  console.info(payload);
  sendToRemote(payload);
};

export const warn = (message: string, meta?: Record<string, unknown>) => {
  const payload = formatPayload("warn", message, meta);
  // eslint-disable-next-line no-console
  console.warn(payload);
  sendToRemote(payload);
};

export const error = (message: string, meta?: Record<string, unknown>) => {
  const payload = formatPayload("error", message, meta);
  // eslint-disable-next-line no-console
  console.error(payload);
  sendToRemote(payload);
};
