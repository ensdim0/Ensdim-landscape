import { AdminRepository } from "@domain/repositories/AdminRepository";
import { Result } from "@core/types/Result";
import { AppError } from "@core/errors/AppError";
import { Contract } from "@domain/entities/Contract";

export const getLineContracts = async (
  repo: AdminRepository,
  lineId: string
): Promise<Result<Contract[]>> => {
  if (!lineId) {
    return { ok: false, error: new AppError("معرف الخط مطلوب", "VALIDATION") };
  }
  try {
    const data = await repo.getContractsByLineId(lineId);
    return { ok: true, data };
  } catch (error) {
    return { ok: false, error: new AppError("تعذر تحميل عقود الخط", "INTERNAL") };
  }
};
