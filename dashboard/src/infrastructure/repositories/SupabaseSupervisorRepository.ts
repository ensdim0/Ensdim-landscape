import { SupervisorRepository } from "@domain/repositories/SupervisorRepository";
import { supabase } from "@infrastructure/supabase/client";
import { Contract } from "@domain/entities/Contract";
import { Visit } from "@domain/entities/Visit";
import { SupervisorNote, CreateSupervisorNoteDTO, UpdateSupervisorNoteDTO } from "@domain/entities/SupervisorNote";

export class SupabaseSupervisorRepository implements SupervisorRepository {
  async listAssignedContracts(): Promise<Contract[]> {
    const { data, error } = await supabase.from("contracts_view").select("*");
    if (error) throw error;
    return data as Contract[];
  }

  async createVisit(payload: {
    contractId: string;
    visitDate: string;
    notes?: string | null;
  }): Promise<Visit> {
    const { data, error } = await supabase
      .from("visits")
      .insert({
        contract_id: payload.contractId,
        visit_date: payload.visitDate,
        notes: payload.notes ?? null,
        status: "planned"
      })
      .select()
      .single();
    if (error) throw error;
    return {
      id: data.id,
      contractId: data.contract_id,
      visitDate: data.visit_date,
      notes: data.notes,
      status: data.status,
      createdAt: data.created_at
    };
  }

  async uploadVisitPhoto(visitId: string, file: File): Promise<string> {
    const path = `visits/${visitId}/${file.name}`;
    const { error } = await supabase.storage.from("visit-photos").upload(path, file, {
      upsert: true
    });
    if (error) throw error;
    return path;
  }

  async submitReport(payload: { visitId: string; summary: string }): Promise<void> {
    const { error } = await supabase.from("reports").insert(payload);
    if (error) throw error;
  }

  // Supervisor Notes
  async listSupervisorNotes(visitId: string): Promise<SupervisorNote[]> {
    const { data, error } = await supabase
      .from("supervisor_notes")
      .select("*")
      .eq("visit_id", visitId)
      .order("created_at", { ascending: false });
    if (error) throw error;
    return (data || []).map(note => ({
      id: note.id,
      visitId: note.visit_id,
      contractId: note.contract_id,
      content: note.content,
      visibility: note.visibility,
      createdBy: note.created_by,
      createdAt: note.created_at,
      updatedAt: note.updated_at
    }));
  }

  async createSupervisorNote(payload: CreateSupervisorNoteDTO): Promise<SupervisorNote> {
    const { data: { user } } = await supabase.auth.getUser();
    const { data, error } = await supabase
      .from("supervisor_notes")
      .insert({
        visit_id: payload.visitId,
        contract_id: payload.contractId,
        content: payload.content,
        visibility: payload.visibility,
        created_by: user?.id ?? null
      })
      .select()
      .single();
    if (error) throw error;
    return {
      id: data.id,
      visitId: data.visit_id,
      contractId: data.contract_id,
      content: data.content,
      visibility: data.visibility,
      createdBy: data.created_by,
      createdAt: data.created_at,
      updatedAt: data.updated_at
    };
  }

  async updateSupervisorNote(payload: UpdateSupervisorNoteDTO): Promise<SupervisorNote> {
    const { data, error } = await supabase
      .from("supervisor_notes")
      .update({
        content: payload.content,
        visibility: payload.visibility,
        updated_at: new Date().toISOString()
      })
      .eq("id", payload.noteId)
      .select()
      .single();
    if (error) throw error;
    return {
      id: data.id,
      visitId: data.visit_id,
      contractId: data.contract_id,
      content: data.content,
      visibility: data.visibility,
      createdBy: data.created_by,
      createdAt: data.created_at,
      updatedAt: data.updated_at
    };
  }

  async deleteSupervisorNote(noteId: string): Promise<void> {
    const { error } = await supabase
      .from("supervisor_notes")
      .delete()
      .eq("id", noteId);
    if (error) throw error;
  }
}
