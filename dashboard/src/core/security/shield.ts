/**
 * Runtime security module.
 *
 * Notes:
 * - Previous versions of this module modified global browser state
 *   (overrode console, froze prototypes, blocked devtools, cleared DOM)
 *   which broke observability, third-party libraries, and made debugging
 *   and incident response impossible.
 *
 * - This file purposely avoids mutating globals. All meaningful
 *   security controls (RLS, CSP, X-Frame-Options, secure cookies)
 *   must be enforced server-side and via hosting headers.
 */

export const initSecurityShield = (): void => {
  // Intentionally a no-op for runtime protections. Keep this hook to
  // allow lightweight, non-destructive initialization in the future
  // (attach safe listeners, report-only checks, etc.).
  if (!import.meta.env.PROD) {
    // eslint-disable-next-line no-console
    console.info("[Security] Dev mode — runtime protections disabled (no-op)");
    return;
  }

  // In production we intentionally avoid destructive client-side protections.
  // Server-side headers (CSP, X-Frame-Options) and authenticated RPCs
  // are the correct enforcement points.
  // eslint-disable-next-line no-console
  console.info("[Security] Production mode — client-side runtime protections are disabled; rely on server-side controls.");
};
