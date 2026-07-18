import { AdminRepository } from "@domain/repositories/AdminRepository";
import { Result } from "@core/types/Result";
import { AppError } from "@core/errors/AppError";
import { UpdateContractDTO } from "@application/dtos/UpdateContractDTO";

export const updateContract = async (
  repo: AdminRepository,
  payload: UpdateContractDTO
): Promise<Result<void>> => {
  try {
    await repo.updateContract(payload);
    return { ok: true, data: undefined };
  } catch (error) {
    return { ok: false, error: new AppError("تعذر تحديث العقد", "INTERNAL") };
  }
};