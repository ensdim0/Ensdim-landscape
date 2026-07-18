import { AdminRepository } from "@domain/repositories/AdminRepository";
import { Result } from "@core/types/Result";
import { AppError } from "@core/errors/AppError";

export const deleteContract = async (
  repo: AdminRepository,
  id: string
): Promise<Result<void>> => {
  try {
    await repo.deleteContract(id);
    return { ok: true, data: undefined };
  } catch (error) {
    return { ok: false, error: new AppError("تعذر حذف العقد", "INTERNAL") };
  }
};