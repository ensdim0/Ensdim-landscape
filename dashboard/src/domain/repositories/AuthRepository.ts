import { User } from "@domain/entities/User";

export type AuthSession = {
  accessToken: string;
  user: User;
};

export type RegisterCompanyPayload = {
  companyName: string;
  fullName: string;
  phone: string;
  email: string;
  password: string;
};

export interface AuthRepository {
  login(email: string, password: string): Promise<AuthSession>;
  logout(): Promise<void>;
  getCurrentUser(): Promise<User | null>;
  registerCompany(payload: RegisterCompanyPayload): Promise<void>;
}
