import { AuthRepository } from "@domain/repositories/AuthRepository";
import { Result } from "@core/types/Result";
import { AppError } from "@core/errors/AppError";

export const logout = async (repo: AuthRepository): Promise<Result<void>> => {
  try {
    await repo.logout();
    return { ok: true, data: undefined };
  } catch (error) {
    return { ok: false, error: new AppError("فشل تسجيل الخروج", "INTERNAL") };
  }
};
