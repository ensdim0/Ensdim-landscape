import { RoleName } from "@shared/constants/roles";

export type User = {
  id: string;
  email: string;
  fullName: string;
  phone?: string;
  role: RoleName;
  createdAt: string;
  assignedLineId?: string;
  assignmentStartDate?: string;
  assignmentEndDate?: string;
  tenantId?: string;
  tenantName?: string;
  tenantStatus?: "active" | "suspended" | "trial" | "pending";
};
