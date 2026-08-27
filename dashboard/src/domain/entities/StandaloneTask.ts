export type StandaloneTaskStatus = 'pending' | 'in_progress' | 'completed' | 'cancelled';
export type StandaloneTaskPaymentStatus = 'unpaid' | 'paid';

export type StandaloneTask = {
  id: string;
  title: string;
  description?: string | null;
  address?: string | null;
  clientId?: string | null;
  clientName?: string | null;
  clientPhone?: string | null;
  supervisorId?: string | null;
  taskDate: string;
  contractId?: string | null;
  lineId?: string | null;
  zoneId?: string | null;
  cost?: number | null;
  notes?: string | null;
  supervisorReport?: string | null;
  status: StandaloneTaskStatus;
  paymentStatus: StandaloneTaskPaymentStatus;
  paymentMethod?: string | null;
  createdAt: string;
  updatedAt?: string | null;
  deletedAt?: string | null;
  // Visit lifecycle (start/end, GPS, who) and payment confirmation — see
  // 2026-08-26_standalone_task_teams.sql.
  visitStartedAt?: string | null;
  visitStartedLat?: number | null;
  visitStartedLng?: number | null;
  startedBy?: string | null;
  visitEndedAt?: string | null;
  visitEndedLat?: number | null;
  visitEndedLng?: number | null;
  endedBy?: string | null;
  paymentConfirmedAt?: string | null;
  paymentConfirmedBy?: string | null;
};

// One row per person assigned to a standalone task's team — either a
// supervisor (has a mobile app account) or a worker (cost/HR record only,
// no login; shown for visibility). Exactly one of the two ids is set.
export type StandaloneTaskAssignee = {
  id: string;
  taskId: string;
  supervisorId?: string | null;
  workerId?: string | null;
  createdAt: string;
};

// A checklist entry created by the admin at task creation time. A visit
// cannot be ended until every item for its task is 'completed'.
export type StandaloneTaskItem = {
  id: string;
  taskId: string;
  title: string;
  status: 'pending' | 'completed';
  sortOrder: number;
  completedBy?: string | null;
  completedAt?: string | null;
  createdAt: string;
};

export type StandaloneTaskPhotoPhase = 'start' | 'end';

export type StandaloneTaskPhoto = {
  id: string;
  taskId: string;
  phase: StandaloneTaskPhotoPhase;
  photoPath: string;
  photoUrl: string;
  uploadedBy?: string | null;
  createdAt: string;
};
