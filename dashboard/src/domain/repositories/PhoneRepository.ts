import { CompanyPhone } from "@domain/entities/CompanyPhone";

export interface PhoneRepository {
  listPhones(): Promise<CompanyPhone[]>;
  createPhone(payload: { phoneNumber: string; phoneName?: string | null; notes?: string | null }): Promise<CompanyPhone>;
  updatePhone(payload: { id: string; phoneNumber: string; phoneName?: string | null; notes?: string | null; isActive: boolean }): Promise<CompanyPhone>;
  deletePhone(id: string): Promise<void>;
}
