import { AdminRepository } from "@domain/repositories/AdminRepository";
import { ContractType } from "@domain/entities/ContractType";
import { Result } from "@core/types/Result";
import { AppError } from "@core/errors/AppError";

export async function getContractTypes(repo: AdminRepository): Promise<Result<ContractType[]>> {
  try {
    const types = await repo.listContractTypes();
    return { ok: true, data: types };
  } catch (error: any) {
    return { ok: false, error: new AppError(error.message || "تعذر تحميل أنواع العقود", "INTERNAL") };
  }
}