import { AppError } from "@core/errors/AppError";

export type Result<T> =
  | { ok: true; data: T }
  | { ok: false; error: AppError };
