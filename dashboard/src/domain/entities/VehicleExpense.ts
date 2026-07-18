import type { PaymentMethod } from "./ContractPayment";

export type VehicleExpense = {
  id: string;
  vehicleId: string;
  lineItemId?: string | null;
  description: string;
  amount: number;
  expenseDate: string;
  paymentMethod?: PaymentMethod | null;
  createdAt: string;
};
