import { Contract } from "@domain/entities/Contract";
import { ContractTask } from "@domain/entities/ContractTask";
import { Invoice, InvoiceStatus } from "@domain/entities/Invoice";
import { User } from "@domain/entities/User";
import { ContractType } from "@domain/entities/ContractType";
import { ContractTerm } from "@domain/entities/ContractTerm";
import { Visit } from "@domain/entities/Visit";
import { ContractPayment, PaymentMethod } from "@domain/entities/ContractPayment";
import { ContractStatus } from "@domain/entities/Contract";
import { ContractPalmInfo } from "@domain/entities/Contract";
import { StandaloneTask } from "@domain/entities/StandaloneTask";
import { StandaloneTaskPayment } from "@domain/entities/StandaloneTaskPayment";
import { CompanyExpense, CompanyExpenseCategory } from "@domain/entities/CompanyExpense";
import { ExpenseSection } from "@domain/entities/ExpenseSection";
import { ExpenseLineItem } from "@domain/entities/ExpenseLineItem";

export interface AdminRepository {
  listUsers(): Promise<User[]>;
  createUser(payload: { email?: string; fullName: string; role: string; password?: string; phone: string; assignedLineId?: string; assignmentStartDate?: string; assignmentEndDate?: string }): Promise<User>;
  updateUser(payload: { id: string; email?: string; fullName?: string; role?: string; password?: string; phone?: string; assignedLineId?: string | null; assignmentStartDate?: string | null; assignmentEndDate?: string | null; joinDate?: string | null }): Promise<User>;
  deleteUser(id: string): Promise<void>;
  listClientUsers(): Promise<User[]>;
  createContract(payload: {
    userId: string;
    zoneId: string;
    code: string;
    contractTypeId?: string;
    durationMonths?: number;
    addressDetails?: string;
    notes?: string;
    palmInfo?: ContractPalmInfo | null;
    contractUserName: string;
    contractUserPhone: string;
    contractUserPasswordHash: string;
    startDate: string;
    endDate: string;
    totalValue: number;
    status?: ContractStatus;
    terms?: ContractTerm[];
  }): Promise<Contract>;
  updateContract(payload: {
    id: string;
    userId: string;
    zoneId: string;
    code: string;
    contractTypeId?: string;
    durationMonths?: number;
    addressDetails?: string;
    notes?: string;
    palmInfo?: ContractPalmInfo | null;
    contractUserName: string;
    contractUserPhone: string;
    startDate: string;
    endDate: string;
    totalValue: number;
    status: string;
    terms?: ContractTerm[];
  }): Promise<Contract>;
  deleteContract(id: string): Promise<void>;
  listContracts(): Promise<Contract[]>;
  listContractTypes(): Promise<ContractType[]>;
  createContractType(payload: { name: string; description?: string; terms?: ContractTerm[] }): Promise<ContractType>;
  updateContractType(payload: { id: string; name: string; description?: string; terms?: ContractTerm[] }): Promise<ContractType>;
  deleteContractType(id: string): Promise<void>;
  listInvoices(contractId?: string): Promise<Invoice[]>;
  updateInvoiceStatus(id: string, status: InvoiceStatus): Promise<Invoice>;

  listSupervisors(): Promise<User[]>;
  assignLineToSupervisor(payload: { supervisorId: string; lineId: string; startDate?: string | null; endDate?: string | null }): Promise<void>;
  removeLineAssignment(supervisorId: string): Promise<void>;
  getContractsByLineId(lineId: string): Promise<Contract[]>;
  uploadContractImage(contractId: string, file: Blob, fileName: string): Promise<string>;
  deleteContractImage(contractId: string, imageUrl: string): Promise<void>;

  listVisits(contractId: string): Promise<Visit[]>;
  listAllVisits(contractIds: string[]): Promise<Visit[]>;
  createVisit(payload: { contractId: string; visitDate?: string; notes?: string; title?: string }): Promise<Visit>;
  updateVisit(payload: { id: string; title?: string | null; visitDate?: string; notes?: string | null; status?: string }): Promise<Visit>;
  updateVisitStatus(visitId: string, status: string): Promise<Visit>;
  deleteVisit(visitId: string): Promise<void>;

  listVisitTasks(visitId: string): Promise<ContractTask[]>;
  listAllVisitTasks(visitIds: string[]): Promise<ContractTask[]>;
  createContractTask(payload: { visitId: string; contractId: string; title: string; month: number }): Promise<ContractTask>;
  updateContractTaskStatus(taskId: string, status: string): Promise<ContractTask>;
  deleteContractTask(taskId: string): Promise<void>;

  listTaskExecutions(taskIds: string[]): Promise<any[]>;
  listExecutionPhotos(executionIds: string[]): Promise<any[]>;
  listVisitPhotos(visitId: string): Promise<any[]>;

  listContractComments(contractId: string, visitId?: string): Promise<any[]>;

