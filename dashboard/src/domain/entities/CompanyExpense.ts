import type { PaymentMethod } from "./ContractPayment";

export type CompanyExpenseCategory = "salary" | "rent" | "marketing" | "misc";

export type CompanyExpense = {
  id: string;
  category?: CompanyExpenseCategory | null;
  sectionId?: string | null;
  lineItemId?: string | null;
  name: string;
  description?: string | null;
  amount: number;
  expenseDate: string;
  note?: string | null;
  workerId?: string | null;
  paymentMethod?: PaymentMethod | null;
  createdAt: string;
};
