import { ContractTerm } from "./ContractTerm";

export type ContractType = {
  id: string;
  name: string;
  description?: string | null;
  terms?: ContractTerm[];
  createdAt: string;
  contractCount?: number;
};
