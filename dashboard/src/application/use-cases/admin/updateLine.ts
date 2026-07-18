import { LineRepository } from "@domain/repositories/LineRepository";
import { Result } from "@core/types/Result";
import { AppError } from "@core/errors/AppError";
import { UpdateLineDTO } from "@application/dtos/UpdateLineDTO";
import { updateLineSchema } from "@application/validation/schemas";

export const updateLine = async (
  repo: LineRepository,
  payload: UpdateLineDTO
): Promise<Result<void>> => {
  const parsed = updateLineSchema.safeParse(payload);
  if (!parsed.success) {
    return { ok: false, error: new AppError(parsed.error.errors[0]?.message || "بيانات الخط غير صحيحة", "VALIDATION") };
  }
  try {
    await repo.updateLine(payload);
    return { ok: true, data: undefined };
  } catch(error: any) {
    return { ok: false, error: new AppError(error.message || "تعذر تحديث الخط", "INTERNAL") };
  }
};
