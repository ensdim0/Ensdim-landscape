import { AdminRepository } from "@domain/repositories/AdminRepository";
import { Result } from "@core/types/Result";
import { AppError } from "@core/errors/AppError";
import { Contract } from "@domain/entities/Contract";
import { CreateContractDTO } from "@application/dtos/CreateContractDTO";
import { createContractSchema } from "@application/validation/schemas";

export const createContract = async (
  repo: AdminRepository,
  payload: CreateContractDTO
): Promise<Result<Contract>> => {
  const parsed = createContractSchema.safeParse(payload);
  if (!parsed.success) {
    console.error("Validation Error:", parsed.error); 
    return { ok: false, error: new AppError(`بيانات العقد غير صحيحة: ${parsed.error.errors[0]?.message || 'خطأ في التنسيق'}`, "VALIDATION") };
  }
  try {
    const contract = await repo.createContract(payload);
    return { ok: true, data: contract };
  } catch (error: any) {
    return { ok: false, error: new AppError(error.message || "تعذر إنشاء العقد", "INTERNAL") };
  }
};
