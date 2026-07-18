export type TaskStatus = "pending" | "completed" | "verified" | "rejected";

export type ContractTask = {
  id: string;
  contractId: string;
  visitId: string;
  title: string;
  month: number;
  status: TaskStatus;
  createdAt: string;
};
