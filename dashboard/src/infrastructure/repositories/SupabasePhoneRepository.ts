import { PhoneRepository } from "@domain/repositories/PhoneRepository";
import { supabase } from "@infrastructure/supabase/client";
import { CompanyPhone } from "@domain/entities/CompanyPhone";

export class SupabasePhoneRepository implements PhoneRepository {
  private mapPhone(row: any): CompanyPhone {
    const lines = Array.isArray(row.geographic_lines) ? row.geographic_lines : [];
    return {
      id: row.id,
      phoneNumber: row.phone_number,
      phoneName: row.phone_name,
      status: row.status,
      notes: row.notes,
      createdAt: row.created_at,
      lineCount: lines.length,
      lineNames: lines.map((l: any) => l.name).filter(Boolean),
    };
  }

  async listPhones(): Promise<CompanyPhone[]> {
    const { data, error } = await supabase
      .from("company_phones")
      .select("*, geographic_lines(name)")
      .order("created_at", { ascending: false });
    if (error) throw error;
    return (data ?? []).map((row) => this.mapPhone(row));
  }

  async createPhone(payload: {
    phoneNumber: string;
    phoneName?: string | null;
    notes?: string | null;
  }): Promise<CompanyPhone> {
    const { data, error } = await supabase
      .from("company_phones")
      .insert({
        phone_number: payload.phoneNumber,
        phone_name: payload.phoneName || null,
        notes: payload.notes || null,
        status: "active",
      })
      .select()
      .single();
    if (error) throw error;
    return this.mapPhone(data);
  }

  async updatePhone(payload: {
    id: string;
    phoneNumber: string;
    phoneName?: string | null;
    notes?: string | null;
    isActive: boolean;
  }): Promise<CompanyPhone> {
    const { data, error } = await supabase
      .from("company_phones")
      .update({
        phone_number: payload.phoneNumber,
        phone_name: payload.phoneName || null,
        notes: payload.notes || null,
        status: payload.isActive ? "active" : "inactive",
      })
      .eq("id", payload.id)
      .select()
      .single();
    if (error) throw error;
    return this.mapPhone(data);
  }

  async deletePhone(id: string): Promise<void> {
    const { error } = await supabase.from("company_phones").delete().eq("id", id);
    if (error) throw error;
  }
}
