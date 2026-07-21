import { Fragment, useEffect, useRef, useState } from "react";
import { container } from "@infrastructure/di/container";
import { CustomSelect } from "@presentation/components/CustomSelect";
import { LoadingState, ErrorState } from "@presentation/components/States";
import { useToast } from "@presentation/components/ToastProvider";
import { useTour } from "@presentation/components/tour/useTour";
import { Contract } from "@domain/entities/Contract";
import { ContractPayment, PaymentMethod } from "@domain/entities/ContractPayment";
import { StandaloneTask } from "@domain/entities/StandaloneTask";
import { StandaloneTaskPayment } from "@domain/entities/StandaloneTaskPayment";
import { CompanyExpense } from "@domain/entities/CompanyExpense";
import { ExpenseSection } from "@domain/entities/ExpenseSection";
import { ExpenseLineItem } from "@domain/entities/ExpenseLineItem";
import { Worker } from "@domain/entities/Worker";
import { User } from "@domain/entities/User";
import { Vehicle } from "@domain/entities/Vehicle";
import { VehicleExpense } from "@domain/entities/VehicleExpense";
import {
  Wallet, Plus, X, Save, Pencil, Trash2, Loader2, TrendingUp, TrendingDown, Scale,
  FileText, HardHat, Car, AlertCircle, DollarSign, Calendar, Banknote,
  Smartphone, Zap, MoreHorizontal, Settings, Tag, ChevronDown, ChevronUp, Layers, Download,
  KeyRound, Link2,
} from "lucide-react";
import { exportCompanyAccountsToExcel } from "@presentation/utils/exportCompanyAccounts";
import "@presentation/styles/admin/company-accounts.css";

const PAYMENT_METHOD_OPTIONS: { id: PaymentMethod; label: string }[] = [
  { id: "cash", label: "نقدي" },
  { id: "transfer", label: "رابط" },
  { id: "cheque", label: "شيك" },
  { id: "card", label: "ومض" },
];

const EXPENSE_PAYMENT_METHOD_OPTIONS: { id: PaymentMethod; label: string }[] = [
  { id: "cash", label: "نقدي" },
  { id: "transfer", label: "رابط" },
  { id: "cheque", label: "شيك" },
  { id: "card", label: "ومض" },
  { id: "gateway", label: "UPayments" },
];

const paymentMethodLabel = (method: PaymentMethod) =>
  PAYMENT_METHOD_OPTIONS.find((o) => o.id === method)?.label ?? method;

const formatMoney = (n: number) =>
  `${n.toLocaleString("en-US", { maximumFractionDigits: 2 })} د.ك`;

const formatDate = (d: string) => {
  if (!d) return "—";
  return new Date(d).toLocaleDateString("ar-EG", { year: "numeric", month: "short", day: "numeric" });
};

const currentMonth = () => {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
};

const sum = (arr: { amount: number }[]) => arr.reduce((s, x) => s + x.amount, 0);

type MainTab = "overview" | "revenue" | "expenses" | "costs" | "accounts";
type RangePreset = "today" | "last7" | "thisMonth" | "quarter" | "year" | "custom" | "max";
type RevenueTab = "contracts" | "tasks";

const RANGE_PRESET_OPTIONS: { id: RangePreset; label: string }[] = [
  { id: "today", label: "اليوم" },
  { id: "last7", label: "آخر 7 أيام" },
  { id: "thisMonth", label: "هذا الشهر" },
  { id: "quarter", label: "ربع سنوي" },
  { id: "year", label: "سنوي" },
  { id: "custom", label: "من تاريخ والي تاريخ" },
  { id: "max", label: "الحد الأقصى" },
];

const computeDateRange = (preset: RangePreset, customFrom: string, customTo: string): { from: string | null; to: string | null } => {
  const todayStr = new Date().toISOString().slice(0, 10);
  const daysAgo = (n: number) => { const d = new Date(); d.setDate(d.getDate() - n); return d.toISOString().slice(0, 10); };
  const monthsAgo = (n: number) => { const d = new Date(); d.setMonth(d.getMonth() - n); return d.toISOString().slice(0, 10); };
  switch (preset) {
    case "today": return { from: todayStr, to: todayStr };
    case "last7": return { from: daysAgo(6), to: todayStr };
    case "thisMonth": return { from: `${todayStr.slice(0, 7)}-01`, to: todayStr };
    case "quarter": return { from: monthsAgo(3), to: todayStr };
    case "year": return { from: monthsAgo(12), to: todayStr };
    case "custom": return { from: customFrom || null, to: customTo || null };
    default: return { from: null, to: null }; // max
  }
};

const rangeLabel = (preset: RangePreset, from: string | null, to: string | null): string =>
  preset === "max"
    ? "كل الوقت"
    : preset === "custom"
      ? (from && to ? `من ${from} إلى ${to}` : "اختر نطاق التاريخ")
      : (RANGE_PRESET_OPTIONS.find((o) => o.id === preset)?.label ?? "");

const SectionIcon = ({ type, size = 14 }: { type: string; size?: number }) => {
  if (type === "salary") return <HardHat size={size} />;
  if (type === "vehicles") return <Car size={size} />;
  return <Tag size={size} />;
};

