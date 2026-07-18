import { AdminRepository } from "@domain/repositories/AdminRepository";
import { Result } from "@core/types/Result";
import { AppError } from "@core/errors/AppError";
import { User } from "@domain/entities/User";

export const getUsers = async (repo: AdminRepository): Promise<Result<User[]>> => {
  try {
    const data = await repo.listUsers();
    return { ok: true, data };
  } catch (error) {
    return { ok: false, error: new AppError("تعذر تحميل المستخدمين", "INTERNAL") };
  }
};
