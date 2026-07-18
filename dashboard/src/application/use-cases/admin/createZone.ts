import { LineRepository } from "@domain/repositories/LineRepository";
import { Result } from "@core/types/Result";
import { AppError } from "@core/errors/AppError";
import { CreateZoneDTO } from "@application/dtos/CreateZoneDTO";
import { createZoneSchema } from "@application/validation/schemas";

export const createZone = async (
  repo: LineRepository,
  payload: CreateZoneDTO
): Promise<Result<void>> => {
  const parsed = createZoneSchema.safeParse(payload);
  if (!parsed.success) {
    return { ok: false, error: new AppError("بيانات المنطقة غير صحيحة", "VALIDATION") };
  }
  try {
    await repo.createZone(payload);
    return { ok: true, data: undefined };
  } catch {
    return { ok: false, error: new AppError("تعذر إنشاء المنطقة", "INTERNAL") };
  }
};
