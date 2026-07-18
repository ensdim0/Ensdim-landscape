import { AdminRepository } from "@domain/repositories/AdminRepository";
import { Result } from "@core/types/Result";
import { AppError } from "@core/errors/AppError";
import { z } from "zod";

export const updateUserSchema = z.object({
  id: z.string(),
  email: z.string().email().optional(),
  fullName: z.string().min(3).optional(),
  role: z.string().min(3).optional(),
  password: z.string().min(6).optional(),
  phone: z.string().optional(),
  assignedLineId: z.string().optional().nullable(),
  assignmentStartDate: z.string().optional().nullable(),
  assignmentEndDate: z.string().optional().nullable(),
  joinDate: z.string().optional().nullable()
});

export const updateUser = async (
  repo: AdminRepository,
  payload: z.infer<typeof updateUserSchema>
): Promise<Result<void>> => {
  const parsed = updateUserSchema.safeParse(payload);
  if (!parsed.success) {
    return { ok: false, error: new AppError(parsed.error.message, "VALIDATION") };
  }
  try {
    await repo.updateUser(payload);
    return { ok: true, data: undefined };
  } catch (error) {
    return { ok: false, error: new AppError("تعذر تحديث المستخدم", "INTERNAL") };
  }
};
