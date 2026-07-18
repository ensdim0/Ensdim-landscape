import { AdminRepository } from "@domain/repositories/AdminRepository";
import { Result } from "@core/types/Result";
import { AppError } from "@core/errors/AppError";
import { assignLineSchema } from "@application/validation/schemas";
import { AssignLineDTO } from "@application/dtos/SupervisorDTO";

export const assignLineToSupervisor = async (
  repo: AdminRepository,
  payload: AssignLineDTO
): Promise<Result<void>> => {
  const parsed = assignLineSchema.safeParse(payload);
  if (!parsed.success) {
    return { ok: false, error: new AppError("بيانات التعيين غير صحيحة", "VALIDATION") };
  }
  try {
    await repo.assignLineToSupervisor(parsed.data);
    return { ok: true, data: undefined };
  } catch (error) {
    return { ok: false, error: new AppError("تعذر تعيين الخط للمشرف", "INTERNAL") };
  }
};
