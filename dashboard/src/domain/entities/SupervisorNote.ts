export type SupervisorNoteVisibility = 'supervisors_only' | 'all';

export type SupervisorNote = {
  id: string;
  visitId: string;
  contractId: string;
  content: string;
  visibility: SupervisorNoteVisibility;
  createdBy?: string | null;
  createdAt: string;
  updatedAt: string;
};

export type CreateSupervisorNoteDTO = {
  visitId: string;
  contractId: string;
  content: string;
  visibility: SupervisorNoteVisibility;
};

export type UpdateSupervisorNoteDTO = {
  noteId: string;
  content: string;
  visibility: SupervisorNoteVisibility;
};
