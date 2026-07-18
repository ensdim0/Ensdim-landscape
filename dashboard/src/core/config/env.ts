import { z } from "zod";

// These are defined via Vite `define` in `vite.config.ts` at build-time.
declare const __SUPABASE_URL__: string | undefined;
declare const __SUPABASE_ANON_KEY__: string | undefined;
const rawEnv = {
  VITE_SUPABASE_URL: import.meta.env.VITE_SUPABASE_URL ?? __SUPABASE_URL__,
  VITE_SUPABASE_ANON_KEY: import.meta.env.VITE_SUPABASE_ANON_KEY ?? __SUPABASE_ANON_KEY__,
  VITE_APP_ENV: import.meta.env.VITE_APP_ENV ?? (import.meta.env.DEV ? "development" : "production"),
  VITE_LOG_ENDPOINT: import.meta.env.VITE_LOG_ENDPOINT ?? undefined
};

const EnvSchema = z.object({
  VITE_SUPABASE_URL: z.string().url(),
  VITE_SUPABASE_ANON_KEY: z.string().min(10),
  VITE_APP_ENV: z.enum(["development", "staging", "production"]),
  VITE_LOG_ENDPOINT: z.string().url().optional()
});

const parsed = EnvSchema.safeParse(rawEnv);
if (!parsed.success) {
  // Fail fast: missing or invalid envs are a security risk and must be fixed.
  // Developer-friendly output prints the validation errors.
  // Note: this throws during app bootstrap so CI/build will fail on bad config.
  // Do NOT embed secrets in repo; set them via environment or CI.
  // eslint-disable-next-line no-console
  console.error("Environment validation failed:", parsed.error.format());
  throw new Error("Invalid environment configuration. Check VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY.");
}

export const env = {
  supabaseUrl: parsed.data.VITE_SUPABASE_URL,
  supabaseAnonKey: parsed.data.VITE_SUPABASE_ANON_KEY,
  appEnv: parsed.data.VITE_APP_ENV,
  logEndpoint: parsed.data.VITE_LOG_ENDPOINT ?? null
} as const;
