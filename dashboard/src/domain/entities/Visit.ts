export type VisitStatus = "planned" | "in_progress" | "completed" | "cancelled";

export type Visit = {
  id: string;
  contractId: string;
  title?: string | null;
  visitDate: string;
  notes?: string | null;
  status: VisitStatus;
  summary?: string | null;
  gpsLat?: number | null;
  gpsLng?: number | null;
  completedAt?: string | null;
  createdAt: string;
};
