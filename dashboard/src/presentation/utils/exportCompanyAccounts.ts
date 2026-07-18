import type ExcelJS from "exceljs";
import { Contract } from "@domain/entities/Contract";
import { ContractPayment, GatewayStatus, PaymentMethod } from "@domain/entities/ContractPayment";
import { StandaloneTask } from "@domain/entities/StandaloneTask";
import { StandaloneTaskPayment } from "@domain/entities/StandaloneTaskPayment";
import { CompanyExpense } from "@domain/entities/CompanyExpense";
import { ExpenseSection } from "@domain/entities/ExpenseSection";
import { ExpenseLineItem } from "@domain/entities/ExpenseLineItem";
import { Worker } from "@domain/entities/Worker";
import { User } from "@domain/entities/User";
import { Vehicle } from "@domain/entities/Vehicle";
import { VehicleExpense } from "@domain/entities/VehicleExpense";

const BRAND_GREEN = "FF3A6E2A";
const HEADER_FONT = { name: "Calibri", size: 11, bold: true, color: { argb: "FFFFFFFF" } } as const;
const SUBHEADER_FONT = { name: "Calibri", size: 12, bold: true, color: { argb: "FF1A2A10" } } as const;
const MONEY_FMT = '#,##0.00 "د.ك"';

const PAYMENT_METHOD_LABELS: Record<string, string> = {
  cash: "نقدي",
  transfer: "رابط",
  cheque: "شيك",
  card: "ومض",
  gateway: "UPayments",
};
const paymentMethodLabel = (m?: string | null) => (m ? PAYMENT_METHOD_LABELS[m] ?? m : "—");

const GATEWAY_STATUS_LABELS: Record<string, string> = {
  pending: "قيد الانتظار",
  paid: "مدفوعة",
  failed: "فشلت",
  cancelled: "ملغاة",
};
const gatewayStatusLabel = (s?: GatewayStatus | null) => (s ? GATEWAY_STATUS_LABELS[s] ?? s : "—");

const formatDate = (d?: string | null) => {
  if (!d) return "—";
  return new Date(d).toLocaleDateString("ar-EG", { year: "numeric", month: "short", day: "numeric" });
};

export interface CompanyAccountsExportData {
  rangeLabel: string;
  filterFrom: string | null;
  filterTo: string | null;

  contractPayments: ContractPayment[];
  taskPayments: StandaloneTaskPayment[];
  expenses: CompanyExpense[];
  vehicleExpenses: VehicleExpense[];

  contracts: Contract[];
  clientUsers: User[];
  standaloneTasks: StandaloneTask[];
  workers: Worker[];
  vehicles: Vehicle[];
  sections: ExpenseSection[];
  lineItems: ExpenseLineItem[];

  totals: {
    contractRevenue: number;
    taskRevenue: number;
    totalRevenue: number;
    gatewayFees: number;
    netRevenue: number;
    totalExpenses: number;
    totalCosts: number;
    net: number;
    gatewayRevenue: number;
    gatewayNet: number;
    accountsNetTotal: number;
  };
  sectionTotals: Record<string, number>;
  costSectionTotals: Record<string, number>;
  paymentMethodTotals: { method: string; label: string; amount: number; count: number }[];
  accountBalances: { method: string; label: string; income: number; outgo: number; balance: number }[];

  fileName: string;
}

type ColumnDef = { header: string; key: string; width: number };

function styleHeaderRow(ws: import("exceljs").Worksheet, rowNumber = 1) {
  const row = ws.getRow(rowNumber);
  row.eachCell((cell) => {
    cell.font = { ...HEADER_FONT };
    cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: BRAND_GREEN } };
    cell.alignment = { vertical: "middle", horizontal: "center", wrapText: true };
  });
  row.height = 22;
}

function addDataSheet(
  workbook: ExcelJS.Workbook,
  name: string,
  columns: ColumnDef[],
  rows: Record<string, any>[],
  totalRow?: Record<string, any>
) {
  const ws = workbook.addWorksheet(name, {
    views: [{ rightToLeft: true, state: "frozen", ySplit: 1 }],
  });
  ws.columns = columns;
  styleHeaderRow(ws);

  rows.forEach((r) => ws.addRow(r));

  if (totalRow) {
    const row = ws.addRow(totalRow);
    row.eachCell((cell) => {
      cell.font = { bold: true };
      cell.border = { top: { style: "thin", color: { argb: "FF9CA89A" } } };
    });
  }

  columns.forEach((col, i) => {
    if (/المبلغ|العمولة|الإيرادات|المصروفات|الرصيد/.test(col.header)) {
      ws.getColumn(i + 1).numFmt = MONEY_FMT;
    }
  });

  return ws;
}

