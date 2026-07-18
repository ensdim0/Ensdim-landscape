export type VehicleStatus = "active" | "inactive";

export type Vehicle = {
  id: string;
  plateNumber: string;
  licenseNumber: string;
  licenseExpiry: string;
  status: VehicleStatus;
  notes?: string | null;
  createdAt: string;
  expenseCount?: number;
  totalExpenses?: number;
  currentMonthExpenses?: number;
};
