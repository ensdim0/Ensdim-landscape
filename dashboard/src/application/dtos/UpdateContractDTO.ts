import { ContractTerm } from "@domain/entities/ContractTerm";
import { ContractPalmInfo } from "@domain/entities/Contract";

export type UpdateContractDTO = {
  id: string;
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
  startDate: string;
  firstVisitDate?: string;
  endDate: string;
  totalValue: number;
  status: string;
  terms?: ContractTerm[];
};