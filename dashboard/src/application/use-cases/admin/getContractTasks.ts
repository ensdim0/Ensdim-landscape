import { AdminRepository } from "@domain/repositories/AdminRepository";
import { Result } from "@core/types/Result";
import { AppError } from "@core/errors/AppError";
import { ContractTask } from "@domain/entities/ContractTask";

export const getVisitTasks = async (
  repo: AdminRepository,
  visitId: string
): Promise<Result<ContractTask[]>> => {
  if (!visitId) {
    return { ok: false, error: new AppError("معرف الزيارة مطلوب", "VALIDATION") };
  }
  try {
    const data = await repo.listVisitTasks(visitId);
    return { ok: true, data };
  } catch (error) {
    return { ok: false, error: new AppError("تعذر تحميل مهام الزيارة", "INTERNAL") };
  }
};

export const getAllVisitTasks = async (
  repo: AdminRepository,
  visitIds: string[]
): Promise<Result<ContractTask[]>> => {
  try {
    const data = await repo.listAllVisitTasks(visitIds);
    return { ok: true, data };
  } catch (error) {
    return { ok: false, error: new AppError("تعذر تحميل المهام", "INTERNAL") };
  }
};
