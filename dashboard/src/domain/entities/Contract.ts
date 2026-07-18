import { ContractTerm } from "./ContractTerm";

export type ContractStatus = "active" | "pending" | "expired" | "cancelled" | "terminated";

export type ContractPalmStats = {
  largeProductive: number;
  largeNonProductive: number;
  smallProductive: number;
  smallNonProductive: number;
};

export type ContractPalmInfo = {
  isPalm: boolean;
  species?: "baladi" | "washingtonia";
  baladi?: ContractPalmStats;
  washingtonia?: ContractPalmStats;
};

export type Contract = {
  id: string;
  code: string;
  clientId: string;
  blockId: string | null;
  zoneId?: string | null;
  lineId?: string | null;
  contractTypeId?: string | null;
  durationMonths?: number;
  addressDetails?: string | null;
  notes?: string | null;
  palmInfo?: ContractPalmInfo | null;
  blockNumber?: string | null;
  street?: string | null;
  avenue?: string | null;
  house?: string | null;
  kuwaitFinderUrl?: string | null;
  startDate: string;
  firstVisitDate?: string;
  endDate: string;
  status: ContractStatus;
  totalValue: number;
  terms?: ContractTerm[];
  contractUserName?: string;
  contractUserPhone?: string;
  contractUserPasswordHash?: string;
  contractImageUrl?: string | null;
  createdAt: string;
};