export const CompanyAccountsPage = () => {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<MainTab>("overview");
  const [revenueTab, setRevenueTab] = useState<RevenueTab>("contracts");
  const [activeSectionId, setActiveSectionId] = useState<string | null>(null);
  const [activeCostSectionId, setActiveCostSectionId] = useState<string | null>(null);
  const [isSectionManagerOpen, setIsSectionManagerOpen] = useState(false);
  const [isCostSectionManagerOpen, setIsCostSectionManagerOpen] = useState(false);
  const [filterPreset, setFilterPreset] = useState<RangePreset>("thisMonth");
  const [filterCustomFrom, setFilterCustomFrom] = useState("");
  const [filterCustomTo, setFilterCustomTo] = useState("");
  const [feeAmount, setFeeAmount] = useState(0.13);
  const [isFeeAmountModalOpen, setIsFeeAmountModalOpen] = useState(false);
  const [isSandboxMode, setIsSandboxMode] = useState(true);
  const [isSandboxModalOpen, setIsSandboxModalOpen] = useState(false);
  const [hasPaymentCredentials, setHasPaymentCredentials] = useState(false);
  const [isCredentialsModalOpen, setIsCredentialsModalOpen] = useState(false);
  const [isExporting, setIsExporting] = useState(false);

  const [contracts, setContracts] = useState<Contract[]>([]);
  const [clientUsers, setClientUsers] = useState<User[]>([]);
  const [contractPayments, setContractPayments] = useState<ContractPayment[]>([]);
  const [standaloneTasks, setStandaloneTasks] = useState<StandaloneTask[]>([]);
  const [taskPayments, setTaskPayments] = useState<StandaloneTaskPayment[]>([]);
  const [overdueContractPayments, setOverdueContractPayments] = useState<ContractPayment[]>([]);
  const [overdueTaskPayments, setOverdueTaskPayments] = useState<StandaloneTaskPayment[]>([]);
  const [expenses, setExpenses] = useState<CompanyExpense[]>([]);
  const [sections, setSections] = useState<ExpenseSection[]>([]);
  const [lineItems, setLineItems] = useState<ExpenseLineItem[]>([]);
  const [workers, setWorkers] = useState<Worker[]>([]);
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [vehicleExpenses, setVehicleExpenses] = useState<VehicleExpense[]>([]);

  const { notify } = useToast();
  const repo = container.adminRepository;

  const loadData = async () => {
    try {
      setLoading(true);
      const [
        contractsData, clientUsersData, contractPaymentsData,
        tasksData, taskPaymentsData, expensesData,
        sectionsData, lineItemsData,
        workersData, vehiclesData, vehicleExpensesData,
        feeAmountData, overdueContractPaymentsData, overdueTaskPaymentsData,
        sandboxModeData, hasCredentialsData,
      ] = await Promise.all([
        repo.listContracts(),
        repo.listClientUsers(),
        repo.listAllContractPayments(),
        repo.listStandaloneTasks(),
        repo.listAllStandaloneTaskPayments(),
        repo.listCompanyExpenses(),
        repo.listExpenseSections(),
        repo.listExpenseLineItems(),
        container.workerRepository.listWorkers(),
        container.fleetRepository.listVehicles(),
        container.fleetRepository.listAllExpenses(),
        repo.getUpaymentsFeeAmount(),
        repo.listOverdueContractPayments(),
        repo.listOverdueStandaloneTaskPayments(),
        repo.getUpaymentsSandboxMode(),
        repo.hasTenantPaymentCredentials(),
      ]);
      setContracts(contractsData);
      setClientUsers(clientUsersData);
      setContractPayments(contractPaymentsData);
      setStandaloneTasks(tasksData);
      setTaskPayments(taskPaymentsData);
      setOverdueContractPayments(overdueContractPaymentsData);
      setOverdueTaskPayments(overdueTaskPaymentsData);
      setExpenses(expensesData);
      setSections(sectionsData);
      setLineItems(lineItemsData);
      setWorkers(workersData);
      setVehicles(vehiclesData);
      setVehicleExpenses(vehicleExpensesData);
      setFeeAmount(feeAmountData);
      setIsSandboxMode(sandboxModeData);
      setHasPaymentCredentials(hasCredentialsData);
      if (!activeSectionId) {
        const first = sectionsData.find(s => s.kind === 'expense');
        if (first) setActiveSectionId(first.id);
      }
      if (!activeCostSectionId) {
        const first = sectionsData.find(s => s.kind === 'cost');
        if (first) setActiveCostSectionId(first.id);
      }
    } catch (e: any) {
      setError("تعذر تحميل بيانات الحسابات: " + (e?.message || ""));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { loadData(); }, []);

  useEffect(() => {
    const exp = sections.filter(s => s.kind === 'expense');
    if (exp[0] && (!activeSectionId || !exp.find(s => s.id === activeSectionId))) {
      setActiveSectionId(exp[0].id);
    }
  }, [sections]);

  useEffect(() => {
    const cst = sections.filter(s => s.kind === 'cost');
    if (cst[0] && (!activeCostSectionId || !cst.find(s => s.id === activeCostSectionId))) {
      setActiveCostSectionId(cst[0].id);
    }
  }, [sections]);

  useTour(
    "admin-company-accounts",
    loading || error
      ? []
      : [
          {
            target: ".ca-seg",
            title: "حسابات الشركة",
            content: "تابيات نظرة عامة، الإيرادات، المصروفات، التكاليف، والحسابات — كل تاب بيوضح جانب مختلف من الوضع المالي.",
          },
          {
            target: ".ca-filter-group",
            title: "الفترة الزمنية والتصدير",
            content: "اختار الفترة اللي عايز تشوف بياناتها، وصدّر كل الأرقام إلى ملف Excel من هنا.",
          },
          {
            target: ".ca-summary-strip",
            title: "الملخص المالي",
            content: "إجمالي الإيرادات والمصروفات والتكاليف وصافي الربح للفترة المحددة.",
          },
        ]
  );

  if (loading) return <LoadingState />;
  if (error) return <ErrorState text={error} />;

  const { from: filterFrom, to: filterTo } = computeDateRange(filterPreset, filterCustomFrom, filterCustomTo);
  const filterRangeLabel = rangeLabel(filterPreset, filterFrom, filterTo);

  const matchDate = (dateStr: string) =>
    (!filterFrom || dateStr >= filterFrom) && (!filterTo || dateStr <= filterTo);

  const viewContractPayments = contractPayments.filter((p) => matchDate(p.paymentDate));
  const viewTaskPayments = taskPayments.filter((p) => matchDate(p.paymentDate));
  const viewExpenses = expenses.filter((e) => matchDate(e.expenseDate));
  const viewVehicleExpenses = vehicleExpenses.filter((e) => matchDate(e.expenseDate));

  const contractRevenue = sum(viewContractPayments);
  const taskRevenue = sum(viewTaskPayments);
  const totalRevenue = contractRevenue + taskRevenue;

  const gatewayFees = [...viewContractPayments, ...viewTaskPayments]
    .filter((p) => (p as any).paymentMethod === "gateway")
    .reduce((s, p) => s + ((p as any).gatewayFeeAmount ?? 0), 0);
  const netRevenue = totalRevenue - gatewayFees;

  const expenseSections = sections.filter(s => s.kind === 'expense');
  const costSections    = sections.filter(s => s.kind === 'cost');
  const expenseSectionIds = new Set(expenseSections.map(s => s.id));
  const costSectionIds    = new Set(costSections.map(s => s.id));

  // Totals per expense section
  const sectionTotals: Record<string, number> = {};
  viewExpenses.forEach((e) => {
    if (e.sectionId && expenseSectionIds.has(e.sectionId)) {
      sectionTotals[e.sectionId] = (sectionTotals[e.sectionId] || 0) + e.amount;
    }
  });
  const vehiclesSection = sections.find((s) => s.type === "vehicles");
  if (vehiclesSection) sectionTotals[vehiclesSection.id] = sum(viewVehicleExpenses);

  // Totals per cost section
  const costSectionTotals: Record<string, number> = {};
  viewExpenses.forEach((e) => {
    if (e.sectionId && costSectionIds.has(e.sectionId)) {
      costSectionTotals[e.sectionId] = (costSectionTotals[e.sectionId] || 0) + e.amount;
    }
  });

  const totalExpenses = Object.values(sectionTotals).reduce((a, b) => a + b, 0);
  const totalCosts    = Object.values(costSectionTotals).reduce((a, b) => a + b, 0);
  const net = netRevenue - totalExpenses - totalCosts;

  const paymentMethods = [
    { method: "cash",     label: "نقدي",      Icon: Banknote,   fillClass: "ca-brow-fill--pm-cash"     },
    { method: "transfer", label: "رابط",      Icon: Smartphone, fillClass: "ca-brow-fill--pm-transfer"  },
    { method: "cheque",   label: "شيك",       Icon: FileText,   fillClass: "ca-brow-fill--pm-cheque"    },
    { method: "card",     label: "ومض",       Icon: Zap,        fillClass: "ca-brow-fill--pm-card"      },
    { method: "gateway",  label: "UPayments", Icon: DollarSign, fillClass: "ca-brow-fill--pm-gateway"   },
  ];
  const allRevenuePayments = [...viewContractPayments, ...viewTaskPayments];
  const paymentMethodTotals = paymentMethods.map((m) => ({
    ...m,
    amount: sum(allRevenuePayments.filter((p) => p.paymentMethod === m.method)),
    count: allRevenuePayments.filter((p) => p.paymentMethod === m.method).length,
  }));
  const gatewayRevenue = paymentMethodTotals.find((m) => m.method === "gateway")?.amount ?? 0;
  const gatewayNet = gatewayRevenue - gatewayFees;

  // Account balances — now driven by the page's shared global filter
  // (filterPreset/filterFrom/filterTo) instead of an independent range.
  const accountBalances = [
    ...paymentMethods,
    { method: "unspecified", label: "غير محدد", Icon: MoreHorizontal, fillClass: "ca-brow-fill--pm-unspecified" },
  ].map((m) => {
    const key = m.method === "unspecified" ? null : m.method;
    const income = sum(allRevenuePayments.filter((p) => (p.paymentMethod || null) === key));
    const outgo = sum([...viewExpenses, ...viewVehicleExpenses].filter((e) => ((e as any).paymentMethod || null) === key))
      + (m.method === "gateway" ? gatewayFees : 0);
    return { ...m, income, outgo, balance: income - outgo };
  });
  const accountsNetTotal = accountBalances.reduce((s, b) => s + b.balance, 0);

  const buildExportFileName = () =>
    filterPreset === "max"
      ? "حسابات-الشركة_كل-الوقت.xlsx"
      : filterFrom && filterTo
        ? `حسابات-الشركة_${filterFrom}_${filterTo}.xlsx`
        : `حسابات-الشركة_${filterRangeLabel}.xlsx`;

  const handleExport = async () => {
    setIsExporting(true);
    try {
      await exportCompanyAccountsToExcel({
        rangeLabel: filterRangeLabel,
        filterFrom,
        filterTo,
        contractPayments: viewContractPayments,
        taskPayments: viewTaskPayments,
        expenses: viewExpenses,
        vehicleExpenses: viewVehicleExpenses,
        contracts,
        clientUsers,
        standaloneTasks,
        workers,
        vehicles,
        sections,
        lineItems,
        totals: {
          contractRevenue, taskRevenue, totalRevenue, gatewayFees, netRevenue,
          totalExpenses, totalCosts, net, gatewayRevenue, gatewayNet, accountsNetTotal,
        },
        sectionTotals,
        costSectionTotals,
        paymentMethodTotals,
        accountBalances,
        fileName: buildExportFileName(),
      });
      notify("تم تصدير ملف Excel بنجاح");
    } catch (e: any) {
      notify("فشل تصدير الملف: " + (e?.message || ""));
    } finally {
      setIsExporting(false);
    }
  };

  const revenueTabs = [
    { id: "contracts" as RevenueTab, label: "إيرادات العقود", icon: FileText,   amount: contractRevenue },
    { id: "tasks"     as RevenueTab, label: "إيرادات المهام", icon: DollarSign, amount: taskRevenue },
  ];

  const activeSection     = expenseSections.find((s) => s.id === activeSectionId) ?? null;
  const activeCostSection = costSections.find((s) => s.id === activeCostSectionId) ?? null;

  return (
    <div className="ca-page">

      {/* Top bar */}
      <div className="ca-topbar">
        <div className="ca-topbar-right">
          <div className="ca-title-icon"><Wallet size={20} /></div>
          <h2 className="ca-title">حسابات الشركة</h2>
        </div>
      </div>

      {/* Main tabs + filter */}
      <div className="ca-topbar-left">
        <div className="ca-seg">
          <button className={`ca-seg-tab ${activeTab === "overview" ? "active" : ""}`} onClick={() => setActiveTab("overview")}>
            <Scale size={15} /><span>نظرة عامة</span>
          </button>
          <button className={`ca-seg-tab ca-seg-tab--green ${activeTab === "revenue" ? "active" : ""}`} onClick={() => setActiveTab("revenue")}>
            <TrendingUp size={15} /><span>الإيرادات</span>
            <span className="ca-seg-badge ca-seg-badge--green">{formatMoney(totalRevenue)}</span>
          </button>
          <button className={`ca-seg-tab ca-seg-tab--red ${activeTab === "expenses" ? "active" : ""}`} onClick={() => setActiveTab("expenses")}>
            <TrendingDown size={15} /><span>المصروفات</span>
            <span className="ca-seg-badge ca-seg-badge--red">{formatMoney(totalExpenses)}</span>
          </button>
          <button className={`ca-seg-tab ca-seg-tab--orange ${activeTab === "costs" ? "active" : ""}`} onClick={() => setActiveTab("costs")}>
            <Layers size={15} /><span>التكاليف</span>
            <span className="ca-seg-badge ca-seg-badge--orange">{formatMoney(totalCosts)}</span>
          </button>
          <button className={`ca-seg-tab ${activeTab === "accounts" ? "active" : ""}`} onClick={() => setActiveTab("accounts")}>
            <Wallet size={15} /><span>الحسابات</span>
            <span className={`ca-seg-badge ${accountsNetTotal >= 0 ? "ca-seg-badge--green" : "ca-seg-badge--red"}`}>{formatMoney(accountsNetTotal)}</span>
          </button>
        </div>

        <div className="ca-filter-group">
          <CustomSelect
            value={filterPreset}
            onChange={(val) => setFilterPreset(val as RangePreset)}
            options={RANGE_PRESET_OPTIONS}
            width="180px"
          />

          {filterPreset === "custom" && (
            <div className="ca-accounts-custom-range ca-date-filters">
              <label className="ca-date-field">
                <span className="ca-date-field-label">من تاريخ</span>
                <input
                  type="date"
                  className="input ca-filter-input"
                  value={filterCustomFrom}
                  max={filterCustomTo || undefined}
                  onChange={(e) => setFilterCustomFrom(e.target.value)}
                />
              </label>
              <div className="ca-date-sep" />
              <label className="ca-date-field">
                <span className="ca-date-field-label">والي تاريخ</span>
                <input
                  type="date"
                  className="input ca-filter-input"
                  value={filterCustomTo}
                  min={filterCustomFrom || undefined}
                  onChange={(e) => setFilterCustomTo(e.target.value)}
                />
              </label>
            </div>
          )}

          <button
            className="button secondary"
            onClick={handleExport}
            disabled={isExporting || (totalRevenue === 0 && totalExpenses === 0 && totalCosts === 0)}
            title="تصدير Excel"
            style={{ height: "42px", width: "42px", padding: 0, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}
          >
            {isExporting ? <Loader2 size={18} className="spin" /> : <Download size={18} />}
          </button>
        </div>
      </div>

      {/* ── Overview ── */}
      {activeTab === "overview" && (
        <div className="ca-overview">
          <div className="card ca-summary-strip">
            <div className="ca-summary-metric">
              <div className="ca-summary-metric-top">
                <span className="ca-summary-icon ca-summary-icon--green"><TrendingUp size={14} /></span>
                <span className="ca-summary-label">إجمالي الإيرادات</span>
              </div>
              <span className="ca-summary-value ca-summary-value--green">{formatMoney(totalRevenue)}</span>
            </div>
            <div className="ca-summary-sep" />
            <div className="ca-summary-metric">
              <div className="ca-summary-metric-top">
                <span className="ca-summary-icon ca-summary-icon--red"><TrendingDown size={14} /></span>
                <span className="ca-summary-label">إجمالي المصروفات</span>
              </div>
              <span className="ca-summary-value ca-summary-value--red">{formatMoney(totalExpenses)}</span>
            </div>
            <div className="ca-summary-sep" />
            <div className="ca-summary-metric">
              <div className="ca-summary-metric-top">
                <span className="ca-summary-icon ca-summary-icon--orange"><Layers size={14} /></span>
                <span className="ca-summary-label">إجمالي التكاليف</span>
              </div>
              <span className="ca-summary-value ca-summary-value--orange">{formatMoney(totalCosts)}</span>
            </div>
            <div className="ca-summary-sep" />
            <div className="ca-summary-metric">
              <div className="ca-summary-metric-top">
                <span className={`ca-summary-icon ${net >= 0 ? "ca-summary-icon--green" : "ca-summary-icon--red"}`}><Scale size={14} /></span>
                <span className="ca-summary-label">الصافي</span>
              </div>
              <span className="ca-summary-value" style={{ color: net >= 0 ? "#16a34a" : "#dc2626" }}>{formatMoney(net)}</span>
            </div>
          </div>

          <div className="card ca-pm-strip">
            <div className="ca-pm-strip-title"><Banknote size={14} /><span>طرق تحصيل الإيرادات</span></div>
            <div className="ca-pm-strip-body">
              {paymentMethodTotals.filter((m) => m.method !== "gateway").map((m, i) => {
                const pct = totalRevenue > 0 ? Math.round((m.amount / totalRevenue) * 100) : 0;
                return (
                  <Fragment key={m.method}>
                    {i > 0 && <div className="ca-summary-sep" />}
                    <div className="ca-pm-metric">
                      <div className="ca-pm-metric-top">
                        <span className={`ca-pm-metric-icon ca-pm-metric-icon--${m.method}`}><m.Icon size={13} /></span>
                        <span className="ca-summary-label">{m.label}</span>
                        {m.count > 0 && <span className="ca-brow-count">{m.count}</span>}
                      </div>
                      <span className={`ca-pm-metric-value ca-pm-metric-value--${m.method}`}>{formatMoney(m.amount)}</span>
                      <div className="ca-brow-bar">
                        <div className={`ca-brow-fill ${m.fillClass}`} style={{ width: `${pct}%` }} />
                      </div>
                    </div>
                  </Fragment>
                );
              })}
            </div>
          </div>

          <div className="card ca-pm-strip">
            <div className="ca-pm-strip-title"><DollarSign size={14} /><span>بوابة الدفع (UPayments)</span></div>
            <div className="ca-summary-strip" style={{ border: "none" }}>
              <div className="ca-summary-metric">
                <div className="ca-summary-metric-top">
                  <span className="ca-summary-icon ca-summary-icon--green"><TrendingUp size={14} /></span>
                  <span className="ca-summary-label">إيرادات بوابة الدفع</span>
                </div>
                <span className="ca-summary-value ca-summary-value--green">{formatMoney(gatewayRevenue)}</span>
              </div>
              <div className="ca-summary-sep" />
              <div className="ca-summary-metric">
                <div className="ca-summary-metric-top">
                  <span className="ca-summary-icon ca-summary-icon--red"><TrendingDown size={14} /></span>
                  <span className="ca-summary-label">العمولة</span>
                </div>
                <span className="ca-summary-value ca-summary-value--red">- {formatMoney(gatewayFees)}</span>
              </div>
              <div className="ca-summary-sep" />
              <div className="ca-summary-metric">
                <div className="ca-summary-metric-top">
                  <span className={`ca-summary-icon ${gatewayNet >= 0 ? "ca-summary-icon--green" : "ca-summary-icon--red"}`}><Scale size={14} /></span>
                  <span className="ca-summary-label">الصافي</span>
                </div>
                <span className="ca-summary-value" style={{ color: gatewayNet >= 0 ? "#16a34a" : "#dc2626" }}>{formatMoney(gatewayNet)}</span>
              </div>
            </div>
          </div>

          <div className="ca-breakdown-grid ca-breakdown-grid--3">
            <div className="card ca-breakdown-card">
              <div className="ca-breakdown-header">
                <div className="ca-breakdown-header-dot ca-breakdown-header-dot--green" />
                <span>الإيرادات</span>
                <span className="ca-breakdown-header-total ca-breakdown-header-total--green">{formatMoney(totalRevenue)}</span>
              </div>
              {revenueTabs.map((t) => {
                const pct = totalRevenue > 0 ? Math.round((t.amount / totalRevenue) * 100) : 0;
                return (
                  <div key={t.id} className="ca-brow">
                    <div className="ca-brow-top">
                      <div className="ca-brow-label"><t.icon size={13} color="#9ca89a" /><span>{t.label}</span></div>
                      <span className="ca-brow-amount ca-brow-amount--green">{formatMoney(t.amount)}</span>
                    </div>
                    <div className="ca-brow-bar"><div className="ca-brow-fill ca-brow-fill--green" style={{ width: `${pct}%` }} /></div>
                  </div>
                );
              })}
            </div>

            <div className="card ca-breakdown-card">
              <div className="ca-breakdown-header">
                <div className="ca-breakdown-header-dot ca-breakdown-header-dot--red" />
                <span>المصروفات</span>
                <span className="ca-breakdown-header-total ca-breakdown-header-total--red">{formatMoney(totalExpenses)}</span>
              </div>
              {expenseSections.map((s) => {
                const amount = sectionTotals[s.id] ?? 0;
                const pct = totalExpenses > 0 ? Math.round((amount / totalExpenses) * 100) : 0;
                return (
                  <div key={s.id} className="ca-brow">
                    <div className="ca-brow-top">
                      <div className="ca-brow-label"><SectionIcon type={s.type} size={13} /><span>{s.name}</span></div>
                      <span className="ca-brow-amount ca-brow-amount--red">{formatMoney(amount)}</span>
                    </div>
                    <div className="ca-brow-bar"><div className="ca-brow-fill ca-brow-fill--red" style={{ width: `${pct}%` }} /></div>
                  </div>
                );
              })}
            </div>

            <div className="card ca-breakdown-card">
              <div className="ca-breakdown-header">
                <div className="ca-breakdown-header-dot ca-breakdown-header-dot--orange" />
                <span>التكاليف</span>
                <span className="ca-breakdown-header-total ca-breakdown-header-total--orange">{formatMoney(totalCosts)}</span>
              </div>
              {costSections.length === 0 && (
                <div style={{ padding: "20px 0", textAlign: "center", color: "#b0b8ae", fontSize: "0.8rem" }}>لا توجد أقسام تكاليف</div>
              )}
              {costSections.map((s) => {
                const amount = costSectionTotals[s.id] ?? 0;
                const pct = totalCosts > 0 ? Math.round((amount / totalCosts) * 100) : 0;
                return (
                  <div key={s.id} className="ca-brow">
                    <div className="ca-brow-top">
                      <div className="ca-brow-label"><Tag size={13} color="#9ca89a" /><span>{s.name}</span></div>
                      <span className="ca-brow-amount ca-brow-amount--orange">{formatMoney(amount)}</span>
                    </div>
                    <div className="ca-brow-bar"><div className="ca-brow-fill ca-brow-fill--orange" style={{ width: `${pct}%` }} /></div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      )}

      {/* ── Revenue ── */}
      {activeTab === "revenue" && (
        <div className="ca-section-page">
          <div className="ca-seg">
            {revenueTabs.map((t) => (
              <button key={t.id} className={`ca-seg-tab ca-seg-tab--green ${revenueTab === t.id ? "active" : ""}`} onClick={() => setRevenueTab(t.id)}>
                <t.icon size={14} /><span>{t.label}</span>
                <span className="ca-seg-badge ca-seg-badge--green">{formatMoney(t.amount)}</span>
              </button>
            ))}
          </div>
          {revenueTab === "contracts" && (
            <ContractRevenueSection payments={viewContractPayments} contracts={contracts} clientUsers={clientUsers} />
          )}
          {revenueTab === "tasks" && (
            <TaskRevenueSection payments={viewTaskPayments} tasks={standaloneTasks} />
          )}
        </div>
      )}

      {/* ── Expenses ── */}
      {activeTab === "expenses" && (
        <div className="ca-section-page">
          {/* Section tabs row */}
          <div style={{ display: "flex", alignItems: "flex-start", gap: "10px", flexWrap: "wrap" }}>
            <div className="ca-seg" style={{ flexWrap: "wrap" }}>
              {expenseSections.map((s) => (
                <button
                  key={s.id}
                  className={`ca-seg-tab ca-seg-tab--red ${activeSectionId === s.id ? "active" : ""}`}
                  onClick={() => setActiveSectionId(s.id)}
                >
                  <SectionIcon type={s.type} size={14} />
                  <span>{s.name}</span>
                  <span className="ca-seg-badge ca-seg-badge--red">{formatMoney(sectionTotals[s.id] ?? 0)}</span>
                </button>
              ))}
            </div>
            <button
              className="button secondary"
              style={{ height: "42px", whiteSpace: "nowrap", flexShrink: 0 }}
              onClick={() => setIsSectionManagerOpen(true)}
            >
              <Settings size={16} />
              إدارة الأقسام
            </button>
          </div>

          {/* Active section content */}
          {activeSection?.type === "salary" && (
            <SalaryExpenseSection
              expenses={viewExpenses.filter((e) => e.sectionId === activeSection.id)}
              section={activeSection}
              workers={workers}
              onChanged={loadData}
              notify={notify}
            />
          )}
          {activeSection?.type === "vehicles" && (
            <VehicleExpenseSection
              expenses={viewVehicleExpenses}
              vehicles={vehicles}
              lineItems={lineItems.filter((li) => li.sectionId === activeSection.id)}
              section={activeSection}
              onChanged={loadData}
              notify={notify}
            />
          )}
          {activeSection?.type === "general" && (
            <GeneralExpenseSection
              section={activeSection}
              expenses={viewExpenses.filter((e) => e.sectionId === activeSection.id)}
              lineItems={lineItems.filter((li) => li.sectionId === activeSection.id)}
              onChanged={loadData}
              notify={notify}
            />
          )}
        </div>
      )}

      {/* ── Costs ── */}
      {activeTab === "costs" && (
        <div className="ca-section-page">
          <div style={{ display: "flex", alignItems: "flex-start", gap: "10px", flexWrap: "wrap" }}>
            <div className="ca-seg" style={{ flexWrap: "wrap" }}>
              {costSections.map((s) => (
                <button
                  key={s.id}
                  className={`ca-seg-tab ca-seg-tab--orange ${activeCostSectionId === s.id ? "active" : ""}`}
                  onClick={() => setActiveCostSectionId(s.id)}
                >
                  <Tag size={14} />
                  <span>{s.name}</span>
                  <span className="ca-seg-badge ca-seg-badge--orange">{formatMoney(costSectionTotals[s.id] ?? 0)}</span>
                </button>
              ))}
              {costSections.length === 0 && (
                <span style={{ padding: "10px 16px", color: "#b0b8ae", fontSize: "0.85rem" }}>لا توجد أقسام بعد</span>
              )}
            </div>
            <button
              className="button secondary"
              style={{ height: "42px", whiteSpace: "nowrap", flexShrink: 0 }}
              onClick={() => setIsCostSectionManagerOpen(true)}
            >
              <Settings size={16} />
              إدارة التكاليف
            </button>
          </div>

          {activeCostSection && (
            <GeneralExpenseSection
              section={activeCostSection}
              expenses={viewExpenses.filter((e) => e.sectionId === activeCostSection.id)}
              lineItems={lineItems.filter((li) => li.sectionId === activeCostSection.id)}
              onChanged={loadData}
              notify={notify}
            />
          )}

          {costSections.length === 0 && (
            <div className="card" style={{ padding: "48px", textAlign: "center", color: "#b0b8ae" }}>
              <Layers size={36} style={{ marginBottom: "12px", opacity: 0.3 }} />
              <p style={{ margin: 0, fontSize: "0.9rem" }}>لا توجد أقسام تكاليف بعد. أضف قسمًا من "إدارة التكاليف".</p>
            </div>
          )}
        </div>
      )}

      {/* ── الحسابات ── */}
      {activeTab === "accounts" && (
        <div className="ca-section-page">
          <div className="card ca-fee-card">
            <div className="ca-fee-card-info">
              <span className="ca-fee-card-label">عمولة UPayments</span>
              <span className="ca-fee-card-value">{feeAmount.toLocaleString("en-US", { maximumFractionDigits: 3 })} د.ك</span>
            </div>
            <button className="button secondary" onClick={() => setIsFeeAmountModalOpen(true)}>
              <Settings size={16} />
              تعديل
            </button>
          </div>

          <div className="card ca-fee-card">
            <div className="ca-fee-card-info">
              <span className="ca-fee-card-label">وضع بوابة الدفع (UPayments)</span>
              <span className="ca-fee-card-value" style={{ color: isSandboxMode ? "#d97706" : "#16a34a" }}>
                {isSandboxMode ? "تجريبي (Sandbox)" : "فعلي (Production)"}
              </span>
            </div>
            <button className="button secondary" onClick={() => setIsSandboxModalOpen(true)}>
              <Settings size={16} />
              تعديل
            </button>
          </div>

          <div className="card ca-fee-card">
            <div className="ca-fee-card-info">
              <span className="ca-fee-card-label">بيانات بوابة الدفع الخاصة بالشركة</span>
              <span className="ca-fee-card-value" style={{ color: hasPaymentCredentials ? "#16a34a" : "#d97706" }}>
                {hasPaymentCredentials ? "مُعدة ✓ (بيانات الشركة الخاصة)" : "غير مُعدة — يُستخدم النظام الافتراضي المشترك"}
              </span>
            </div>
            <button className="button secondary" onClick={() => setIsCredentialsModalOpen(true)}>
              <Settings size={16} />
              تعديل
            </button>
          </div>

          <div className="card ca-balances-card">
            <div className="ca-pm-strip-title">
              <Scale size={14} /><span>أرصدة الحسابات</span>
              <span className="ca-balances-badge">{filterRangeLabel}</span>
            </div>
            <table className="table ca-table" style={{ margin: 0, width: "100%" }}>
              <thead>
                <tr><Th>الحساب</Th><Th>الإيرادات</Th><Th>المصروفات</Th><Th>الرصيد</Th></tr>
              </thead>
              <tbody>
                {accountBalances.map((b) => (
                  <tr key={b.method} style={{ background: "white", borderBottom: "1px solid #f5f3ef" }}>
                    <td style={{ padding: "12px 14px", fontWeight: 700, display: "flex", alignItems: "center", gap: 8 }}>
                      <span className={`ca-pm-metric-icon ca-pm-metric-icon--${b.method}`}><b.Icon size={13} /></span>{b.label}
                    </td>
                    <td style={{ padding: "12px 14px", color: "#16a34a", fontWeight: 700 }}>{formatMoney(b.income)}</td>
                    <td style={{ padding: "12px 14px", color: "#dc2626", fontWeight: 700 }}>{formatMoney(b.outgo)}</td>
                    <td style={{ padding: "12px 14px", fontWeight: 800, color: b.balance >= 0 ? "#16a34a" : "#dc2626" }}>{formatMoney(b.balance)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {isFeeAmountModalOpen && (
        <FeeAmountModal
          currentAmount={feeAmount}
          onClose={() => setIsFeeAmountModalOpen(false)}
          onSaved={(newAmount) => { setFeeAmount(newAmount); setIsFeeAmountModalOpen(false); }}
          notify={notify}
        />
      )}

      {isSandboxModalOpen && (
        <SandboxModeModal
          currentSandbox={isSandboxMode}
          onClose={() => setIsSandboxModalOpen(false)}
          onSaved={(newSandbox) => { setIsSandboxMode(newSandbox); setIsSandboxModalOpen(false); }}
          notify={notify}
        />
      )}

      {isCredentialsModalOpen && (
        <PaymentCredentialsModal
          onClose={() => setIsCredentialsModalOpen(false)}
          onSaved={() => { setHasPaymentCredentials(true); setIsCredentialsModalOpen(false); }}
          notify={notify}
        />
      )}

      {/* Section Manager Modal (expenses) */}
      {isSectionManagerOpen && (
        <SectionManagerModal
          sections={expenseSections}
          lineItems={lineItems}
          kind="expense"
          onChanged={loadData}
          notify={notify}
          onClose={() => setIsSectionManagerOpen(false)}
        />
      )}

      {/* Section Manager Modal (costs) */}
      {isCostSectionManagerOpen && (
        <SectionManagerModal
          sections={costSections}
          lineItems={lineItems}
          kind="cost"
          onChanged={loadData}
          notify={notify}
          onClose={() => setIsCostSectionManagerOpen(false)}
        />
      )}
    </div>
  );
};

/* ─────────────────────────────────────────────────────
   Section Manager Modal
───────────────────────────────────────────────────── */
const SectionManagerModal = ({ sections, lineItems: _lineItems, kind, onChanged, notify, onClose }: {
  sections: ExpenseSection[];
  lineItems: ExpenseLineItem[];
  kind: 'expense' | 'cost';
  onChanged: () => void;
  notify: (msg: string) => void;
  onClose: () => void;
}) => {
  const [editingSection, setEditingSection] = useState<ExpenseSection | null>(null);
  const [isAddSection, setIsAddSection] = useState(false);
  const [deleteSectionConfirm, setDeleteSectionConfirm] = useState<ExpenseSection | null>(null);
  const repo = container.adminRepository;

  const handleAddSection = async (name: string) => {
    try {
      await repo.createExpenseSection({ name, kind });
      notify("تم إضافة القسم");
      setIsAddSection(false);
      onChanged();
    } catch (e: any) { notify("فشل إضافة القسم: " + (e?.message || "")); }
  };

  const handleUpdateSection = async (name: string) => {
    if (!editingSection) return;
    try {
      await repo.updateExpenseSection({ id: editingSection.id, name });
      notify("تم تحديث القسم");
      setEditingSection(null);
      onChanged();
    } catch (e: any) { notify("فشل تحديث القسم: " + (e?.message || "")); }
  };

  const handleDeleteSection = async () => {
    if (!deleteSectionConfirm) return;
    try {
      await repo.deleteExpenseSection(deleteSectionConfirm.id);
      notify("تم حذف القسم وجميع بياناته");
      setDeleteSectionConfirm(null);
      onChanged();
    } catch (e: any) { notify("فشل الحذف: " + (e?.message || "")); }
  };

  return (
    <div className="ca-modal-overlay" style={{ position: "fixed", inset: 0, background: "rgba(0,0,0,0.5)", backdropFilter: "blur(4px)", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 100 }}>
      <div className="card" style={{ width: "100%", maxWidth: "480px", maxHeight: "90vh", overflowY: "auto", padding: "24px" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "20px" }}>
          <h3 style={{ margin: 0, fontSize: "1.1rem", color: "#1a2a10", display: "flex", alignItems: "center", gap: "8px" }}>
            <Settings size={20} color="var(--primary)" />
            {kind === 'cost' ? 'إدارة أقسام التكاليف' : 'إدارة أقسام المصروفات'}
          </h3>
          <button onClick={onClose} style={{ background: "#f5f3ef", border: "none", borderRadius: "8px", width: "32px", height: "32px", display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" }}>
            <X size={20} />
          </button>
        </div>

        <p style={{ margin: "0 0 16px", fontSize: "0.82rem", color: "#9ca89a" }}>
          البنود تُدار من داخل كل قسم مباشرةً.
        </p>

        <div style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
          {sections.map((section) => (
            <div key={section.id} style={{ display: "flex", alignItems: "center", gap: "10px", padding: "12px 14px", border: "1px solid #e4e0d8", borderRadius: "10px", background: "#fafaf8" }}>
              <SectionIcon type={section.type} size={16} />
              <span style={{ flex: 1, fontWeight: 700, fontSize: "0.92rem", color: "#1a2a10" }}>{section.name}</span>
              {section.isSystem && (
                <span style={{ fontSize: "0.7rem", background: "#ece9e3", color: "#6b7a68", padding: "2px 8px", borderRadius: "20px", fontWeight: 600 }}>نظام</span>
              )}
              {!section.isSystem && (
                <button className="icon-button" onClick={() => setEditingSection(section)} title="تعديل"><Pencil size={15} /></button>
              )}
              {!section.isSystem && (
                <button className="icon-button" onClick={() => setDeleteSectionConfirm(section)} title="حذف" style={{ color: "#ef4444" }}><Trash2 size={15} /></button>
              )}
            </div>
          ))}

          {sections.length === 0 && (
            <div style={{ textAlign: "center", padding: "20px", color: "#b0b8ae", fontSize: "0.85rem" }}>لا توجد أقسام بعد</div>
          )}

          {isAddSection ? (
            <InlineNameInput placeholder="اسم القسم الجديد" onSubmit={handleAddSection} onCancel={() => setIsAddSection(false)} />
          ) : (
            <button className="button" style={{ marginTop: "4px", justifyContent: "center" }} onClick={() => setIsAddSection(true)}>
              <Plus size={16} /> إضافة قسم جديد
            </button>
          )}
        </div>
      </div>

      {editingSection && (
        <InlineModal title="تعديل القسم" onClose={() => setEditingSection(null)}>
          <InlineNameForm defaultName={editingSection.name} onSubmit={handleUpdateSection} onCancel={() => setEditingSection(null)} submitLabel="حفظ" />
        </InlineModal>
      )}

      {deleteSectionConfirm && (
        <DestructiveDeleteModal
          title="حذف القسم"
          description={`سيتم حذف قسم "${deleteSectionConfirm.name}" وجميع بنوده وجميع المصروفات المرتبطة به نهائياً. هذا الإجراء لا يمكن التراجع عنه.`}
          confirmWord={deleteSectionConfirm.name}
          onConfirm={handleDeleteSection}
          onClose={() => setDeleteSectionConfirm(null)}
        />
      )}
    </div>
  );
};

const InlineNameInput = ({ placeholder, onSubmit, onCancel }: { placeholder: string; onSubmit: (v: string) => void; onCancel: () => void }) => {
  const [val, setVal] = useState("");
  return (
    <div style={{ display: "flex", gap: "8px", marginTop: "8px" }}>
      <input
        className="input"
        placeholder={placeholder}
        value={val}
        onChange={(e) => setVal(e.target.value)}
        autoFocus
        onKeyDown={(e) => { if (e.key === "Enter" && val.trim()) onSubmit(val.trim()); if (e.key === "Escape") onCancel(); }}
        style={{ flex: 1 }}
      />
      <button className="button" onClick={() => val.trim() && onSubmit(val.trim())}><Plus size={16} /></button>
      <button className="button secondary" onClick={onCancel}><X size={16} /></button>
    </div>
  );
};

const InlineModal = ({ title, onClose, children }: { title: string; onClose: () => void; children: React.ReactNode }) => (
  <div style={{ position: "fixed", inset: 0, background: "rgba(0,0,0,0.6)", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 200 }}>
    <div className="card" style={{ width: "100%", maxWidth: "400px", padding: "24px" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "16px" }}>
        <h4 style={{ margin: 0, fontSize: "1rem", color: "#1a2a10" }}>{title}</h4>
        <button onClick={onClose} style={{ background: "#f5f3ef", border: "none", borderRadius: "8px", width: "28px", height: "28px", display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" }}><X size={16} /></button>
      </div>
      {children}
    </div>
  </div>
);

const InlineNameForm = ({ defaultName, onSubmit, onCancel, submitLabel }: { defaultName: string; onSubmit: (v: string) => void; onCancel: () => void; submitLabel: string }) => {
  const [val, setVal] = useState(defaultName);
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "12px" }}>
      <input className="input" value={val} onChange={(e) => setVal(e.target.value)} autoFocus />
      <div style={{ display: "flex", gap: "10px" }}>
        <button className="button" style={{ flex: 1, justifyContent: "center" }} onClick={() => val.trim() && onSubmit(val.trim())}><Save size={16} />{submitLabel}</button>
        <button className="button secondary" onClick={onCancel}>إلغاء</button>
      </div>
    </div>
  );
};

/* ─────────────────────────────────────────────────────
   General Expense Section — sidebar layout
───────────────────────────────────────────────────── */
const GeneralExpenseSection = ({ section, expenses, lineItems, onChanged, notify }: {
  section: ExpenseSection;
  expenses: CompanyExpense[];
  lineItems: ExpenseLineItem[];
  onChanged: () => void;
  notify: (msg: string) => void;
}) => {
  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [editing, setEditing] = useState<CompanyExpense | null>(null);
  const [confirmDeleteExpense, setConfirmDeleteExpense] = useState<CompanyExpense | null>(null);
  const [deletingExpense, setDeletingExpense] = useState(false);

  const [activeLineItemId, setActiveLineItemId] = useState<string | null>(null);
  const [isAddingLineItem, setIsAddingLineItem] = useState(false);
  const [editingLineItem, setEditingLineItem] = useState<ExpenseLineItem | null>(null);
  const [confirmDeleteLineItem, setConfirmDeleteLineItem] = useState<ExpenseLineItem | null>(null);

  const repo = container.adminRepository;

  // Keep activeLineItemId valid when line items change
  useEffect(() => {
    if (activeLineItemId && !lineItems.find(li => li.id === activeLineItemId)) {
      setActiveLineItemId(null);
    }
  }, [lineItems]);

  /* ── Expense handlers ── */
  const handleCreate = async (data: any) => {
    try {
      await repo.createCompanyExpense({ ...data, sectionId: section.id, category: null });
      notify("تم إضافة المصروف");
      setIsCreateOpen(false);
      onChanged();
    } catch (e: any) { notify("فشل الإضافة: " + (e?.message || "")); }
  };

  const handleUpdate = async (data: any) => {
    try {
      await repo.updateCompanyExpense(data);
      notify("تم التحديث");
      setEditing(null);
      onChanged();
    } catch (e: any) { notify("فشل التحديث: " + (e?.message || "")); }
  };

  const handleDeleteExpense = async () => {
    if (!confirmDeleteExpense) return;
    setDeletingExpense(true);
    try {
      await repo.deleteCompanyExpense(confirmDeleteExpense.id);
      notify("تم الحذف");
      setConfirmDeleteExpense(null);
      onChanged();
    } catch (e: any) { notify("فشل الحذف: " + (e?.message || "")); }
    finally { setDeletingExpense(false); }
  };

  /* ── Line item handlers ── */
  const handleAddLineItem = async (name: string) => {
    try {
      await repo.createExpenseLineItem({ sectionId: section.id, name });
      notify("تم إضافة البند");
      setIsAddingLineItem(false);
      onChanged();
    } catch (e: any) { notify("فشل إضافة البند: " + (e?.message || "")); }
  };

  const handleUpdateLineItem = async (name: string) => {
    if (!editingLineItem) return;
    try {
      await repo.updateExpenseLineItem({ id: editingLineItem.id, name });
      notify("تم تحديث البند");
      setEditingLineItem(null);
      onChanged();
    } catch (e: any) { notify("فشل التحديث: " + (e?.message || "")); }
  };

  const handleDeleteLineItem = async () => {
    if (!confirmDeleteLineItem) return;
    try {
      await repo.deleteExpenseLineItem(confirmDeleteLineItem.id);
      notify("تم حذف البند");
      if (activeLineItemId === confirmDeleteLineItem.id) setActiveLineItemId(null);
      setConfirmDeleteLineItem(null);
      onChanged();
    } catch (e: any) { notify("فشل الحذف: " + (e?.message || "")); }
  };

  /* ── Derived data ── */
  const filteredExpenses = activeLineItemId === null
    ? expenses
    : expenses.filter(e => e.lineItemId === activeLineItemId);

  const liTotals: Record<string, number> = {};
  expenses.forEach(e => {
    if (e.lineItemId) liTotals[e.lineItemId] = (liTotals[e.lineItemId] || 0) + e.amount;
  });

  const showBandCol = activeLineItemId === null && lineItems.length > 0;

  return (
    <div className="card ca-section" style={{ padding: 0, overflow: "hidden", border: "1px solid #e4e0d8" }}>
      {/* Header */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "14px 16px", borderBottom: "1px solid #f5f3ef", flexWrap: "wrap", gap: "10px" }}>
        <h3 style={{ margin: 0, display: "flex", alignItems: "center", gap: "10px", fontSize: "1.05rem", color: "#1a2a10", fontWeight: 700 }}>
          <SectionIcon type={section.type} size={20} />
          {section.name}
          <span style={{ fontSize: "0.8rem", fontWeight: 600, color: "#9ca89a" }}>
            ({formatMoney(sum(expenses))})
          </span>
        </h3>
        <button className="button" onClick={() => setIsCreateOpen(true)}>
          <Plus size={18} /> إضافة
        </button>
      </div>

      {/* Split body */}
      <div className="ca-section-split">

        {/* ── Line items sidebar ── */}
        <div className="ca-li-sidebar">
          {/* "All" row */}
          <div
            className={`ca-li-item ${activeLineItemId === null ? "active" : ""}`}
            onClick={() => setActiveLineItemId(null)}
          >
            <Scale size={13} color="#9ca89a" style={{ flexShrink: 0 }} />
            <span className="ca-li-item-name">الإجمالي</span>
            <span className="ca-li-item-total">{formatMoney(sum(expenses))}</span>
          </div>

          {/* Each بند */}
          {lineItems.map(li => (
            <div
              key={li.id}
              className={`ca-li-item ${activeLineItemId === li.id ? "active" : ""}`}
              onClick={() => setActiveLineItemId(li.id)}
            >
              <Tag size={12} color="#9ca89a" style={{ flexShrink: 0 }} />
              <span className="ca-li-item-name">{li.name}</span>
              <span className="ca-li-item-total">{formatMoney(liTotals[li.id] ?? 0)}</span>
              <div className="ca-li-item-actions" onClick={e => e.stopPropagation()}>
                <button className="icon-button" title="تعديل" onClick={() => setEditingLineItem(li)}><Pencil size={12} /></button>
                <button className="icon-button" title="حذف" style={{ color: "#ef4444" }} onClick={() => setConfirmDeleteLineItem(li)}><Trash2 size={12} /></button>
              </div>
            </div>
          ))}

          {lineItems.length === 0 && !isAddingLineItem && (
            <div style={{ padding: "14px 13px", fontSize: "0.78rem", color: "#b0b8ae", textAlign: "center" }}>لا توجد بنود</div>
          )}

          {/* Add line item footer */}
          <div className="ca-li-sidebar-footer">
            {isAddingLineItem ? (
              <InlineNameInput
                placeholder="اسم البند"
                onSubmit={handleAddLineItem}
                onCancel={() => setIsAddingLineItem(false)}
              />
            ) : (
              <button className="ca-li-add-btn" onClick={() => setIsAddingLineItem(true)}>
                <Plus size={13} /> إضافة بند
              </button>
            )}
          </div>
        </div>

        {/* ── Expenses content ── */}
        <div className="ca-section-content">
          {filteredExpenses.length === 0 ? (
            <div className="ca-section-empty">
              <Tag size={28} style={{ opacity: 0.25 }} />
              <span>{lineItems.length === 0 ? "أضف بندًا من القائمة الجانبية ثم أضف مصروفات" : "لا توجد مصروفات لهذا البند"}</span>
            </div>
          ) : (
            <table className="table ca-table" style={{ margin: 0, width: "100%" }}>
              <thead>
                <tr>
                  {showBandCol && <Th>البند</Th>}
                  <Th>الاسم</Th>
                  <Th>المبلغ</Th>
                  <Th>التاريخ</Th>
                  <Th>ملاحظة</Th>
                  <Th center>الإجراءات</Th>
                </tr>
              </thead>
              <tbody>
                {filteredExpenses.map(e => (
                  <tr key={e.id} style={{ background: "white", borderBottom: "1px solid #f5f3ef" }}>
                    {showBandCol && (
                      <td style={{ padding: "12px 14px" }}>
                        {e.lineItemId ? (
                          <span style={{ fontSize: "0.78rem", background: "#eef3e8", padding: "2px 8px", borderRadius: "20px", color: "#3a6e2a", fontWeight: 600 }}>
                            {lineItems.find(li => li.id === e.lineItemId)?.name ?? "—"}
                          </span>
                        ) : <span style={{ color: "#b0b8ae", fontSize: "0.8rem" }}>—</span>}
                      </td>
                    )}
                    <td style={{ padding: "12px 14px", fontWeight: 700, color: "#1a2a10" }}>{e.name}</td>
                    <td style={{ padding: "12px 14px", fontWeight: 700 }}>{formatMoney(e.amount)}</td>
                    <td style={{ padding: "12px 14px", color: "#7c857a" }}>{formatDate(e.expenseDate)}</td>
                    <td style={{ padding: "12px 14px", color: "#7c857a" }}>{e.note || "—"}</td>
                    <td style={{ textAlign: "center", padding: "12px 14px" }}>
                      <RowActions onEdit={() => setEditing(e)} onDelete={() => setConfirmDeleteExpense(e)} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>

      {/* Expense modals */}
      {isCreateOpen && (
        <GeneralExpenseModal
          title="إضافة مصروف"
          lineItems={lineItems}
          defaultLineItemId={activeLineItemId ?? ""}
          onClose={() => setIsCreateOpen(false)}
          onSubmit={handleCreate}
        />
      )}
      {editing && (
        <GeneralExpenseModal
          title="تعديل مصروف"
          lineItems={lineItems}
          expense={editing}
          onClose={() => setEditing(null)}
          onSubmit={handleUpdate}
        />
      )}
      {confirmDeleteExpense && (
        <ConfirmDeleteModal
          name={confirmDeleteExpense.name}
          loading={deletingExpense}
          onConfirm={handleDeleteExpense}
          onClose={() => !deletingExpense && setConfirmDeleteExpense(null)}
        />
      )}

      {/* Line item modals */}
      {editingLineItem && (
        <InlineModal title="تعديل البند" onClose={() => setEditingLineItem(null)}>
          <InlineNameForm
            defaultName={editingLineItem.name}
            onSubmit={handleUpdateLineItem}
            onCancel={() => setEditingLineItem(null)}
            submitLabel="حفظ"
          />
        </InlineModal>
      )}
      {confirmDeleteLineItem && (
        <ConfirmDeleteModal
          name={confirmDeleteLineItem.name}
          loading={false}
          onConfirm={handleDeleteLineItem}
          onClose={() => setConfirmDeleteLineItem(null)}
        />
      )}
    </div>
  );
};

const GeneralExpenseModal = ({ title, lineItems, expense, defaultLineItemId, onClose, onSubmit }: {
  title: string; lineItems: ExpenseLineItem[]; expense?: CompanyExpense; defaultLineItemId?: string; onClose: () => void; onSubmit: (data: any) => void;
}) => {
  const [name, setName] = useState(expense?.name || "");
  const [lineItemId, setLineItemId] = useState(expense?.lineItemId || defaultLineItemId || "");
  const [description, setDescription] = useState(expense?.description || "");
  const [amount, setAmount] = useState(expense?.amount?.toString() || "");
  const [expenseDate, setExpenseDate] = useState(expense?.expenseDate || new Date().toISOString().slice(0, 10));
  const [note, setNote] = useState(expense?.note || "");
  const [paymentMethod, setPaymentMethod] = useState<string>(expense?.paymentMethod || "");
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim() || !amount || !expenseDate || !paymentMethod) return;
    setSubmitting(true);
    await onSubmit({
      ...(expense ? { id: expense.id } : {}),
      name: name.trim(),
      lineItemId: lineItemId || null,
      description: description.trim() || null,
      amount: Number(amount),
      expenseDate,
      note: note.trim() || null,
      workerId: null,
      paymentMethod: paymentMethod as PaymentMethod,
    });
    setSubmitting(false);
  };

  return (
    <Modal title={title} onClose={onClose}>
      <form onSubmit={handleSubmit} style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
        <FormField label="الاسم" icon={FileText} required>
          <input className="input" value={name} onChange={(e) => setName(e.target.value)} style={{ paddingRight: "40px" }} />
        </FormField>
        {lineItems.length > 0 && (
          <FormField label="البند">
            <CustomSelect
              value={lineItemId}
              onChange={(val) => setLineItemId(val as string)}
              options={[{ id: "", label: "— غير محدد —" }, ...lineItems.map((li) => ({ id: li.id, label: li.name }))]}
              placeholder="اختر البند"
              width="100%"
            />
          </FormField>
        )}
        <FormField label="الوصف" icon={FileText}>
          <input className="input" value={description} onChange={(e) => setDescription(e.target.value)} style={{ paddingRight: "40px" }} />
        </FormField>
        <FormField label="المبلغ (د.ك)" icon={DollarSign} required>
          <input type="number" className="input" min="0" step="0.01" value={amount} onChange={(e) => setAmount(e.target.value)} style={{ paddingRight: "40px" }} />
        </FormField>
        <FormField label="التاريخ" icon={Calendar} required>
          <input type="date" className="input" value={expenseDate} onChange={(e) => setExpenseDate(e.target.value)} style={{ paddingRight: "40px" }} />
        </FormField>
        <FormField label="طريقة الدفع" required>
          <CustomSelect
            value={paymentMethod}
            onChange={(val) => setPaymentMethod(val as string)}
            options={EXPENSE_PAYMENT_METHOD_OPTIONS}
            placeholder="اختر طريقة الدفع"
            width="100%"
          />
        </FormField>
        <FormField label="ملاحظة" icon={FileText}>
          <textarea className="input" rows={2} value={note} onChange={(e) => setNote(e.target.value)} style={{ paddingRight: "40px", resize: "vertical" }} />
        </FormField>
        <ModalActions submitting={submitting} isEdit={!!expense} onClose={onClose} />
      </form>
    </Modal>
  );
};

/* ─────────────────────────────────────────────────────
   Salary Section (unchanged behavior)
───────────────────────────────────────────────────── */
const SalaryExpenseSection = ({ expenses, section, workers, onChanged, notify }: {
  expenses: CompanyExpense[];
  section: ExpenseSection;
  workers: Worker[];
  onChanged: () => void;
  notify: (msg: string) => void;
}) => {
  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [editing, setEditing] = useState<CompanyExpense | null>(null);
  const [confirmDelete, setConfirmDelete] = useState<CompanyExpense | null>(null);
  const [deleting, setDeleting] = useState(false);
  const [bulkPaying, setBulkPaying] = useState(false);
  const [isBulkPayModalOpen, setIsBulkPayModalOpen] = useState(false);
  const repo = container.adminRepository;

  const handleCreate = async (data: any) => {
    try {
      await repo.createCompanyExpense({ ...data, sectionId: section.id, category: "salary" });
      notify("تم إضافة الراتب");
      setIsCreateOpen(false);
      onChanged();
    } catch (e: any) { notify("فشل الإضافة: " + (e?.message || "")); }
  };

  const handleUpdate = async (data: any) => {
    try {
      await repo.updateCompanyExpense(data);
      notify("تم تحديث الراتب");
      setEditing(null);
      onChanged();
    } catch (e: any) { notify("فشل التحديث: " + (e?.message || "")); }
  };

  const handleDelete = async () => {
    if (!confirmDelete) return;
    setDeleting(true);
    try {
      await repo.deleteCompanyExpense(confirmDelete.id);
      notify("تم حذف المصروف");
      setConfirmDelete(null);
      onChanged();
    } catch (e: any) { notify("فشل الحذف: " + (e?.message || "")); }
    finally { setDeleting(false); }
  };

  const handleBulkPay = async (paymentMethod: PaymentMethod) => {
    setBulkPaying(true);
    try {
      const created = await repo.bulkPaySalaries(currentMonth(), paymentMethod);
      notify(created.length === 0 ? "جميع الرواتب مدفوعة بالفعل" : `تم تنزيل ${created.length} راتب`);
      setIsBulkPayModalOpen(false);
      onChanged();
    } catch (e: any) { notify("فشل تنزيل المرتبات: " + (e?.message || "")); }
    finally { setBulkPaying(false); }
  };

  return (
    <SectionCard
      title="رواتب العمالة"
      icon={HardHat}
      onAdd={() => setIsCreateOpen(true)}
      addLabel="إضافة راتب"
      extraAction={
        <button className="button secondary" onClick={() => setIsBulkPayModalOpen(true)} disabled={bulkPaying}>
          {bulkPaying ? <Loader2 size={18} className="spin" /> : <Banknote size={18} />}
          {bulkPaying ? "جار التنزيل..." : "تنزيل كل المرتبات"}
        </button>
      }
    >
      <table className="table ca-table" style={{ margin: 0, width: "100%" }}>
        <thead>
          <tr>
            <Th>الاسم</Th><Th>الوصف</Th><Th>المبلغ</Th><Th>التاريخ</Th><Th>ملاحظة</Th><Th center>الإجراءات</Th>
          </tr>
        </thead>
        <tbody>
          {expenses.length === 0 && (
            <tr><td colSpan={6} style={{ textAlign: "center", padding: "32px", color: "#b0b8ae" }}>لا توجد رواتب هذا الشهر</td></tr>
          )}
          {expenses.map((e) => (
            <tr key={e.id} style={{ background: "white", borderBottom: "1px solid #f5f3ef" }}>
              <td style={{ padding: "14px", fontWeight: 700, color: "#1a2a10" }}>{e.name}</td>
              <td style={{ padding: "14px", color: "#7c857a" }}>{e.description || "—"}</td>
              <td style={{ padding: "14px", fontWeight: 700 }}>{formatMoney(e.amount)}</td>
              <td style={{ padding: "14px", color: "#7c857a" }}>{formatDate(e.expenseDate)}</td>
              <td style={{ padding: "14px", color: "#7c857a" }}>{e.note || "—"}</td>
              <td style={{ textAlign: "center", padding: "14px" }}>
                <RowActions onEdit={() => setEditing(e)} onDelete={() => setConfirmDelete(e)} />
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      {isCreateOpen && <SalaryExpenseModal title="إضافة راتب" workers={workers} onClose={() => setIsCreateOpen(false)} onSubmit={handleCreate} />}
      {editing && <SalaryExpenseModal title="تعديل راتب" workers={workers} expense={editing} onClose={() => setEditing(null)} onSubmit={handleUpdate} />}
      {confirmDelete && <ConfirmDeleteModal name={confirmDelete.name} loading={deleting} onConfirm={handleDelete} onClose={() => !deleting && setConfirmDelete(null)} />}
      {isBulkPayModalOpen && (
        <BulkPaySalariesModal
          loading={bulkPaying}
          onConfirm={handleBulkPay}
          onClose={() => !bulkPaying && setIsBulkPayModalOpen(false)}
        />
      )}
    </SectionCard>
  );
};

const BulkPaySalariesModal = ({ loading, onConfirm, onClose }: {
  loading: boolean; onConfirm: (paymentMethod: PaymentMethod) => void; onClose: () => void;
}) => {
  const [paymentMethod, setPaymentMethod] = useState("");
  return (
    <Modal title="تنزيل كل المرتبات" onClose={onClose}>
      <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
        <p style={{ margin: 0, color: "#7c857a", lineHeight: "1.6" }}>
          سيتم تنزيل رواتب جميع العمال غير المدفوعين لهذا الشهر. اختر طريقة الدفع لكل الدفعات:
        </p>
        <FormField label="طريقة الدفع" required>
          <CustomSelect value={paymentMethod} onChange={setPaymentMethod} options={EXPENSE_PAYMENT_METHOD_OPTIONS} placeholder="اختر طريقة الدفع" width="100%" />
        </FormField>
        <div style={{ display: "flex", gap: "12px", borderTop: "1px solid #f5f3ef", paddingTop: "16px" }}>
          <button className="button" style={{ flex: 1, justifyContent: "center" }} disabled={!paymentMethod || loading} onClick={() => onConfirm(paymentMethod as PaymentMethod)}>
            {loading ? <Loader2 size={18} className="spin" /> : <Banknote size={18} />}
            {loading ? "جار التنزيل..." : "تأكيد وتنزيل"}
          </button>
          <button className="button secondary" onClick={onClose} disabled={loading}>إلغاء</button>
        </div>
      </div>
    </Modal>
  );
};

const FeeAmountModal = ({ currentAmount, onClose, onSaved, notify }: {
  currentAmount: number; onClose: () => void; onSaved: (newAmount: number) => void; notify: (msg: string) => void;
}) => {
  const [amount, setAmount] = useState(currentAmount.toString());
  const [submitting, setSubmitting] = useState(false);
  const repo = container.adminRepository;

  const handleSave = async () => {
    const value = Number(amount);
    if (!amount || isNaN(value) || value < 0) return;
    setSubmitting(true);
    try {
      await repo.updateUpaymentsFeeAmount(value);
      notify("تم تحديث قيمة العمولة");
      onSaved(value);
    } catch (e: any) {
      notify("فشل تحديث القيمة: " + (e?.message || ""));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <Modal title="تعديل قيمة عمولة UPayments" onClose={onClose}>
      <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
        <p style={{ margin: 0, color: "#7c857a", lineHeight: "1.6" }}>
          قيمة عمولة UPayments مبلغ ثابت لكل دفعة (محاسبية فقط، لا تُخصم من مبلغ الدفع)، وتُطبق على أي دفعة إلكترونية جديدة فور الحفظ.
        </p>
        <FormField label="قيمة العمولة الثابتة (د.ك)" icon={DollarSign} required>
          <input type="number" className="input" min="0" step="0.001" value={amount} onChange={(e) => setAmount(e.target.value)} style={{ paddingRight: "40px" }} />
        </FormField>
        <div style={{ display: "flex", gap: "12px", borderTop: "1px solid #f5f3ef", paddingTop: "16px" }}>
          <button className="button" style={{ flex: 1, justifyContent: "center" }} disabled={submitting} onClick={handleSave}>
            {submitting ? <Loader2 size={18} className="spin" /> : <Save size={18} />}
            {submitting ? "جار الحفظ..." : "حفظ"}
          </button>
          <button className="button secondary" onClick={onClose} disabled={submitting}>إلغاء</button>
        </div>
      </div>
    </Modal>
  );
};

const SandboxModeModal = ({ currentSandbox, onClose, onSaved, notify }: {
  currentSandbox: boolean; onClose: () => void; onSaved: (newSandbox: boolean) => void; notify: (msg: string) => void;
}) => {
  const [submitting, setSubmitting] = useState(false);
  const repo = container.adminRepository;
  const targetSandbox = !currentSandbox;

  const handleSave = async () => {
    setSubmitting(true);
    try {
      await repo.updateUpaymentsSandboxMode(targetSandbox);
      notify(targetSandbox ? "تم تحويل بوابة الدفع إلى الوضع التجريبي" : "تم تحويل بوابة الدفع إلى الوضع الفعلي (Production)");
      onSaved(targetSandbox);
    } catch (e: any) {
      notify("فشل تحويل وضع البوابة: " + (e?.message || ""));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <Modal title="تعديل وضع بوابة الدفع" onClose={onClose}>
      <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
        <p style={{ margin: 0, color: "#7c857a", lineHeight: "1.6" }}>
          الوضع الحالي: <b>{currentSandbox ? "تجريبي (Sandbox)" : "فعلي (Production)"}</b>.
        </p>
        {targetSandbox ? (
          <p style={{ margin: 0, color: "#7c857a", lineHeight: "1.6" }}>
            سيتم التحويل إلى الوضع التجريبي — لن يتم تحصيل أي مبالغ حقيقية من العملاء.
          </p>
        ) : (
          <div style={{ display: "flex", gap: "10px", alignItems: "flex-start", background: "#fef3e8", border: "1px solid #f5c98f", borderRadius: "8px", padding: "12px 14px" }}>
            <AlertCircle size={18} color="#d97706" style={{ flexShrink: 0, marginTop: "2px" }} />
            <p style={{ margin: 0, color: "#92400e", lineHeight: "1.6", fontSize: "0.9rem" }}>
              سيتم التحويل إلى الوضع الفعلي — أي دفعة جديدة عبر الرابط سيتم تحصيلها فعليًا من بطاقة/حساب العميل.
              تأكد أن التوكن الحقيقي لـ UPayments مضبوط في الـ Supabase secrets قبل التأكيد.
            </p>
          </div>
        )}
        <div style={{ display: "flex", gap: "12px", borderTop: "1px solid #f5f3ef", paddingTop: "16px" }}>
          <button className="button" style={{ flex: 1, justifyContent: "center" }} disabled={submitting} onClick={handleSave}>
            {submitting ? <Loader2 size={18} className="spin" /> : <Save size={18} />}
            {submitting ? "جار الحفظ..." : `تحويل إلى ${targetSandbox ? "تجريبي" : "فعلي"}`}
          </button>
          <button className="button secondary" onClick={onClose} disabled={submitting}>إلغاء</button>
        </div>
      </div>
    </Modal>
  );
};

const GATEWAY_SRC_OPTIONS: { id: string; label: string }[] = [
  { id: "cc", label: "بطاقة ائتمان (CC)" },
  { id: "knet", label: "كي نت (KNET)" },
];

const PaymentCredentialsModal = ({ onClose, onSaved, notify }: {
  onClose: () => void; onSaved: () => void; notify: (msg: string) => void;
}) => {
  const [provider] = useState("upayments");
  const [apiToken, setApiToken] = useState("");
  const [nwlToken, setNwlToken] = useState("");
  const [gatewaySrc, setGatewaySrc] = useState("cc");
  const [webhookSecret, setWebhookSecret] = useState("");
  const [returnUrl, setReturnUrl] = useState("");
  const [cancelUrl, setCancelUrl] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const repo = container.adminRepository;

  const handleSave = async () => {
    if (!apiToken.trim()) {
      notify("توكن الـ API مطلوب");
      return;
    }
    setSubmitting(true);
    try {
      await repo.setTenantPaymentCredentials({
        apiToken: apiToken.trim(),
        nwlToken: nwlToken.trim(),
        gatewaySrc,
        webhookSecret: webhookSecret.trim(),
        returnUrl: returnUrl.trim(),
        cancelUrl: cancelUrl.trim(),
      });
      notify("تم حفظ بيانات بوابة الدفع");
      onSaved();
    } catch (e: any) {
      notify("فشل حفظ بيانات البوابة: " + (e?.message || ""));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <Modal title="بيانات بوابة الدفع الخاصة بالشركة" onClose={onClose}>
      <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
        <p style={{ margin: 0, color: "#7c857a", lineHeight: "1.6" }}>
          البيانات دي بتخلي دفعات عملاء شركتك تروح لحساب UPayments بتاعك إنت، بدل الحساب الافتراضي
          المشترك. القيم بعد الحفظ متخزنة بشكل مشفّر ومحدش (حتى الداشبورد) بيقدر يعرضها تاني —
          هتحتاج تدخلها من جديد لو عايز تغيّرها.
        </p>

        <FormField label="بوابة الدفع" required>
          <select className="input" value={provider} disabled style={{ paddingRight: "12px" }}>
            <option value="upayments">UPayments</option>
          </select>
        </FormField>

        <FormField label="API Token" icon={KeyRound} required>
          <input
            type="password" autoComplete="off" className="input" placeholder="أدخل توكن UPayments"
            value={apiToken} onChange={(e) => setApiToken(e.target.value)} style={{ paddingRight: "40px" }}
          />
        </FormField>

        <FormField label="White-label Token (اختياري)" icon={KeyRound}>
          <input
            type="password" autoComplete="off" className="input" placeholder="لو مختلف عن API Token"
            value={nwlToken} onChange={(e) => setNwlToken(e.target.value)} style={{ paddingRight: "40px" }}
          />
        </FormField>

        <FormField label="Webhook Secret" icon={KeyRound} required>
          <input
            type="password" autoComplete="off" className="input" placeholder="سر توقيع الـ webhook"
            value={webhookSecret} onChange={(e) => setWebhookSecret(e.target.value)} style={{ paddingRight: "40px" }}
          />
        </FormField>

        <FormField label="طريقة الدفع الافتراضية" required>
          <CustomSelect
            options={GATEWAY_SRC_OPTIONS}
            value={gatewaySrc}
            onChange={setGatewaySrc}
          />
        </FormField>

        <FormField label="Return URL" icon={Link2}>
          <input
            type="text" className="input" placeholder="رابط الرجوع بعد الدفع الناجح"
            value={returnUrl} onChange={(e) => setReturnUrl(e.target.value)} style={{ paddingRight: "40px" }}
          />
        </FormField>

        <FormField label="Cancel URL" icon={Link2}>
          <input
            type="text" className="input" placeholder="رابط الرجوع عند الإلغاء"
            value={cancelUrl} onChange={(e) => setCancelUrl(e.target.value)} style={{ paddingRight: "40px" }}
          />
        </FormField>

        <div style={{ display: "flex", gap: "12px", borderTop: "1px solid #f5f3ef", paddingTop: "16px" }}>
          <button className="button" style={{ flex: 1, justifyContent: "center" }} disabled={submitting} onClick={handleSave}>
            {submitting ? <Loader2 size={18} className="spin" /> : <Save size={18} />}
            {submitting ? "جار الحفظ..." : "حفظ"}
          </button>
          <button className="button secondary" onClick={onClose} disabled={submitting}>إلغاء</button>
        </div>
      </div>
    </Modal>
  );
};

const SalaryExpenseModal = ({ title, workers, expense, onClose, onSubmit }: {
  title: string; workers: Worker[]; expense?: CompanyExpense; onClose: () => void; onSubmit: (data: any) => void;
}) => {
  const [workerId, setWorkerId] = useState(expense?.workerId || "");
  const [name, setName] = useState(expense?.name || "");
  const [description, setDescription] = useState(expense?.description || "");
  const [amount, setAmount] = useState(expense?.amount?.toString() || "");
  const [expenseDate, setExpenseDate] = useState(expense?.expenseDate || new Date().toISOString().slice(0, 10));
  const [note, setNote] = useState(expense?.note || "");
  const [paymentMethod, setPaymentMethod] = useState<string>(expense?.paymentMethod || "");
  const [submitting, setSubmitting] = useState(false);

  const handleWorkerChange = (id: string) => {
    setWorkerId(id);
    const worker = workers.find((w) => w.id === id);
    if (worker) { setName(worker.name); setAmount(worker.salary.toString()); }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim() || !amount || !expenseDate || !paymentMethod) return;
    setSubmitting(true);
    await onSubmit({
      ...(expense ? { id: expense.id } : {}),
      name: name.trim(), description: description.trim() || null,
      amount: Number(amount), expenseDate,
      note: note.trim() || null, workerId: workerId || null,
      paymentMethod: paymentMethod as PaymentMethod,
    });
    setSubmitting(false);
  };

  return (
    <Modal title={title} onClose={onClose}>
      <form onSubmit={handleSubmit} style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
        <FormField label="العامل (اختياري)">
          <CustomSelect
            value={workerId}
            onChange={(val) => handleWorkerChange(val as string)}
            options={[{ id: "", label: "-- بدون ربط بعامل --" }, ...workers.map((w) => ({ id: w.id, label: `${w.name} (${w.salary.toLocaleString()} د.ك)` }))]}
            placeholder="اختر العامل" width="100%" searchable
          />
        </FormField>
        <FormField label="الاسم" icon={HardHat} required>
          <input className="input" value={name} onChange={(e) => setName(e.target.value)} style={{ paddingRight: "40px" }} />
        </FormField>
        <FormField label="الوصف" icon={FileText}>
          <input className="input" value={description} onChange={(e) => setDescription(e.target.value)} style={{ paddingRight: "40px" }} />
        </FormField>
        <FormField label="المبلغ (د.ك)" icon={DollarSign} required>
          <input type="number" className="input" min="0" step="0.01" value={amount} onChange={(e) => setAmount(e.target.value)} style={{ paddingRight: "40px" }} />
        </FormField>
        <FormField label="التاريخ" icon={Calendar} required>
          <input type="date" className="input" value={expenseDate} onChange={(e) => setExpenseDate(e.target.value)} style={{ paddingRight: "40px" }} />
        </FormField>
        <FormField label="طريقة الدفع" required>
          <CustomSelect
            value={paymentMethod}
            onChange={(val) => setPaymentMethod(val)}
            options={EXPENSE_PAYMENT_METHOD_OPTIONS}
            placeholder="اختر طريقة الدفع"
            width="100%"
          />
        </FormField>
        <FormField label="ملاحظة" icon={FileText}>
          <textarea className="input" rows={2} value={note} onChange={(e) => setNote(e.target.value)} style={{ paddingRight: "40px", resize: "vertical" }} />
        </FormField>
        <ModalActions submitting={submitting} isEdit={!!expense} onClose={onClose} />
      </form>
    </Modal>
  );
};

/* ─────────────────────────────────────────────────────
   Vehicle Expense Section — sidebar layout
───────────────────────────────────────────────────── */
const VehicleExpenseSection = ({ expenses, vehicles, lineItems, section, onChanged, notify }: {
  expenses: VehicleExpense[];
  vehicles: Vehicle[];
  lineItems: ExpenseLineItem[];
  section: ExpenseSection;
  onChanged: () => void;
  notify: (msg: string) => void;
}) => {
  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [editing, setEditing] = useState<VehicleExpense | null>(null);
  const [confirmDeleteExpense, setConfirmDeleteExpense] = useState<VehicleExpense | null>(null);
  const [deletingExpense, setDeletingExpense] = useState(false);

  const [activeLineItemId, setActiveLineItemId] = useState<string | null>(null);
  const [isAddingLineItem, setIsAddingLineItem] = useState(false);
  const [editingLineItem, setEditingLineItem] = useState<ExpenseLineItem | null>(null);
  const [confirmDeleteLineItem, setConfirmDeleteLineItem] = useState<ExpenseLineItem | null>(null);

  const fleetRepo  = container.fleetRepository;
  const adminRepo  = container.adminRepository;

  const vehicleLabel = (id: string) => vehicles.find((v) => v.id === id)?.plateNumber ?? "—";

  useEffect(() => {
    if (activeLineItemId && !lineItems.find(li => li.id === activeLineItemId)) {
      setActiveLineItemId(null);
    }
  }, [lineItems]);

  /* ── Expense handlers ── */
  const handleCreate = async (data: any) => {
    try {
      await fleetRepo.createExpense(data);
      notify("تم إضافة المصروف");
      setIsCreateOpen(false);
      onChanged();
    } catch (e: any) { notify("فشل الإضافة: " + (e?.message || "")); }
  };

  const handleUpdate = async (data: any) => {
    try {
      await fleetRepo.updateExpense(data);
      notify("تم التحديث");
      setEditing(null);
      onChanged();
    } catch (e: any) { notify("فشل التحديث: " + (e?.message || "")); }
  };

  const handleDeleteExpense = async () => {
    if (!confirmDeleteExpense) return;
    setDeletingExpense(true);
    try {
      await fleetRepo.deleteExpense(confirmDeleteExpense.id);
      notify("تم الحذف");
      setConfirmDeleteExpense(null);
      onChanged();
    } catch (e: any) { notify("فشل الحذف: " + (e?.message || "")); }
    finally { setDeletingExpense(false); }
  };

  /* ── Line item handlers ── */
  const handleAddLineItem = async (name: string) => {
    try {
      await adminRepo.createExpenseLineItem({ sectionId: section.id, name });
      notify("تم إضافة البند");
      setIsAddingLineItem(false);
      onChanged();
    } catch (e: any) { notify("فشل إضافة البند: " + (e?.message || "")); }
  };

  const handleUpdateLineItem = async (name: string) => {
    if (!editingLineItem) return;
    try {
      await adminRepo.updateExpenseLineItem({ id: editingLineItem.id, name });
      notify("تم تحديث البند");
      setEditingLineItem(null);
      onChanged();
    } catch (e: any) { notify("فشل التحديث: " + (e?.message || "")); }
  };

  const handleDeleteLineItem = async () => {
    if (!confirmDeleteLineItem) return;
    try {
      await adminRepo.deleteExpenseLineItem(confirmDeleteLineItem.id);
      notify("تم حذف البند");
      if (activeLineItemId === confirmDeleteLineItem.id) setActiveLineItemId(null);
      setConfirmDeleteLineItem(null);
      onChanged();
    } catch (e: any) { notify("فشل الحذف: " + (e?.message || "")); }
  };

  /* ── Derived data ── */
  const filteredExpenses = activeLineItemId === null
    ? expenses
    : expenses.filter(e => e.lineItemId === activeLineItemId);

  const liTotals: Record<string, number> = {};
  expenses.forEach(e => {
    if (e.lineItemId) liTotals[e.lineItemId] = (liTotals[e.lineItemId] || 0) + e.amount;
  });

  const showBandCol = activeLineItemId === null && lineItems.length > 0;

  return (
    <div className="card ca-section" style={{ padding: 0, overflow: "hidden", border: "1px solid #e4e0d8" }}>
      {/* Header */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "14px 16px", borderBottom: "1px solid #f5f3ef", flexWrap: "wrap", gap: "10px" }}>
        <h3 style={{ margin: 0, display: "flex", alignItems: "center", gap: "10px", fontSize: "1.05rem", color: "#1a2a10", fontWeight: 700 }}>
          <Car size={20} color="var(--primary)" />
          مصاريف السيارات
          <span style={{ fontSize: "0.8rem", fontWeight: 600, color: "#9ca89a" }}>
            ({formatMoney(sum(expenses))})
          </span>
        </h3>
        <button className="button" onClick={() => setIsCreateOpen(true)}>
          <Plus size={18} /> إضافة
        </button>
      </div>

      {/* Split body */}
      <div className="ca-section-split">

        {/* ── Line items sidebar ── */}
        <div className="ca-li-sidebar">
          <div
            className={`ca-li-item ${activeLineItemId === null ? "active" : ""}`}
            onClick={() => setActiveLineItemId(null)}
          >
            <Scale size={13} color="#9ca89a" style={{ flexShrink: 0 }} />
            <span className="ca-li-item-name">الإجمالي</span>
            <span className="ca-li-item-total">{formatMoney(sum(expenses))}</span>
          </div>

          {lineItems.map(li => (
            <div
              key={li.id}
              className={`ca-li-item ${activeLineItemId === li.id ? "active" : ""}`}
              onClick={() => setActiveLineItemId(li.id)}
            >
              <Tag size={12} color="#9ca89a" style={{ flexShrink: 0 }} />
              <span className="ca-li-item-name">{li.name}</span>
              <span className="ca-li-item-total">{formatMoney(liTotals[li.id] ?? 0)}</span>
              <div className="ca-li-item-actions" onClick={e => e.stopPropagation()}>
                <button className="icon-button" title="تعديل" onClick={() => setEditingLineItem(li)}><Pencil size={12} /></button>
                <button className="icon-button" title="حذف" style={{ color: "#ef4444" }} onClick={() => setConfirmDeleteLineItem(li)}><Trash2 size={12} /></button>
              </div>
            </div>
          ))}

          {lineItems.length === 0 && !isAddingLineItem && (
            <div style={{ padding: "14px 13px", fontSize: "0.78rem", color: "#b0b8ae", textAlign: "center" }}>لا توجد بنود</div>
          )}

          <div className="ca-li-sidebar-footer">
            {isAddingLineItem ? (
              <InlineNameInput placeholder="اسم البند" onSubmit={handleAddLineItem} onCancel={() => setIsAddingLineItem(false)} />
            ) : (
              <button className="ca-li-add-btn" onClick={() => setIsAddingLineItem(true)}>
                <Plus size={13} /> إضافة بند
              </button>
            )}
          </div>
        </div>

        {/* ── Content ── */}
        <div className="ca-section-content">
          {filteredExpenses.length === 0 ? (
            <div className="ca-section-empty">
              <Car size={28} style={{ opacity: 0.25 }} />
              <span>{lineItems.length === 0 ? "أضف بندًا من القائمة الجانبية ثم أضف مصاريف" : "لا توجد مصاريف لهذا البند"}</span>
            </div>
          ) : (
            <table className="table ca-table" style={{ margin: 0, width: "100%" }}>
              <thead>
                <tr>
                  {showBandCol && <Th>البند</Th>}
                  <Th>السيارة</Th>
                  <Th>الوصف</Th>
                  <Th>المبلغ</Th>
                  <Th>التاريخ</Th>
                  <Th center>الإجراءات</Th>
                </tr>
              </thead>
              <tbody>
                {filteredExpenses.map(e => (
                  <tr key={e.id} style={{ background: "white", borderBottom: "1px solid #f5f3ef" }}>
                    {showBandCol && (
                      <td style={{ padding: "12px 14px" }}>
                        {e.lineItemId ? (
                          <span style={{ fontSize: "0.78rem", background: "#eef3e8", padding: "2px 8px", borderRadius: "20px", color: "#3a6e2a", fontWeight: 600 }}>
                            {lineItems.find(li => li.id === e.lineItemId)?.name ?? "—"}
                          </span>
                        ) : <span style={{ color: "#b0b8ae", fontSize: "0.8rem" }}>—</span>}
                      </td>
                    )}
                    <td style={{ padding: "12px 14px", fontWeight: 700, color: "#1a2a10" }}>{vehicleLabel(e.vehicleId)}</td>
                    <td style={{ padding: "12px 14px", color: "#7c857a" }}>{e.description || "—"}</td>
                    <td style={{ padding: "12px 14px", fontWeight: 700 }}>{formatMoney(e.amount)}</td>
                    <td style={{ padding: "12px 14px", color: "#7c857a" }}>{formatDate(e.expenseDate)}</td>
                    <td style={{ textAlign: "center", padding: "12px 14px" }}>
                      <RowActions onEdit={() => setEditing(e)} onDelete={() => setConfirmDeleteExpense(e)} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>

      {/* Expense modals */}
      {isCreateOpen && (
        <VehicleExpenseModal
          title="إضافة مصروف سيارة"
          vehicles={vehicles}
          lineItems={lineItems}
          defaultLineItemId={activeLineItemId ?? ""}
          onClose={() => setIsCreateOpen(false)}
          onSubmit={handleCreate}
        />
      )}
      {editing && (
        <VehicleExpenseModal
          title="تعديل مصروف سيارة"
          vehicles={vehicles}
          lineItems={lineItems}
          expense={editing}
          onClose={() => setEditing(null)}
          onSubmit={handleUpdate}
        />
      )}
      {confirmDeleteExpense && (
        <ConfirmDeleteModal
          name={`مصروف بقيمة ${formatMoney(confirmDeleteExpense.amount)}`}
          loading={deletingExpense}
          onConfirm={handleDeleteExpense}
          onClose={() => !deletingExpense && setConfirmDeleteExpense(null)}
        />
      )}

      {/* Line item modals */}
      {editingLineItem && (
        <InlineModal title="تعديل البند" onClose={() => setEditingLineItem(null)}>
          <InlineNameForm defaultName={editingLineItem.name} onSubmit={handleUpdateLineItem} onCancel={() => setEditingLineItem(null)} submitLabel="حفظ" />
        </InlineModal>
      )}
      {confirmDeleteLineItem && (
        <ConfirmDeleteModal name={confirmDeleteLineItem.name} loading={false} onConfirm={handleDeleteLineItem} onClose={() => setConfirmDeleteLineItem(null)} />
      )}
    </div>
  );
};

const VehicleExpenseModal = ({ title, vehicles, lineItems, expense, defaultLineItemId, onClose, onSubmit }: {
  title: string; vehicles: Vehicle[]; lineItems: ExpenseLineItem[]; expense?: VehicleExpense; defaultLineItemId?: string; onClose: () => void; onSubmit: (data: any) => void;
}) => {
  const [vehicleId, setVehicleId] = useState(expense?.vehicleId || "");
  const [lineItemId, setLineItemId] = useState(expense?.lineItemId || defaultLineItemId || "");
  const [description, setDescription] = useState(expense?.description || "");
  const [amount, setAmount] = useState(expense?.amount?.toString() || "");
  const [expenseDate, setExpenseDate] = useState(expense?.expenseDate || new Date().toISOString().slice(0, 10));
  const [paymentMethod, setPaymentMethod] = useState<string>(expense?.paymentMethod || "");
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!vehicleId || !description.trim() || !amount || !expenseDate || !paymentMethod) return;
    setSubmitting(true);
    await onSubmit({
      ...(expense ? { id: expense.id } : {}),
      vehicleId, lineItemId: lineItemId || null,
      description: description.trim(), amount: Number(amount), expenseDate,
      paymentMethod: paymentMethod as PaymentMethod,
    });
    setSubmitting(false);
  };

  return (
    <Modal title={title} onClose={onClose}>
      <form onSubmit={handleSubmit} style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
        <FormField label="السيارة" required>
          <CustomSelect
            value={vehicleId}
            onChange={(val) => setVehicleId(val as string)}
            options={vehicles.map((v) => ({ id: v.id, label: v.plateNumber }))}
            placeholder="اختر السيارة" width="100%" searchable
          />
        </FormField>
        {lineItems.length > 0 && (
          <FormField label="البند">
            <CustomSelect
              value={lineItemId}
              onChange={(val) => setLineItemId(val as string)}
              options={[{ id: "", label: "— غير محدد —" }, ...lineItems.map((li) => ({ id: li.id, label: li.name }))]}
              placeholder="اختر البند (وقود، صيانة...)" width="100%"
            />
          </FormField>
        )}
        <FormField label="الوصف" icon={FileText} required>
          <input className="input" value={description} onChange={(e) => setDescription(e.target.value)} style={{ paddingRight: "40px" }} />
        </FormField>
        <FormField label="المبلغ (د.ك)" icon={DollarSign} required>
          <input type="number" className="input" min="0" step="0.01" value={amount} onChange={(e) => setAmount(e.target.value)} style={{ paddingRight: "40px" }} />
        </FormField>
        <FormField label="التاريخ" icon={Calendar} required>
          <input type="date" className="input" value={expenseDate} onChange={(e) => setExpenseDate(e.target.value)} style={{ paddingRight: "40px" }} />
        </FormField>
        <FormField label="طريقة الدفع" required>
          <CustomSelect
            value={paymentMethod}
            onChange={(val) => setPaymentMethod(val)}
            options={EXPENSE_PAYMENT_METHOD_OPTIONS}
            placeholder="اختر طريقة الدفع"
            width="100%"
          />
        </FormField>
        <ModalActions submitting={submitting} isEdit={!!expense} onClose={onClose} />
      </form>
    </Modal>
  );
};

/* ─────────────────────────────────────────────────────
   Revenue sections — view only (no edit / delete)
───────────────────────────────────────────────────── */
const ContractRevenueSection = ({ payments, contracts, clientUsers }: {
  payments: ContractPayment[]; contracts: Contract[]; clientUsers: User[];
}) => {
  const contractLabel = (id: string) => {
    const c = contracts.find((c) => c.id === id);
    if (!c) return "—";
    const clientName = clientUsers.find((u) => u.id === c.clientId)?.fullName ?? c.contractUserName ?? "—";
    return `${c.code} - ${clientName}`;
  };

  return (
    <SectionCard title="إيرادات العقود" icon={FileText}>
      <table className="table ca-table" style={{ margin: 0, width: "100%" }}>
        <thead><tr><Th>العقد</Th><Th>المبلغ</Th><Th>طريقة الدفع</Th><Th>التاريخ</Th><Th>ملاحظات</Th></tr></thead>
        <tbody>
          {payments.length === 0 && <tr><td colSpan={5} style={{ textAlign: "center", padding: "32px", color: "#b0b8ae" }}>لا توجد دفعات</td></tr>}
          {payments.map((p) => (
            <tr key={p.id} style={{ background: "white", borderBottom: "1px solid #f5f3ef" }}>
              <td style={{ padding: "14px", fontWeight: 700, color: "#1a2a10" }}>{contractLabel(p.contractId)}</td>
              <td style={{ padding: "14px", fontWeight: 700 }}>{formatMoney(p.amount)}</td>
              <td style={{ padding: "14px" }}>{paymentMethodLabel(p.paymentMethod)}</td>
              <td style={{ padding: "14px", color: "#7c857a" }}>{formatDate(p.paymentDate)}</td>
              <td style={{ padding: "14px", color: "#7c857a" }}>{p.notes || "—"}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </SectionCard>
  );
};

const TaskRevenueSection = ({ payments, tasks }: {
  payments: StandaloneTaskPayment[]; tasks: StandaloneTask[];
}) => {
  const taskLabel = (id: string) => tasks.find((t) => t.id === id)?.title ?? "—";

  return (
    <SectionCard title="إيرادات المهام المستقلة" icon={FileText}>
      <table className="table ca-table" style={{ margin: 0, width: "100%" }}>
        <thead><tr><Th>المهمة</Th><Th>المبلغ</Th><Th>طريقة الدفع</Th><Th>التاريخ</Th><Th>ملاحظات</Th></tr></thead>
        <tbody>
          {payments.length === 0 && <tr><td colSpan={5} style={{ textAlign: "center", padding: "32px", color: "#b0b8ae" }}>لا توجد دفعات</td></tr>}
          {payments.map((p) => (
            <tr key={p.id} style={{ background: "white", borderBottom: "1px solid #f5f3ef" }}>
              <td style={{ padding: "14px", fontWeight: 700, color: "#1a2a10" }}>{taskLabel(p.taskId)}</td>
              <td style={{ padding: "14px", fontWeight: 700 }}>{formatMoney(p.amount)}</td>
              <td style={{ padding: "14px" }}>{paymentMethodLabel(p.paymentMethod)}</td>
              <td style={{ padding: "14px", color: "#7c857a" }}>{formatDate(p.paymentDate)}</td>
              <td style={{ padding: "14px", color: "#7c857a" }}>{p.notes || "—"}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </SectionCard>
  );
};

/* ─────────────────────────────────────────────────────
   Shared UI Components
───────────────────────────────────────────────────── */
const SectionCard = ({ title, icon: Icon, onAdd, addLabel, extraAction, children }: {
  title: string; icon: any; onAdd?: () => void; addLabel?: string; extraAction?: React.ReactNode; children: React.ReactNode;
}) => (
  <div className="card ca-section" style={{ padding: 0, overflow: "hidden", border: "1px solid #e4e0d8" }}>
    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "14px 16px", borderBottom: "1px solid #f5f3ef", flexWrap: "wrap", gap: "12px" }}>
      <h3 style={{ margin: 0, display: "flex", alignItems: "center", gap: "10px", fontSize: "1.05rem", color: "#1a2a10", fontWeight: 700 }}>
        <Icon size={20} color="var(--primary)" />
        {title}
      </h3>
      <div style={{ display: "flex", gap: "8px", alignItems: "center", flexWrap: "wrap" }}>
        {extraAction}
        {onAdd && (
          <button className="button" onClick={onAdd}>
            <Plus size={18} /> {addLabel}
          </button>
        )}
      </div>
    </div>
    <div style={{ overflowX: "auto" }}>{children}</div>
  </div>
);

const RowActions = ({ onEdit, onDelete }: { onEdit: () => void; onDelete: () => void }) => (
  <div style={{ display: "flex", gap: "8px", justifyContent: "center" }}>
    <button className="icon-button" title="تعديل" onClick={onEdit}><Pencil size={18} /></button>
    <button className="icon-button" title="حذف" onClick={onDelete} style={{ color: "#ef4444" }}><Trash2 size={18} /></button>
  </div>
);

const ModalActions = ({ submitting, isEdit, onClose }: { submitting: boolean; isEdit: boolean; onClose: () => void }) => (
  <div style={{ display: "flex", gap: "12px", marginTop: "8px", borderTop: "1px solid #f5f3ef", paddingTop: "16px" }}>
    <button className="button" style={{ flex: 1, justifyContent: "center" }} type="submit" disabled={submitting}>
      {submitting ? <Loader2 size={18} className="spin" /> : isEdit ? <Save size={18} /> : <Plus size={18} />}
      {submitting ? "جار الحفظ..." : isEdit ? "حفظ التغييرات" : "إضافة"}
    </button>
    <button className="button secondary" type="button" onClick={onClose} disabled={submitting}>إلغاء</button>
  </div>
);

const Th = ({ children, center }: { children: React.ReactNode; center?: boolean }) => (
  <th style={{ padding: "12px 14px", color: "#7c857a", fontSize: "0.85rem", fontWeight: 700, borderBottom: "1px solid #e4e0d8", background: "#FBF9F5", textAlign: center ? "center" : undefined, whiteSpace: "nowrap" }}>{children}</th>
);

const Modal = ({ title, onClose, children }: { title: string; onClose: () => void; children: React.ReactNode }) => (
  <div className="ca-modal-overlay" style={{ position: "fixed", inset: 0, background: "rgba(0,0,0,0.5)", backdropFilter: "blur(4px)", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 100 }}>
    <div className="card ca-modal-card" style={{ width: "100%", maxWidth: "480px", maxHeight: "90vh", overflowY: "auto", padding: "24px" }}>
      <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "20px", alignItems: "center" }}>
        <h3 style={{ margin: 0, fontSize: "1.15rem", color: "#1a2a10" }}>{title}</h3>
        <button onClick={onClose} style={{ background: "#f5f3ef", border: "none", borderRadius: "8px", width: "32px", height: "32px", display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" }}>
          <X size={20} />
        </button>
      </div>
      {children}
    </div>
  </div>
);

const FormField = ({ label, icon: Icon, required, children }: { label: string; icon?: any; required?: boolean; children: React.ReactNode }) => (
  <label style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
    <span style={{ fontSize: "0.9rem", fontWeight: 600, color: "#2d3a2a" }}>
      {label} {required && <span style={{ color: "red" }}>*</span>}
    </span>
    <div style={{ position: "relative" }}>
      {Icon && <Icon size={18} style={{ position: "absolute", top: "10px", right: "12px", color: "#b0b8ae" }} />}
      {children}
    </div>
  </label>
);

const ConfirmDeleteModal = ({ name, loading, onConfirm, onClose }: {
  name: string; loading: boolean; onConfirm: () => void; onClose: () => void;
}) => (
  <Modal title="تأكيد الحذف" onClose={onClose}>
    <div style={{ display: "flex", flexDirection: "column", gap: "20px" }}>
      <p style={{ margin: 0, color: "#7c857a", lineHeight: "1.6" }}>
        هل أنت متأكد من حذف <strong style={{ color: "#1a2a10", margin: "0 4px" }}>{name}</strong>؟
      </p>
      <div style={{ display: "flex", gap: "12px", borderTop: "1px solid #f5f3ef", paddingTop: "16px" }}>
        <button className="button danger" onClick={onConfirm} disabled={loading} style={{ flex: 1, justifyContent: "center" }}>
          {loading ? <Loader2 size={18} className="spin" /> : <Trash2 size={18} />}
          {loading ? "جار الحذف..." : "تأكيد الحذف"}
        </button>
        <button className="button secondary" onClick={onClose} disabled={loading}>إلغاء</button>
      </div>
    </div>
  </Modal>
);

/* Destructive delete — user must type the exact section name */
const DestructiveDeleteModal = ({ title, description, confirmWord, onConfirm, onClose }: {
  title: string; description: string; confirmWord: string; onConfirm: () => void; onClose: () => void;
}) => {
  const [typed, setTyped] = useState("");
  const [loading, setLoading] = useState(false);
  const matches = typed.trim() === confirmWord.trim();

  const handleConfirm = async () => {
    if (!matches) return;
    setLoading(true);
    await onConfirm();
    setLoading(false);
  };

  return (
    <div style={{ position: "fixed", inset: 0, background: "rgba(0,0,0,0.65)", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 300 }}>
      <div className="card" style={{ width: "100%", maxWidth: "440px", padding: "28px" }}>
        <div style={{ display: "flex", alignItems: "center", gap: "10px", marginBottom: "16px" }}>
          <div style={{ width: "36px", height: "36px", background: "#fee2e2", borderRadius: "8px", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
            <Trash2 size={18} color="#dc2626" />
          </div>
          <h3 style={{ margin: 0, fontSize: "1.05rem", color: "#1a2a10" }}>{title}</h3>
        </div>
        <p style={{ margin: "0 0 16px", color: "#5a6a58", fontSize: "0.88rem", lineHeight: "1.6" }}>{description}</p>
        <div style={{ background: "#fff7f7", border: "1px solid #fecaca", borderRadius: "8px", padding: "12px 14px", marginBottom: "16px" }}>
          <p style={{ margin: "0 0 8px", fontSize: "0.82rem", color: "#b91c1c", fontWeight: 600 }}>
            اكتب اسم القسم للتأكيد:
            <strong style={{ margin: "0 4px", fontFamily: "monospace", fontSize: "0.9rem" }}>{confirmWord}</strong>
          </p>
          <input
            className="input"
            value={typed}
            onChange={(e) => setTyped(e.target.value)}
            placeholder={confirmWord}
            style={{ borderColor: matches ? "#16a34a" : typed ? "#f87171" : undefined }}
            autoFocus
          />
        </div>
        <div style={{ display: "flex", gap: "10px" }}>
          <button
            className="button danger"
            style={{ flex: 1, justifyContent: "center", opacity: matches ? 1 : 0.5 }}
            onClick={handleConfirm}
            disabled={!matches || loading}
          >
            {loading ? <Loader2 size={18} className="spin" /> : <Trash2 size={18} />}
            {loading ? "جار الحذف..." : "حذف نهائي"}
          </button>
          <button className="button secondary" onClick={onClose} disabled={loading}>إلغاء</button>
        </div>
      </div>
    </div>
  );
};
