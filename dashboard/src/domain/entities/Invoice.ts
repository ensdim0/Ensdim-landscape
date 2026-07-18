export type InvoiceStatus = "issued" | "partially_paid" | "paid" | "overdue";

export type Invoice = {
  id: string;
  contractId: string;
  amount: number;
  status: InvoiceStatus;
  dueDate: string;
  createdAt: string;
};
