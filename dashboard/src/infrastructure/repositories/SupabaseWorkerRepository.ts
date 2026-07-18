import { WorkerRepository } from "@domain/repositories/WorkerRepository";
import { supabase } from "@infrastructure/supabase/client";
import { Worker } from "@domain/entities/Worker";

export class SupabaseWorkerRepository implements WorkerRepository {
  private mapWorker(row: any): Worker {
    return {
      id: row.id,
      name: row.name,
      phone: row.phone,
      visaStart: row.visa_start,
      visaEnd: row.visa_end,
      salary: row.salary,
      notes: row.notes,
      createdAt: row.created_at,
    };
  }

  async listWorkers(): Promise<Worker[]> {
    const { data, error } = await supabase
      .from("workers")
      .select("*")
      .order("created_at", { ascending: false });
    if (error) throw error;
    return (data ?? []).map((row) => this.mapWorker(row));
  }

  async createWorker(payload: {
    name: string;
    phone: string;
    visaStart: string;
    visaEnd: string;
    salary: number;
    notes?: string | null;
  }): Promise<Worker> {
    const { data, error } = await supabase
      .from("workers")
      .insert({
        name: payload.name,
        phone: payload.phone,
        visa_start: payload.visaStart,
        visa_end: payload.visaEnd,
        salary: payload.salary,
        notes: payload.notes || null,
      })
      .select()
      .single();
    if (error) throw error;
    return this.mapWorker(data);
  }

  async updateWorker(payload: {
    id: string;
    name: string;
    phone: string;
    visaStart: string;
    visaEnd: string;
    salary: number;
    notes?: string | null;
  }): Promise<Worker> {
    const { data, error } = await supabase
      .from("workers")
      .update({
        name: payload.name,
        phone: payload.phone,
        visa_start: payload.visaStart,
        visa_end: payload.visaEnd,
        salary: payload.salary,
        notes: payload.notes || null,
      })
      .eq("id", payload.id)
      .select()
      .single();
    if (error) throw error;
    return this.mapWorker(data);
  }

  async deleteWorker(id: string): Promise<void> {
    const { error } = await supabase.from("workers").delete().eq("id", id);
    if (error) throw error;
  }
}