function contractLabel(contractId: string, contracts: Contract[], clientUsers: User[]) {
  const c = contracts.find((x) => x.id === contractId);
  if (!c) return { code: "—", client: "—" };
  const client = clientUsers.find((u) => u.id === c.clientId)?.fullName ?? c.contractUserName ?? "—";
  return { code: c.code, client };
}

export async function exportCompanyAccountsToExcel(data: CompanyAccountsExportData): Promise<void> {
  const {
    rangeLabel, contractPayments, taskPayments, expenses, vehicleExpenses,
    contracts, clientUsers, standaloneTasks, workers, vehicles, sections, lineItems,
    totals, sectionTotals, costSectionTotals, paymentMethodTotals, accountBalances,
    fileName,
  } = data;

  const { default: ExcelJSModule } = await import("exceljs");
  const workbook = new ExcelJSModule.Workbook();
  workbook.creator = "نظام إدارة الشركة";
  workbook.created = new Date();

  /* ── (a) الملخص العام ── */
  const summarySections = sections.filter((s) => s.kind === "expense");
  const costSections = sections.filter((s) => s.kind === "cost");
  const sectionTypeLabel = (t: string) => (t === "salary" ? "رواتب" : t === "vehicles" ? "سيارات" : "عام");

  const summaryWs = workbook.addWorksheet("الملخص العام", { views: [{ rightToLeft: true }] });
  summaryWs.columns = [
    { header: "", key: "a", width: 30 },
    { header: "", key: "b", width: 20 },
    { header: "", key: "c", width: 20 },
    { header: "", key: "d", width: 16 },
  ];

  const addTitle = (text: string) => {
    const row = summaryWs.addRow([text]);
    summaryWs.mergeCells(row.number, 1, row.number, 4);
    row.getCell(1).font = SUBHEADER_FONT;
    row.getCell(1).alignment = { horizontal: "right" };
  };
  const addTableHeader = (...cells: string[]) => {
    const row = summaryWs.addRow(cells);
    row.eachCell((cell) => {
      cell.font = { bold: true, color: { argb: "FFFFFFFF" } };
      cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: BRAND_GREEN } };
      cell.alignment = { horizontal: "center" };
    });
  };
  const addMoneyRow = (label: string, value: number) => {
    const row = summaryWs.addRow([label, value]);
    row.getCell(2).numFmt = MONEY_FMT;
  };
  const blankRow = () => summaryWs.addRow([]);

  addTitle(`تقرير حسابات الشركة — ${rangeLabel}`);
  blankRow();

  addTitle("الإجماليات الرئيسية");
  addMoneyRow("إجمالي الإيرادات", totals.totalRevenue);
  addMoneyRow("عمولة بوابة الدفع", totals.gatewayFees);
  addMoneyRow("صافي الإيرادات", totals.netRevenue);
  addMoneyRow("إجمالي المصروفات", totals.totalExpenses);
  addMoneyRow("إجمالي التكاليف", totals.totalCosts);
  addMoneyRow("الصافي العام", totals.net);
  blankRow();

  addTitle("الإيرادات حسب المصدر");
  addMoneyRow("إيرادات العقود", totals.contractRevenue);
  addMoneyRow("إيرادات المهام المستقلة", totals.taskRevenue);
  blankRow();

  addTitle("طرق تحصيل الإيرادات");
  addTableHeader("طريقة الدفع", "المبلغ", "عدد العمليات");
  paymentMethodTotals.forEach((m) => {
    const row = summaryWs.addRow([m.label, m.amount, m.count]);
    row.getCell(2).numFmt = MONEY_FMT;
  });
  blankRow();

  addTitle("بوابة الدفع (UPayments)");
  addMoneyRow("إيرادات البوابة", totals.gatewayRevenue);
  addMoneyRow("العمولة", totals.gatewayFees);
  addMoneyRow("الصافي", totals.gatewayNet);
  blankRow();

  addTitle("المصروفات حسب القسم");
  addTableHeader("القسم", "نوع القسم", "المبلغ");
  summarySections.forEach((s) => {
    const row = summaryWs.addRow([s.name, sectionTypeLabel(s.type), sectionTotals[s.id] ?? 0]);
    row.getCell(3).numFmt = MONEY_FMT;
  });
  blankRow();

  addTitle("التكاليف حسب القسم");
  addTableHeader("القسم", "المبلغ");
  if (costSections.length === 0) {
    summaryWs.addRow(["لا توجد أقسام تكاليف"]);
  } else {
    costSections.forEach((s) => {
      const row = summaryWs.addRow([s.name, costSectionTotals[s.id] ?? 0]);
      row.getCell(2).numFmt = MONEY_FMT;
    });
  }
  blankRow();

  addTitle("أرصدة الحسابات (ملخص)");
  addTableHeader("الحساب", "الإيرادات", "المصروفات", "الرصيد");
  accountBalances.forEach((b) => {
    const row = summaryWs.addRow([b.label, b.income, b.outgo, b.balance]);
    row.getCell(2).numFmt = MONEY_FMT;
    row.getCell(3).numFmt = MONEY_FMT;
    row.getCell(4).numFmt = MONEY_FMT;
  });
  const netRow = summaryWs.addRow(["الصافي الإجمالي", "", "", totals.accountsNetTotal]);
  netRow.eachCell((c) => (c.font = { bold: true }));
  netRow.getCell(4).numFmt = MONEY_FMT;

  /* ── (b) إيرادات العقود ── */
  addDataSheet(
    workbook,
    "إيرادات العقود",
    [
      { header: "كود العقد", key: "code", width: 16 },
      { header: "اسم العميل", key: "client", width: 24 },
      { header: "المبلغ", key: "amount", width: 14 },
      { header: "طريقة الدفع", key: "method", width: 14 },
      { header: "تاريخ الدفع", key: "date", width: 16 },
      { header: "تاريخ الاستحقاق", key: "dueDate", width: 16 },
      { header: "حالة بوابة الدفع", key: "gatewayStatus", width: 16 },
      { header: "عمولة البوابة", key: "gatewayFee", width: 14 },
      { header: "ملاحظات", key: "notes", width: 26 },
    ],
    contractPayments.map((p) => {
      const { code, client } = contractLabel(p.contractId, contracts, clientUsers);
      return {
        code,
        client,
        amount: p.amount,
        method: paymentMethodLabel(p.paymentMethod),
        date: formatDate(p.paymentDate),
        dueDate: formatDate(p.dueDate),
        gatewayStatus: p.paymentMethod === "gateway" ? gatewayStatusLabel(p.gatewayStatus) : "—",
        gatewayFee: p.gatewayFeeAmount ?? 0,
        notes: p.notes || "—",
      };
    }),
    { code: "الإجمالي", amount: totals.contractRevenue }
  );

  /* ── (c) إيرادات المهام المستقلة ── */
  addDataSheet(
    workbook,
    "إيرادات المهام المستقلة",
    [
      { header: "المهمة", key: "title", width: 26 },
      { header: "اسم العميل", key: "clientName", width: 22 },
      { header: "هاتف العميل", key: "clientPhone", width: 16 },
      { header: "المبلغ", key: "amount", width: 14 },
      { header: "طريقة الدفع", key: "method", width: 14 },
      { header: "تاريخ الدفع", key: "date", width: 16 },
      { header: "تاريخ الاستحقاق", key: "dueDate", width: 16 },
      { header: "عمولة البوابة", key: "gatewayFee", width: 14 },
      { header: "ملاحظات", key: "notes", width: 26 },
    ],
    taskPayments.map((p) => {
      const task = standaloneTasks.find((t) => t.id === p.taskId);
      return {
        title: task?.title ?? "—",
        clientName: task?.clientName ?? "—",
        clientPhone: task?.clientPhone ?? "—",
        amount: p.amount,
        method: paymentMethodLabel(p.paymentMethod),
        date: formatDate(p.paymentDate),
        dueDate: formatDate(p.dueDate),
        gatewayFee: p.gatewayFeeAmount ?? 0,
        notes: p.notes || "—",
      };
    }),
    { title: "الإجمالي", amount: totals.taskRevenue }
  );

  /* ── (d) مصروفات عامة ورواتب ── */
  const generalExpenses = expenses.filter((e) => {
    const section = sections.find((s) => s.id === e.sectionId);
    return section && section.kind === "expense" && section.type !== "vehicles";
  });
  addDataSheet(
    workbook,
    "مصروفات عامة ورواتب",
    [
      { header: "القسم", key: "section", width: 18 },
      { header: "نوع القسم", key: "sectionType", width: 12 },
      { header: "البند", key: "lineItem", width: 18 },
      { header: "الاسم", key: "name", width: 22 },
      { header: "الوصف", key: "description", width: 26 },
      { header: "المبلغ", key: "amount", width: 14 },
      { header: "تاريخ المصروف", key: "date", width: 16 },
      { header: "طريقة الدفع", key: "method", width: 14 },
      { header: "العامل المرتبط", key: "worker", width: 20 },
      { header: "ملاحظة", key: "note", width: 24 },
    ],
    generalExpenses.map((e) => {
      const section = sections.find((s) => s.id === e.sectionId);
      const lineItem = lineItems.find((li) => li.id === e.lineItemId);
      const worker = workers.find((w) => w.id === e.workerId);
      return {
        section: section?.name ?? "—",
        sectionType: sectionTypeLabel(section?.type ?? "general"),
        lineItem: lineItem?.name ?? "—",
        name: e.name,
        description: e.description || "—",
        amount: e.amount,
        date: formatDate(e.expenseDate),
        method: paymentMethodLabel(e.paymentMethod),
        worker: worker?.name ?? "—",
        note: e.note || "—",
      };
    }),
    { section: "الإجمالي", amount: generalExpenses.reduce((s, e) => s + e.amount, 0) }
  );

  /* ── (e) مصاريف السيارات ── */
  addDataSheet(
    workbook,
    "مصاريف السيارات",
    [
      { header: "رقم اللوحة", key: "plate", width: 16 },
      { header: "البند", key: "lineItem", width: 18 },
      { header: "الوصف", key: "description", width: 28 },
      { header: "المبلغ", key: "amount", width: 14 },
      { header: "تاريخ المصروف", key: "date", width: 16 },
      { header: "طريقة الدفع", key: "method", width: 14 },
    ],
    vehicleExpenses.map((e) => {
      const vehicle = vehicles.find((v) => v.id === e.vehicleId);
      const lineItem = lineItems.find((li) => li.id === e.lineItemId);
      return {
        plate: vehicle?.plateNumber ?? "—",
        lineItem: lineItem?.name ?? "—",
        description: e.description || "—",
        amount: e.amount,
        date: formatDate(e.expenseDate),
        method: paymentMethodLabel(e.paymentMethod),
      };
    }),
    { plate: "الإجمالي", amount: vehicleExpenses.reduce((s, e) => s + e.amount, 0) }
  );

  /* ── (f) التكاليف ── */
  const costExpenses = expenses.filter((e) => {
    const section = sections.find((s) => s.id === e.sectionId);
    return section && section.kind === "cost";
  });
  addDataSheet(
    workbook,
    "التكاليف",
    [
      { header: "القسم", key: "section", width: 18 },
      { header: "البند", key: "lineItem", width: 18 },
      { header: "الاسم", key: "name", width: 22 },
      { header: "الوصف", key: "description", width: 26 },
      { header: "المبلغ", key: "amount", width: 14 },
      { header: "تاريخ المصروف", key: "date", width: 16 },
      { header: "طريقة الدفع", key: "method", width: 14 },
      { header: "ملاحظة", key: "note", width: 24 },
    ],
    costExpenses.map((e) => {
      const section = sections.find((s) => s.id === e.sectionId);
      const lineItem = lineItems.find((li) => li.id === e.lineItemId);
      return {
        section: section?.name ?? "—",
        lineItem: lineItem?.name ?? "—",
        name: e.name,
        description: e.description || "—",
        amount: e.amount,
        date: formatDate(e.expenseDate),
        method: paymentMethodLabel(e.paymentMethod),
        note: e.note || "—",
      };
    }),
    { section: "الإجمالي", amount: totals.totalCosts }
  );

  /* ── (g) أرصدة الحسابات ── */
  addDataSheet(
    workbook,
    "أرصدة الحسابات",
    [
      { header: "الحساب", key: "label", width: 18 },
      { header: "الإيرادات", key: "income", width: 16 },
      { header: "المصروفات", key: "outgo", width: 16 },
      { header: "الرصيد", key: "balance", width: 16 },
    ],
    accountBalances.map((b) => ({ label: b.label, income: b.income, outgo: b.outgo, balance: b.balance })),
    { label: "الإجمالي", balance: totals.accountsNetTotal }
  );

  const buffer = await workbook.xlsx.writeBuffer();
  const blob = new Blob([buffer], {
    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = fileName;
  a.click();
  URL.revokeObjectURL(url);
}
