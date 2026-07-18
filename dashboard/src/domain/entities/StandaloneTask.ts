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
};
