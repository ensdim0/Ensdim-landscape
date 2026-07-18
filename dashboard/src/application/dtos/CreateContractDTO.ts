import { ContractTerm } from "@domain/entities/ContractTerm";
import { ContractPalmInfo, ContractStatus } from "@domain/entities/Contract";

export type CreateContractDTO = {
  userId: string;
  zoneId: string;
  code: string;
  contractTypeId?: string;
  durationMonths?: number;
  addressDetails?: string;
  notes?: string;
  palmInfo?: ContractPalmInfo | null;
  blockNumber?: string;
  street?: string;
  avenue?: string;
  house?: string;
  kuwaitFinderUrl?: string;
  contractUserName: string;
  contractUserPhone: string;
  contractUserPasswordHash: string;
  startDate: string;
  endDate: string;
  totalValue: number;
  status?: ContractStatus;
  terms?: ContractTerm[];
  firstVisitDate?: string; // Date for first visit (if different from startDate)
};
