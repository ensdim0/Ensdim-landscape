import { AdminRepository } from "@domain/repositories/AdminRepository";
import { ContractType } from "@domain/entities/ContractType";
import { Result } from "@core/types/Result";
import { AppError } from "@core/errors/AppError";
import { ContractTerm } from "@domain/entities/ContractTerm";

export async function createContractType(
  repo: AdminRepository,
  payload: { name: string; description?: string; terms?: ContractTerm[] }
): Promise<Result<ContractType>> {
  try {
    if (!payload.name) return { ok: false, error: new AppError("الاسم مطلوب", "VALIDATION") };
    const type = await repo.createContractType(payload);
    return { ok: true, data: type };
  } catch (error: any) {
    return { ok: false, error: new AppError(error.message || "تعذر إنشاء نوع العقد", "INTERNAL") };
  }
}