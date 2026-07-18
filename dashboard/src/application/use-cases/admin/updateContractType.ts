import { AdminRepository } from "@domain/repositories/AdminRepository";
import { ContractType } from "@domain/entities/ContractType";
import { Result } from "@core/types/Result";
import { AppError } from "@core/errors/AppError";
import { ContractTerm } from "@domain/entities/ContractTerm";

export async function updateContractType(
  repo: AdminRepository,
  payload: { id: string; name: string; description?: string; terms?: ContractTerm[] }
): Promise<Result<ContractType>> {
  try {
    if (!payload.name) return { ok: false, error: new AppError("الاسم مطلوب", "VALIDATION") };
    const type = await repo.updateContractType(payload);
    return { ok: true, data: type };
  } catch (error: any) {
    return { ok: false, error: new AppError(error.message || "تعذر تحديث نوع العقد", "INTERNAL") };
  }
}