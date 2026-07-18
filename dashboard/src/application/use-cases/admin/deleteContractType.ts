import { AdminRepository } from "@domain/repositories/AdminRepository";
import { Result } from "@core/types/Result";
import { AppError } from "@core/errors/AppError";

export async function deleteContractType(
  repo: AdminRepository,
  id: string
): Promise<Result<void>> {
  try {
    await repo.deleteContractType(id);
    return { ok: true, data: undefined };
  } catch (error: any) {
    return { ok: false, error: new AppError(error.message || "تعذر حذف نوع العقد", "INTERNAL") };
  }
}