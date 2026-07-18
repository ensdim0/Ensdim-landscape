import type { GatewayStatus, PaymentMethod } from "./ContractPayment";

export type StandaloneTaskPayment = {
  id: string;
  taskId: string;
  amount: number;
  paymentMethod: PaymentMethod;
  notes?: string | null;
  paymentDate: string;
  createdAt: string;
  // Scheduled payment fields
  dueDate?: string | null;
  // UPayments gateway fields
  paymentGatewayUrl?: string | null;
  paymentGatewayOrderId?: string | null;
  gatewayStatus?: GatewayStatus | null;
  gatewayFeeAmount?: number | null;
  receiptUrl?: string | null;
};
