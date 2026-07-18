import { AuthRepository } from "@domain/repositories/AuthRepository";
import { Result } from "@core/types/Result";
import { AppError } from "@core/errors/AppError";
import { loginSchema } from "@application/validation/schemas";

export const login = async (
  repo: AuthRepository,
  payload: { email: string; password: string }
): Promise<Result<void>> => {
  const parsed = loginSchema.safeParse(payload);
  if (!parsed.success) {
    return { ok: false, error: new AppError("بيانات دخول غير صحيحة", "VALIDATION") };
  }
  try {
    await repo.login(payload.email, payload.password);
    return { ok: true, data: undefined };
  } catch (error) {
    return { ok: false, error: new AppError("فشل تسجيل الدخول", "UNAUTHORIZED") };
  }
};
