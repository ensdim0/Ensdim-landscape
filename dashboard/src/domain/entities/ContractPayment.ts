export type PaymentMethod = "cash" | "transfer" | "cheque" | "card" | "gateway";

export type GatewayStatus = "pending" | "paid" | "failed" | "cancelled";

export type ContractPayment = {
  id: string;
  contractId: string;
  amount: number;
  paymentMethod: PaymentMethod;
  transferImageUrl?: string | null;
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
