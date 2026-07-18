import { LineRepository } from "@domain/repositories/LineRepository";
import { Result } from "@core/types/Result";
import { AppError } from "@core/errors/AppError";
import { CreateLineDTO } from "@application/dtos/CreateLineDTO";
import { createLineSchema } from "@application/validation/schemas";

export const createLine = async (
  repo: LineRepository,
  payload: CreateLineDTO
): Promise<Result<void>> => {
  const parsed = createLineSchema.safeParse(payload);
  if (!parsed.success) {
    return { ok: false, error: new AppError("بيانات الخط غير صحيحة", "VALIDATION") };
  }
  try {
    await repo.createLine(payload);
    return { ok: true, data: undefined };
  } catch {
    return { ok: false, error: new AppError("تعذر إنشاء الخط", "INTERNAL") };
  }
};