  listContractPayments(contractId: string): Promise<ContractPayment[]>;
  listAllContractPayments(): Promise<ContractPayment[]>;
  /** Payments (of any gateway status, including still-pending ones) whose due date has passed and that aren't paid yet. */
  listOverdueContractPayments(): Promise<ContractPayment[]>;
  listScheduledContractPayments(contractId: string): Promise<ContractPayment[]>;
  createContractPayment(payload: { contractId: string; amount: number; paymentMethod: PaymentMethod; notes?: string; paymentDate: string }): Promise<ContractPayment>;
  createScheduledContractPayment(payload: { contractId: string; amount: number; dueDate: string; paymentMethod: PaymentMethod; notes?: string | null }): Promise<ContractPayment>;
  updateContractPayment(payload: { id: string; amount: number; paymentMethod: PaymentMethod; notes?: string | null; paymentDate: string }): Promise<ContractPayment>;
  /** Updates just the planned payment method of a scheduled/unpaid payment. */
  updateScheduledPaymentMethod(id: string, paymentMethod: PaymentMethod): Promise<ContractPayment>;
  /** Converts a scheduled/unpaid payment into a manually-paid one (clears due_date and any gateway state). */
  markContractPaymentPaid(payload: { id: string; paymentMethod: PaymentMethod; paymentDate: string; notes?: string | null }): Promise<ContractPayment>;
  uploadPaymentImage(paymentId: string, file: Blob, fileName: string): Promise<string>;
  deleteContractPayment(id: string): Promise<void>;

  // Standalone task payments
  listAllStandaloneTaskPayments(): Promise<StandaloneTaskPayment[]>;
  /** Payments (of any gateway status, including still-pending ones) whose due date has passed and that aren't paid yet. */
  listOverdueStandaloneTaskPayments(): Promise<StandaloneTaskPayment[]>;
  createStandaloneTaskPayment(payload: { taskId: string; amount: number; paymentMethod: PaymentMethod; notes?: string | null; paymentDate: string }): Promise<StandaloneTaskPayment>;
  updateStandaloneTaskPayment(payload: { id: string; amount: number; paymentMethod: PaymentMethod; notes?: string | null; paymentDate: string }): Promise<StandaloneTaskPayment>;
  deleteStandaloneTaskPayment(id: string): Promise<void>;

  // Expense sections
  listExpenseSections(): Promise<ExpenseSection[]>;
  createExpenseSection(payload: { name: string; kind?: 'expense' | 'cost' }): Promise<ExpenseSection>;
  updateExpenseSection(payload: { id: string; name: string; sortOrder?: number }): Promise<ExpenseSection>;
  deleteExpenseSection(id: string): Promise<void>;

  // Expense line items
  listExpenseLineItems(): Promise<ExpenseLineItem[]>;
  createExpenseLineItem(payload: { sectionId: string; name: string }): Promise<ExpenseLineItem>;
  updateExpenseLineItem(payload: { id: string; name: string; sortOrder?: number }): Promise<ExpenseLineItem>;
  deleteExpenseLineItem(id: string): Promise<void>;

  // Company expenses
  listCompanyExpenses(): Promise<CompanyExpense[]>;
  createCompanyExpense(payload: { sectionId: string; category?: CompanyExpenseCategory | null; lineItemId?: string | null; name: string; description?: string | null; amount: number; expenseDate: string; note?: string | null; workerId?: string | null; paymentMethod?: PaymentMethod | null }): Promise<CompanyExpense>;
  updateCompanyExpense(payload: { id: string; lineItemId?: string | null; name: string; description?: string | null; amount: number; expenseDate: string; note?: string | null; workerId?: string | null; paymentMethod?: PaymentMethod | null }): Promise<CompanyExpense>;
  deleteCompanyExpense(id: string): Promise<void>;
  bulkPaySalaries(month: string, paymentMethod: PaymentMethod): Promise<CompanyExpense[]>;

  // System settings
  getUpaymentsFeeAmount(): Promise<number>;
  updateUpaymentsFeeAmount(amount: number): Promise<void>;
  getUpaymentsSandboxMode(): Promise<boolean>;
  updateUpaymentsSandboxMode(sandbox: boolean): Promise<void>;
  hasTenantPaymentCredentials(): Promise<boolean>;
  setTenantPaymentCredentials(input: {
    apiToken: string;
    nwlToken: string;
    gatewaySrc: string;
    webhookSecret: string;
    returnUrl: string;
    cancelUrl: string;
  }): Promise<void>;

  // Standalone tasks (not tied to contracts)
  listStandaloneTasks(): Promise<StandaloneTask[]>;
  listStandaloneTasksByContract(contractId: string): Promise<StandaloneTask[]>;
  createStandaloneTask(payload: { title: string; description?: string | null; address?: string | null; clientId?: string | null; clientName?: string | null; clientPhone?: string | null; taskDate: string; notes?: string | null; supervisorId?: string | null; contractId?: string | null; lineId?: string | null; zoneId?: string | null; cost?: number | null; status?: string; paymentStatus?: string; paymentMethod?: string | null }): Promise<StandaloneTask>;
  updateStandaloneTask(id: string, payload: { title?: string; description?: string | null; address?: string | null; clientId?: string | null; clientName?: string | null; clientPhone?: string | null; supervisorId?: string | null; taskDate?: string; notes?: string | null; supervisorReport?: string | null; status?: string; contractId?: string | null; lineId?: string | null; zoneId?: string | null; cost?: number | null; paymentStatus?: string; paymentMethod?: string | null }): Promise<StandaloneTask>;
  updateStandaloneTaskStatus(id: string, status: string): Promise<StandaloneTask>;
  deleteStandaloneTask(id: string): Promise<void>;
}
