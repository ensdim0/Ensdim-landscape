import { Contract } from "@domain/entities/Contract";
import { Visit } from "@domain/entities/Visit";
import { SupervisorNote, CreateSupervisorNoteDTO, UpdateSupervisorNoteDTO } from "@domain/entities/SupervisorNote";

export interface SupervisorRepository {
  listAssignedContracts(): Promise<Contract[]>;
  createVisit(payload: {
    contractId: string;
    visitDate?: string;
    notes?: string | null;
  }): Promise<Visit>;
  uploadVisitPhoto(visitId: string, file: File): Promise<string>;
  submitReport(payload: { visitId: string; summary: string }): Promise<void>;
  
  // Supervisor Notes
  listSupervisorNotes(visitId: string): Promise<SupervisorNote[]>;
  createSupervisorNote(payload: CreateSupervisorNoteDTO): Promise<SupervisorNote>;
  updateSupervisorNote(payload: UpdateSupervisorNoteDTO): Promise<SupervisorNote>;
  deleteSupervisorNote(noteId: string): Promise<void>;
}
