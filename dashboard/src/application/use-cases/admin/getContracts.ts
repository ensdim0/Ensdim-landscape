import { AdminRepository } from "@domain/repositories/AdminRepository";
import { Contract } from "@domain/entities/Contract";
import { Result } from "@core/types/Result";
import { AppError } from "@core/errors/AppError";

export const getContracts = async (repo: AdminRepository): Promise<Result<Contract[]>> => {
  try {
    const contracts = await repo.listContracts();
    return { ok: true, data: contracts };
  } catch (error) {
    return { ok: false, error: new AppError("تعذر تحميل العقود", "INTERNAL") };
  }
};