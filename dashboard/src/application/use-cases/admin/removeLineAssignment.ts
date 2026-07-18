import { AdminRepository } from "@domain/repositories/AdminRepository";
import { Result } from "@core/types/Result";
import { AppError } from "@core/errors/AppError";

export const removeLineAssignment = async (
  repo: AdminRepository,
  supervisorId: string
): Promise<Result<void>> => {
  if (!supervisorId) {
    return { ok: false, error: new AppError("معرف المشرف مطلوب", "VALIDATION") };
  }
  try {
    await repo.removeLineAssignment(supervisorId);
    return { ok: true, data: undefined };
  } catch (error) {
    return { ok: false, error: new AppError("تعذر إزالة تعيين الخط", "INTERNAL") };
  }
};
