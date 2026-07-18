import { LineRepository } from "@domain/repositories/LineRepository";
import { Result } from "@core/types/Result";
import { AppError } from "@core/errors/AppError";

export const deleteLine = async (
  repo: LineRepository,
  id: string
): Promise<Result<void>> => {
  try {
    await repo.deleteLine(id);
    return { ok: true, data: undefined };
  } catch (err: any) {
    return {
      ok: false,
      error: new AppError(err?.message || "تعذر حذف الخط", "INTERNAL"),
    };
  }
};
