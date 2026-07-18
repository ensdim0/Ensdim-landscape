import { AdminRepository } from "@domain/repositories/AdminRepository";
import { Result } from "@core/types/Result";
import { AppError } from "@core/errors/AppError";

export const deleteUser = async (
  repo: AdminRepository,
  id: string
): Promise<Result<void>> => {
  if (!id) {
    return { ok: false, error: new AppError("معرف المستخدم مطلوب", "VALIDATION") };
  }
  try {
    await repo.deleteUser(id);
    return { ok: true, data: undefined };
  } catch (error) {
    return { ok: false, error: new AppError("تعذر حذف المستخدم", "INTERNAL") };
  }
};
