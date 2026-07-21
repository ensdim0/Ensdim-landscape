import { AuthRepository, RegisterCompanyPayload } from "@domain/repositories/AuthRepository";
import { Result } from "@core/types/Result";
import { AppError } from "@core/errors/AppError";
import { registerCompanySchema } from "@application/validation/schemas";

export const registerCompany = async (
  repo: AuthRepository,
  payload: RegisterCompanyPayload
): Promise<Result<void>> => {
  const parsed = registerCompanySchema.safeParse(payload);
  if (!parsed.success) {
    return { ok: false, error: new AppError("يرجى مراجعة بيانات التسجيل", "VALIDATION") };
  }
  try {
    await repo.registerCompany(payload);
    return { ok: true, data: undefined };
  } catch (error: any) {
    const message = error?.message?.includes("already registered")
      ? "البريد الإلكتروني مستخدم بالفعل"
      : "فشل إنشاء الحساب";
    return { ok: false, error: new AppError(message, "VALIDATION") };
  }
};
