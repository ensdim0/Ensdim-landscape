import { AdminRepository } from "@domain/repositories/AdminRepository";
import { Result } from "@core/types/Result";
import { AppError } from "@core/errors/AppError";
import { CreateUserDTO } from "@application/dtos/CreateUserDTO";
import { createUserSchema } from "@application/validation/schemas";

export const createUser = async (
  repo: AdminRepository,
  payload: CreateUserDTO
): Promise<Result<void>> => {
  const asTrimmedString = (value: unknown): string => (typeof value === "string" ? value.trim() : "");

  // Clean up payload: trim strings and convert blank optional values to undefined.
  const trimmedEmail = asTrimmedString(payload.email);
  const trimmedFullName = asTrimmedString(payload.fullName);
  const trimmedRole = asTrimmedString(payload.role);
  const trimmedPassword = asTrimmedString(payload.password);
  const trimmedPhone = asTrimmedString(payload.phone);

  const cleaned = {
    email: trimmedEmail || undefined,
    fullName: trimmedFullName,
    role: trimmedRole,
    password: trimmedPassword || undefined,
    phone: trimmedPhone,
    assignedLineId: asTrimmedString(payload.assignedLineId) || undefined,
    assignmentStartDate: asTrimmedString(payload.assignmentStartDate) || undefined,
    assignmentEndDate: asTrimmedString(payload.assignmentEndDate) || undefined,
  };

  const parsed = createUserSchema.safeParse(cleaned);
  if (!parsed.success) {
    const details = parsed.error.issues.map(i => i.message).join('، ');
    return { ok: false, error: new AppError(`بيانات غير صحيحة: ${details}`, "VALIDATION") };
  }

  const normalizedPayload = {
    ...parsed.data,
    assignedLineId: parsed.data.assignedLineId ?? undefined,
    assignmentStartDate: parsed.data.assignmentStartDate ?? undefined,
    assignmentEndDate: parsed.data.assignmentEndDate ?? undefined,
  };

  try {
    await repo.createUser(normalizedPayload);
    return { ok: true, data: undefined };
  } catch (error: any) {
    console.error("Create User Error:", error);
    const msg = error?.message || "تعذر إنشاء المستخدم";
    return { ok: false, error: new AppError(msg, "INTERNAL") };
  }
};
