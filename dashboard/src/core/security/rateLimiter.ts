/**
 * Rate limiter for login attempts — prevents brute force attacks.
 * Uses in-memory tracking (resets on page reload, but that's fine
 * because attackers would need to reload to retry anyway).
 */

const WINDOW_MS = 15 * 60 * 1000; 
const MAX_ATTEMPTS = 5;          
const LOCKOUT_MS = 30 * 60 * 1000; 

interface AttemptRecord {
  attempts: number;
  firstAttempt: number;
  lockedUntil: number | null;
}

const store = new Map<string, AttemptRecord>();

const normalizeKey = (key: string): string => (typeof key === 'string' ? key : '').toLowerCase().trim();


export const checkRateLimit = (key: string): { allowed: boolean; retryAfterMs: number; remainingAttempts: number } => {
  const now = Date.now();
  const normalizedKey = normalizeKey(key);
  let record = store.get(normalizedKey);

  if (!record) {
    return { allowed: true, retryAfterMs: 0, remainingAttempts: MAX_ATTEMPTS };
  }

  if (record.lockedUntil && now < record.lockedUntil) {
    return { allowed: false, retryAfterMs: record.lockedUntil - now, remainingAttempts: 0 };
  }

  if (record.lockedUntil && now >= record.lockedUntil) {
    store.delete(normalizedKey);
    return { allowed: true, retryAfterMs: 0, remainingAttempts: MAX_ATTEMPTS };
  }

  if (now - record.firstAttempt > WINDOW_MS) {
    store.delete(normalizedKey);
    return { allowed: true, retryAfterMs: 0, remainingAttempts: MAX_ATTEMPTS };
  }

  const remaining = MAX_ATTEMPTS - record.attempts;
  return { allowed: remaining > 0, retryAfterMs: remaining > 0 ? 0 : LOCKOUT_MS, remainingAttempts: Math.max(0, remaining) };
};

export const recordFailedAttempt = (key: string): void => {
  const now = Date.now();
  const normalizedKey = normalizeKey(key);
  let record = store.get(normalizedKey);

  if (!record || now - record.firstAttempt > WINDOW_MS) {
    record = { attempts: 1, firstAttempt: now, lockedUntil: null };
  } else {
    record.attempts += 1;
    if (record.attempts >= MAX_ATTEMPTS) {
      record.lockedUntil = now + LOCKOUT_MS;
    }
  }

  store.set(normalizedKey, record);
};

export const resetRateLimit = (key: string): void => {
  store.delete(normalizeKey(key));
};


export const formatLockoutTime = (ms: number): string => {
  const minutes = Math.ceil(ms / 60000);
  if (minutes <= 1) return "أقل من دقيقة";
  return `${minutes} دقيقة`;
};
