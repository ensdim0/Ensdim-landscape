import { LineRepository } from "@domain/repositories/LineRepository";
import { Result } from "@core/types/Result";
import { AppError } from "@core/errors/AppError";

export const deleteZone = async (
  repo: LineRepository,
  id: string
): Promise<Result<void>> => {
  if (!id) {
    return { ok: false, error: new AppError("معرف المنطقة مطلوب", "VALIDATION") };
  }
  try {
    await repo.deleteZone(id);
    return { ok: true, data: undefined };
  } catch {
    return { ok: false, error: new AppError("تعذر حذف المنطقة", "INTERNAL") };
  }
};