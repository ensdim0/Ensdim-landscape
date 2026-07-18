import { createClient, SupabaseClient } from "@supabase/supabase-js";
import { env } from "@core/config/env";

const getStorageScope = (): string => {
  try {
    const host = new URL(env.supabaseUrl).hostname;
    const projectRef = host.split(".")[0] || "default";
    return projectRef.replace(/[^a-zA-Z0-9_-]/g, "") || "default";
  } catch {
    return "default";
  }
};

const storageScope = getStorageScope();
const STORAGE_PREFIX = `__fops_${storageScope}_`;
const AUTH_STORAGE_KEY = `field-ops-auth-${storageScope}`;
const MAX_AGE_MS = 72 * 60 * 60 * 1000;

const secureStorage = {
  getItem: (key: string): string | null => {
    try {
      const raw = window.localStorage.getItem(STORAGE_PREFIX + key);
      if (raw) {
        const parsed = JSON.parse(raw);
        if (parsed._exp && Date.now() > parsed._exp) {
          window.localStorage.removeItem(STORAGE_PREFIX + key);
          return null;
        }
        const val = parsed.v;
        return typeof val === "string" ? val : JSON.stringify(val);
      }
      const legacyPrefixed = window.localStorage.getItem(STORAGE_PREFIX + key);
      const legacy = window.localStorage.getItem(key);
      if (legacy) {
        secureStorage.setItem(key, legacy);
        window.localStorage.removeItem(key);
        return legacy;
      }
      return null;
    } catch {
      window.localStorage.removeItem(STORAGE_PREFIX + key);
      return null;
    }
  },
  setItem: (key: string, value: string): void => {
    try {
      const wrapper = JSON.stringify({ v: value, _exp: Date.now() + MAX_AGE_MS });
      window.localStorage.setItem(STORAGE_PREFIX + key, wrapper);
    } catch {
    }
  },
  removeItem: (key: string): void => {
    window.localStorage.removeItem(STORAGE_PREFIX + key);
    window.localStorage.removeItem(key); // Also clean legacy key
  }
};

let _instance: SupabaseClient | null = null;

function getSupabaseClient(): SupabaseClient {
  if (_instance) return _instance;

  _instance = createClient(env.supabaseUrl, env.supabaseAnonKey, {
    auth: {
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: false, 
      storage: typeof window !== "undefined" ? secureStorage : undefined,
      storageKey: AUTH_STORAGE_KEY
    },
    global: {
      headers: {
        "X-Client-Info": "field-ops-dashboard"
      }
    }
  });

  return _instance;
}

export const supabase = getSupabaseClient();
