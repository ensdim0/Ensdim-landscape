import { User } from "@domain/entities/User";

export type AuthSession = {
  accessToken: string;
  user: User;
};

export interface AuthRepository {
  login(email: string, password: string): Promise<AuthSession>;
  logout(): Promise<void>;
  getCurrentUser(): Promise<User | null>;
}
