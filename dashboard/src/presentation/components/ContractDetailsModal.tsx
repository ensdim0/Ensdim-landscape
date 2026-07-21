import React, { useEffect, useState, useRef, useCallback, useMemo } from "react";
import {
  FileText,
  X,
  LayoutList,
  Calendar,
  Clock,
  User as UserIcon,
  MapPin,
  ImageIcon,
  ClipboardList,
  Truck,
  CheckSquare,
  Check,
  ChevronDown,
  ChevronLeft,
  Loader2,
  Camera,
  MessageCircle,
  DollarSign,
  Plus,
  Trash2,
  CreditCard,
  Upload,
  Eye,
  Pencil,
} from "lucide-react";
import { container } from "@infrastructure/di/container";
import { supabase } from "@infrastructure/supabase/client";
import { formatDate, formatTime, formatDateTime } from "@shared/utils/date";
import { ContractPayment, PaymentMethod } from "@domain/entities/ContractPayment";
import { SupervisorNote } from "@domain/entities/SupervisorNote";
import { User } from "@domain/entities/User";
import { compressImage } from "@shared/utils/imageCompression";
import { CustomSelect } from "@presentation/components/CustomSelect";
import { CONTRACT_STATUS_OPTIONS, getContractStatusLabel } from "@shared/contractStatus";
import { getVisitStatusStyle } from "@shared/visitStatus";
import { SupervisorNotesEditor } from "@presentation/components/SupervisorNotesEditor";
import { useToast } from "@presentation/components/ToastProvider";
import { CreateStandaloneTaskModal } from "@presentation/screens/admin/AssignTaskPage";
import { StandaloneTaskDetailsPage } from "@presentation/screens/admin/StandaloneTaskDetailsPage";
import { StandaloneTask } from "@domain/entities/StandaloneTask";

const Badge = ({
  children,
  variant = "default",
  className = "",
  style = {},
}: any) => {
  const styles: any = {
    default: { bg: "var(--neutral-100)", color: "var(--text-secondary)" },
    success: { bg: "var(--color-success-bg)", color: "var(--color-success)" },
    warning: { bg: "var(--color-warning-bg)", color: "var(--color-warning)" },
    error: { bg: "var(--color-error-bg)", color: "var(--color-error)" },
    info: { bg: "var(--color-info-bg)", color: "var(--color-info)" },
    primary: { bg: "var(--green-50)", color: "var(--color-primary)" },
  };
  const s = styles[variant] || styles.default;

  return (
    <span
      style={{
        backgroundColor: s.bg,
        color: s.color,
        padding: "4px 10px",
        borderRadius: "12px",
        fontSize: "0.75rem",
        fontWeight: 600,
        display: "inline-flex",
        alignItems: "center",
        gap: "6px",
        lineHeight: 1,
        whiteSpace: "nowrap",
        ...style,
        ...className,
      }}
    >
      {children}
    </span>
  );
};

export const STATUS_OPTIONS = CONTRACT_STATUS_OPTIONS.map((option) => ({
  ...option,
  bg: option.value === "active" ? "var(--green-100)" : option.value === "pending" ? "var(--orange-100)" : option.value === "expired" ? "var(--color-error-bg)" : "var(--neutral-100)",
  color: option.value === "active" ? "var(--green-700)" : option.value === "pending" ? "var(--orange-700)" : option.value === "expired" ? "var(--color-error)" : "var(--neutral-500)",
  dot: option.value === "active" ? "var(--green-500)" : option.value === "pending" ? "var(--orange-500)" : option.value === "expired" ? "var(--color-error)" : "var(--neutral-500)",
}));

export const StatusPicker = ({
  status,
  onChange,
}: {
  status: string;
  onChange: (s: string) => void;
}) => {
  const [open, setOpen] = useState(false);
  const [dropdownStyle, setDropdownStyle] = useState<React.CSSProperties>({});
  const btnRef = useRef<HTMLButtonElement>(null);
  const dropdownRef = useRef<HTMLDivElement>(null);
  const current = STATUS_OPTIONS.find((o) => o.value === status) ?? {
    value: status,
    label: getContractStatusLabel(status),
    bg: "var(--neutral-100)",
    color: "var(--neutral-600)",
    dot: "var(--neutral-400)",
  };

  const openDropdown = () => {
    if (!btnRef.current) return;
    const rect = btnRef.current.getBoundingClientRect();
    const dropdownWidth = 150;
    let left = rect.left + rect.width / 2 - dropdownWidth / 2;
    if (left + dropdownWidth > window.innerWidth - 8) left = window.innerWidth - dropdownWidth - 8;
    if (left < 8) left = 8;
    setDropdownStyle({
      position: "fixed",
      top: rect.bottom + 4,
      left,
      width: dropdownWidth,
      background: "var(--bg-card)",
      borderRadius: "var(--radius-md)",
      border: "1px solid var(--color-border)",
      boxShadow: "var(--shadow-md)",
      zIndex: 9999,
      padding: "4px",
    });
    setOpen(true);
  };

  useEffect(() => {
    if (!open) return;
    const handleClick = (e: MouseEvent) => {
      if (
        btnRef.current?.contains(e.target as Node) ||
        dropdownRef.current?.contains(e.target as Node)
      ) return;
      setOpen(false);
    };
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, [open]);

  return (
    <>
      <button
        ref={btnRef}
        onClick={openDropdown}
        style={{
          padding: "6px 12px",
          borderRadius: "20px",
          fontSize: "0.8rem",
          fontWeight: "600",
          background: current.bg,
          color: current.color,
          border: "none",
          cursor: "pointer",
          display: "flex",
          alignItems: "center",
          gap: "8px",
          transition: "opacity 0.2s",
          width: "100px",
          justifyContent: "center",
        }}
      >
        <span style={{ width: "8px", height: "8px", borderRadius: "50%", background: current.dot }} />
        {current.label}
      </button>
      {open && (
        <div ref={dropdownRef} style={dropdownStyle}>
          {STATUS_OPTIONS.map((opt) => (
            <button
              key={opt.value}
              onClick={() => { onChange(opt.value); setOpen(false); }}
              style={{
                width: "100%",
                display: "flex",
                alignItems: "center",
                gap: "10px",
                padding: "10px",
                border: "none",
                borderRadius: "var(--radius-sm)",
                background: status === opt.value ? "var(--neutral-50)" : "transparent",
                color: "var(--text-primary)",
                fontSize: "0.85rem",
                cursor: "pointer",
                textAlign: "right",
                transition: "background 0.2s",
              }}
            >
              <span style={{ width: "8px", height: "8px", borderRadius: "50%", background: opt.dot }} />
              {opt.label}
            </button>
          ))}
        </div>
      )}
    </>
  );
};

const thStyle: React.CSSProperties = {
  padding: "12px 16px",
  textAlign: "right",
  color: "var(--text-tertiary)",
  fontSize: "0.85rem",
  fontWeight: 700,
  whiteSpace: "nowrap",
  borderBottom: "1px solid var(--color-border)",
};

const tdStyle: React.CSSProperties = {
  padding: "12px 16px",
  color: "var(--text-primary)",
  borderBottom: "1px solid var(--color-border)",
  verticalAlign: "middle",
};

export const ContractDetailsModal = ({
  contract,
  client,
  typeName,
  lineName,
  zoneName,
  initialVisitId,
  initialTab,
  onClose,
  onStatusChange,
  refreshContractDetails,
  onPaymentsChange,
}: any) => {
  const { notify } = useToast();
  const [activeTab, setActiveTab] = useState<"summary" | "visits" | "payments" | "tasks">(
    initialTab || (initialVisitId ? "visits" : "summary")
  );
  const [visits, setVisits] = useState<any[]>([]);
  const [loadingVisits, setLoadingVisits] = useState(false);
  const [expandedTerms, setExpandedTerms] = useState<Set<number>>(new Set());
  const [expandedVisits, setExpandedVisits] = useState<Set<string>>(
    initialVisitId ? new Set([initialVisitId]) : new Set()
  );
  const [visitExecutions, setVisitExecutions] = useState<Record<string, any[]>>({});
  const [visitPhotos, setVisitPhotos] = useState<Record<string, any[]>>({});
  const [visitLevelPhotos, setVisitLevelPhotos] = useState<Record<string, any[]>>({});
  const [comments, setComments] = useState<any[]>([]);
  const [loadingDetails, setLoadingDetails] = useState<Set<string>>(new Set());
  const [supervisorNotes, setSupervisorNotes] = useState<Record<string, SupervisorNote[]>>({});
  const [noteActionLoading, setNoteActionLoading] = useState<Record<string, boolean>>({});

  // Payments state
  const [payments, setPayments] = useState<ContractPayment[]>([]);
  const [loadingPayments, setLoadingPayments] = useState(false);
  const [showAddPayment, setShowAddPayment] = useState(false);
  const [paymentKind, setPaymentKind] = useState<"paid" | "scheduled">("paid");
  const [paymentAmount, setPaymentAmount] = useState("");
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethod | "">("");
  const [paymentDate, setPaymentDate] = useState(new Date().toISOString().split("T")[0]);
  const [paymentNotes, setPaymentNotes] = useState("");
  const [savingPayment, setSavingPayment] = useState(false);
  const [paymentImageFile, setPaymentImageFile] = useState<File | null>(null);
  const [viewingImage, setViewingImage] = useState<string | null>(null);
  // Scheduled payment due date (only used when paymentKind === "scheduled")
  const [scheduledDueDate, setScheduledDueDate] = useState("");
  const [sendingGatewayId, setSendingGatewayId] = useState<string | null>(null);
  const [confirmDeleteImage, setConfirmDeleteImage] = useState(false);
  // Convert a scheduled/unpaid payment into a manually-paid one
  const [convertingPaymentId, setConvertingPaymentId] = useState<string | null>(null);
  const [convertMethod, setConvertMethod] = useState<PaymentMethod | "">("");
  const [convertDate, setConvertDate] = useState(new Date().toISOString().split("T")[0]);
  const [convertNotes, setConvertNotes] = useState("");
  const [convertImageFile, setConvertImageFile] = useState<File | null>(null);
  const [convertingSaving, setConvertingSaving] = useState(false);
  // Edit the planned payment method of a scheduled/unpaid payment (before it's actually paid)
  const [editingMethodPaymentId, setEditingMethodPaymentId] = useState<string | null>(null);
  const [editMethodValue, setEditMethodValue] = useState<PaymentMethod | "">("");
  const [savingMethodEdit, setSavingMethodEdit] = useState(false);
  const convertFileRef = useRef<HTMLInputElement>(null);
  const [deletingImage, setDeletingImage] = useState(false);
  const paymentFileRef = useRef<HTMLInputElement>(null);
  const [standaloneTasks, setStandaloneTasks] = useState<StandaloneTask[]>([]);
  const [loadingStandaloneTasks, setLoadingStandaloneTasks] = useState(false);
  const [showCreateTask, setShowCreateTask] = useState(false);
  const [editingStandaloneTaskId, setEditingStandaloneTaskId] = useState<string | null>(null);
  const [viewingStandaloneTaskId, setViewingStandaloneTaskId] = useState<string | null>(null);
  const [deletingStandaloneTaskId, setDeletingStandaloneTaskId] = useState<string | null>(null);
  const [supervisors, setSupervisors] = useState<User[]>([]);

  const supervisorsMap = useMemo(() => {
    const m: Record<string, string> = {};
    supervisors.forEach((s) => (m[s.id] = s.fullName));
    return m;
  }, [supervisors]);

  const formatTimeDate = (iso?: string) => {
    if (!iso) return { time: "", date: "" };
    const normalized = iso.includes(" ") && !iso.includes("T") ? iso.replace(" ", "T") : iso;
    const isDateOnly = /^\d{4}-\d{2}-\d{2}$/.test(iso);
    const hasTime = /T\d{2}:\d{2}|\s\d{2}:\d{2}/.test(iso);
    const d = new Date(normalized);
    if (Number.isNaN(d.getTime())) return { time: "", date: iso };
    if (isDateOnly || !hasTime) {
      return { time: "", date: d.toLocaleDateString() };
    }
    const time = formatTime(d);
    const date = d.toLocaleDateString();
    return { time, date };
  };

  const formatShortTimestamp = (task: StandaloneTask) => {
    if (task.status === "completed" && task.updatedAt) {
      const { time, date } = formatTimeDate(task.updatedAt);
      return time ? `${time} • ${date}` : date;
    }
    if (!task.taskDate) return "";
    const { time, date } = formatTimeDate(task.taskDate);
    return time ? `${time} • ${date}` : date;
  };

  const renderTaskTimestamp = (task: StandaloneTask) => {
    if (task.status === "completed" && task.updatedAt) {
      const { time, date } = formatTimeDate(task.updatedAt);
      return (
        <div>
          {time ? <div style={{ fontWeight: 700 }}>{time}</div> : null}
          <div style={{ color: "var(--text-tertiary)", fontSize: "0.85rem" }}>{date}</div>
        </div>
      );
    }
    if (task.taskDate) {
      const { time, date } = formatTimeDate(task.taskDate);
      return (
        <div>
          {time ? <div style={{ fontWeight: 700 }}>{time}</div> : null}
          <div style={{ color: "var(--text-tertiary)", fontSize: "0.85rem" }}>{date}</div>
        </div>
      );
    }
    return <div style={{ color: "var(--text-tertiary)", fontSize: "0.95rem" }}>{task.taskDate}</div>;
  };

  const toggleTerm = (termIdx: number) => {
    setExpandedTerms((prev) => {
      const next = new Set(prev);
      if (next.has(termIdx)) {
        next.delete(termIdx);
      } else {
        next.add(termIdx);
      }
      return next;
    });
  };

  const toggleVisit = (visitId: string) => {
    setExpandedVisits((prev) => {
      const next = new Set(prev);
      if (next.has(visitId)) {
        next.delete(visitId);
      } else {
        next.add(visitId);
      }
      return next;
    });
  };

  useEffect(() => {
    let mounted = true;
    const load = async () => {
      try {
        const s = await container.adminRepository.listSupervisors();
        if (!mounted) return;
        setSupervisors(s);
      } catch (e) {
        console.error("Error loading supervisors:", e);
      }
    };
    load();
    return () => {
      mounted = false;
    };
  }, []);

  const getTaskStatusLabel = (status?: string) => {
    switch (status) {
      case "pending":
        return "قيد الانتظار";
      case "in_progress":
        return "جاري التنفيذ";
      case "completed":
        return "مكتملة";
      case "cancelled":
        return "ملغاة";
      default:
        return status || "—";
    }
  };

  const loadVisitDetails = useCallback(async (visit: any) => {
    if (visitExecutions[visit.id] && visitLevelPhotos[visit.id]) return;
    setLoadingDetails(prev => new Set(prev).add(visit.id));
    try {
      if (!visitLevelPhotos[visit.id]) {
        const directPhotos = await container.adminRepository.listVisitPhotos(visit.id);
        setVisitLevelPhotos(prev => ({ ...prev, [visit.id]: directPhotos }));
      }

      if (!visitExecutions[visit.id] && visit.tasks && visit.tasks.length > 0) {
        const taskIds = visit.tasks.map((t: any) => t.id);
        const executions = await container.adminRepository.listTaskExecutions(taskIds);
        setVisitExecutions(prev => ({ ...prev, [visit.id]: executions }));
        if (executions.length > 0) {
          const execIds = executions.map((e: any) => e.id);
          const photos = await container.adminRepository.listExecutionPhotos(execIds);
          setVisitPhotos(prev => ({ ...prev, [visit.id]: photos }));
        }
      }
    } catch (e) {
      console.error("Error loading visit details:", e);
    } finally {
      setLoadingDetails(prev => { const n = new Set(prev); n.delete(visit.id); return n; });
    }
  }, [visitExecutions, visitLevelPhotos]);

  const loadSupervisorNotes = useCallback(async (visitId: string) => {
    try {
      const notes = await container.supervisorRepository.listSupervisorNotes(visitId);
      setSupervisorNotes(prev => ({ ...prev, [visitId]: notes }));
    } catch (e) {
      console.error("Error loading supervisor notes:", e);
    }
  }, []);

  const handleAddNote = useCallback(async (visitId: string, content: string, visibility: "supervisors_only" | "all") => {
    if (!content.trim()) return;
    setNoteActionLoading(prev => ({ ...prev, [visitId]: true }));
    try {
      const note = await container.supervisorRepository.createSupervisorNote({
        visitId,
        contractId: contract.id,
        content,
        visibility,
      });
      setSupervisorNotes(prev => ({
        ...prev,
        [visitId]: [note, ...(prev[visitId] || [])],
      }));
    } catch (e) {
      console.error("Error adding supervisor note:", e);
      throw e;
    } finally {
      setNoteActionLoading(prev => ({ ...prev, [visitId]: false }));
    }
  }, [contract.id]);

  const handleUpdateNote = useCallback(async (visitId: string, noteId: string, content: string, visibility: "supervisors_only" | "all") => {
    if (!content.trim()) return;
    setNoteActionLoading(prev => ({ ...prev, [visitId]: true }));
    try {
      const note = await container.supervisorRepository.updateSupervisorNote({
        noteId,
        content,
        visibility,
      });
      setSupervisorNotes(prev => ({
        ...prev,
        [visitId]: (prev[visitId] || []).map(n => n.id === noteId ? note : n),
      }));
    } catch (e) {
      console.error("Error updating supervisor note:", e);
      throw e;
    } finally {
      setNoteActionLoading(prev => ({ ...prev, [visitId]: false }));
    }
  }, []);

  const handleDeleteNote = useCallback(async (visitId: string, noteId: string) => {
    setNoteActionLoading(prev => ({ ...prev, [visitId]: true }));
    try {
      await container.supervisorRepository.deleteSupervisorNote(noteId);
      setSupervisorNotes(prev => ({
        ...prev,
        [visitId]: (prev[visitId] || []).filter(n => n.id !== noteId),
      }));
    } catch (e) {
      console.error("Error deleting supervisor note:", e);
      throw e;
    } finally {
      setNoteActionLoading(prev => ({ ...prev, [visitId]: false }));
    }
  }, []);

  const getTermVisitGroups = useCallback(() => {
    // Build unique term labels in order (same logic as ContractVisitsManagerModal)
    const seen = new Set<string>();
    const termLabels: string[] = [];
    for (const term of contract.terms || []) {
      const label = (term.content || "").trim();
      if (!label || seen.has(label)) continue;
      seen.add(label);
      termLabels.push(label);
    }

    const usedVisitIds = new Set<string>();
    const groups: { term: any; termIndex: number; visits: any[] }[] = [];

    termLabels.forEach((label, ti) => {
      const matched = visits.filter((v) => {
        if (usedVisitIds.has(v.id)) return false;
        return (v.title || "").trim() === label;
      });
      matched.forEach((v) => usedVisitIds.add(v.id));
      groups.push({ term: { content: label }, termIndex: ti, visits: matched });
    });

    const unmatched = visits.filter((v) => !usedVisitIds.has(v.id));
    if (unmatched.length > 0) {
      groups.push({ term: { content: "زيارات بدون بند" }, termIndex: -1, visits: unmatched });
    }

    return groups;
  }, [contract.terms, visits]);

  useEffect(() => {
    if (activeTab === "visits") {
      setLoadingVisits(true);
      container.adminRepository
        .listVisits(contract.id)
        .then(async (vs) => {
          const visitsWithTasks = await Promise.all(
            vs.map(async (v) => {
              const tasks = await container.adminRepository.listVisitTasks(v.id);
              return { ...v, tasks };
            }),
          );
          setVisits(visitsWithTasks);
          try {
            const c = await container.adminRepository.listContractComments(contract.id);
            setComments(c);
          } catch {}
        })
        .catch(console.error)
        .finally(() => setLoadingVisits(false));
    }
  }, [activeTab, contract.id]);

  // When opened from a notification, auto-expand the term group that contains the target visit
  useEffect(() => {
    if (!initialVisitId || loadingVisits || visits.length === 0) return;
    const groups = getTermVisitGroups();
    const groupIdx = groups.findIndex((g) => g.visits.some((v: any) => v.id === initialVisitId));
    if (groupIdx !== -1) {
      setExpandedTerms((prev) => {
        const next = new Set(prev);
        next.add(groupIdx);
        return next;
      });
    }
    // scroll after a brief delay to allow the DOM to render the expanded group
    const timer = window.setTimeout(() => {
      const el = document.getElementById(`visit-row-${initialVisitId}`);
      if (el) el.scrollIntoView({ behavior: "smooth", block: "center" });
    }, 150);
    return () => window.clearTimeout(timer);
  }, [initialVisitId, loadingVisits, visits.length, getTermVisitGroups]);

  const loadStandaloneTasks = useCallback(async () => {
    setLoadingStandaloneTasks(true);
    try {
      const ts = await container.adminRepository.listStandaloneTasksByContract(contract.id);
      setStandaloneTasks(ts);
    } catch (e) {
      console.error(e);
      notify("تعذر تحميل المهام");
    } finally {
      setLoadingStandaloneTasks(false);
    }
  }, [contract.id, notify]);

  useEffect(() => {
    if (activeTab === "tasks") {
      loadStandaloneTasks();
    }
  }, [activeTab, loadStandaloneTasks]);

  const handleDeleteStandaloneTask = async (taskId: string) => {
    if (!window.confirm("هل تريد حذف هذه المهمة؟")) return;

    setDeletingStandaloneTaskId(taskId);
    try {
      await container.adminRepository.deleteStandaloneTask(taskId);
      setStandaloneTasks((prev) => prev.filter((task) => task.id !== taskId));
      notify("تم حذف المهمة");
    } catch (e) {
      console.error(e);
      notify("فشل حذف المهمة");
    } finally {
      setDeletingStandaloneTaskId(null);
    }
  };

  // Load payments
  const loadPayments = useCallback(async () => {
    setLoadingPayments(true);
    try {
      const data = await container.adminRepository.listContractPayments(contract.id);
      setPayments(data);
    } catch (e) {
      console.error("Error loading payments:", e);
    } finally {
      setLoadingPayments(false);
    }
  }, [contract.id]);

  useEffect(() => {
    if (activeTab === "payments") {
      loadPayments();
    }
  }, [activeTab, loadPayments]);

  // Prefer the structured palmInfo column, but keep legacy notes parsing as fallback.
  const PALM_PREFIX = '[[PALM_INFO]]';
  let palmInfo: any = contract.palmInfo || null;
  let cleanedNotes = contract.notes || '';
  try {
    if (!palmInfo && typeof contract.notes === 'string' && contract.notes.startsWith(PALM_PREFIX)) {
      const rest = contract.notes.substring(PALM_PREFIX.length);
      const jsonEnd = rest.indexOf('\n');
      const jsonStr = jsonEnd === -1 ? rest : rest.substring(0, jsonEnd);
      palmInfo = JSON.parse(jsonStr);
      cleanedNotes = jsonEnd === -1 ? '' : rest.substring(jsonEnd + 1);
    }
  } catch (e) {
    palmInfo = null;
    cleanedNotes = contract.notes || '';
  }

  // Determine which species to show (if encoded)
  let speciesToShow: string | null = null;
  if (palmInfo && palmInfo.isPalm) {
    speciesToShow = palmInfo.species || null;
    if (!speciesToShow) {
      const bal = palmInfo.baladi || {};
      const wash = palmInfo.washingtonia || {};
      const balSum = (Number(bal.largeProductive || 0) + Number(bal.largeNonProductive || 0) + Number(bal.smallProductive || 0) + Number(bal.smallNonProductive || 0));
      const washSum = (Number(wash.largeProductive || 0) + Number(wash.largeNonProductive || 0) + Number(wash.smallProductive || 0) + Number(wash.smallNonProductive || 0));
      speciesToShow = balSum >= washSum ? 'baladi' : 'washingtonia';
    }
  }

  // Only count payments that are actually received:
  // - manual payments: no gateway_status AND no dueDate
  // - gateway payments: gateway_status = 'paid'
  const totalPaid = payments
    .filter(p => p.gatewayStatus === "paid" || (!p.gatewayStatus && !p.dueDate))
    .reduce((sum, p) => sum + p.amount, 0);
  const remaining = (contract.totalValue || 0) - totalPaid;
  const paidPercent = contract.totalValue > 0 ? Math.min((totalPaid / contract.totalValue) * 100, 100) : 0;

  // Active payments = everything still a live financial commitment against the
  // contract (paid, pending gateway, or scheduled), excluding only payments
  // that will never be collected (failed/cancelled gateway attempts).
  const activePaymentsTotal = payments
    .filter(p => p.gatewayStatus !== "failed" && p.gatewayStatus !== "cancelled")
    .reduce((sum, p) => sum + p.amount, 0);
  const maxAllowedNewAmount = Math.max((contract.totalValue || 0) - activePaymentsTotal, 0);
  const amountExceedsLimit = parseFloat(paymentAmount) > maxAllowedNewAmount + 0.001;

  const PAYMENT_METHODS: { value: PaymentMethod; label: string }[] = [
    { value: "cash",     label: "نقدي" },
    { value: "transfer", label: "رابط" },
    { value: "cheque",   label: "شيك" },
    { value: "card",     label: "ومض" },
    { value: "gateway",  label: "UPayments" },
  ];

  const getMethodLabel = (m: string) => PAYMENT_METHODS.find(pm => pm.value === m)?.label || m;

  const todayStr = new Date().toISOString().slice(0, 10);
  const isPaymentLate = (p: ContractPayment) =>
    !!p.dueDate && p.dueDate < todayStr && p.gatewayStatus !== "paid";

  const getGatewayBadge = (p: ContractPayment) => {
    // paid → show as normal payment method label (falls through to getMethodLabel)
    if (p.gatewayStatus === "paid")      return null;
    if (isPaymentLate(p))                return { label: `متأخرة: ${p.dueDate}`, color: "var(--color-error)",    bg: "var(--color-error-bg)"   };
    if (p.gatewayStatus === "pending")   return { label: "في الانتظار",          color: "var(--color-warning)",  bg: "var(--color-warning-bg)" };
    if (p.gatewayStatus === "failed")    return { label: "فشل الدفع",            color: "var(--color-error)",    bg: "var(--color-error-bg)"   };
    if (p.gatewayStatus === "cancelled") return { label: "ملغي",                 color: "var(--text-secondary)", bg: "var(--neutral-100)"       };
    if (p.dueDate && !p.gatewayStatus)   return { label: `مجدولة: ${p.dueDate}`, color: "var(--color-warning)",  bg: "var(--color-warning-bg)" };
    return null;
  };

  const resetAddPaymentForm = () => {
    setShowAddPayment(false);
    setPaymentKind("paid");
    setPaymentAmount("");
    setPaymentMethod("");
    setPaymentDate(new Date().toISOString().split("T")[0]);
    setPaymentNotes("");
    setPaymentImageFile(null);
    setScheduledDueDate("");
  };

  const handleSubmitPayment = async () => {
    const amount = parseFloat(paymentAmount);
    if (!amount || amount <= 0) return;

    if (amount > maxAllowedNewAmount + 0.001) {
      notify(`المبلغ يتجاوز المتبقي من قيمة العقد (${maxAllowedNewAmount.toLocaleString()} د.ك)`);
      return;
    }

    if (paymentKind === "scheduled") {
      if (!scheduledDueDate) return;
      if (!paymentMethod) {
        notify("من فضلك اختر طريقة الدفع المتوقعة");
        return;
      }
      setSavingPayment(true);
      try {
        const created = await container.adminRepository.createScheduledContractPayment({
          contractId: contract.id,
          amount,
          dueDate: scheduledDueDate,
          paymentMethod,
          notes: paymentNotes || null,
        });

        // If the due date is already within the reminder window (≤3 days away,
        // or in the past), notify the client immediately instead of waiting for
        // the next daily cron run. functions.invoke() attaches the admin's own
        // session JWT automatically, which the function now requires.
        supabase.functions
          .invoke("notify-payment-now", { body: { paymentId: created.id } })
          .catch((e) => console.warn("notify-payment-now failed:", e));

        resetAddPaymentForm();
        await loadPayments();
        onPaymentsChange?.();
        notify("تم جدولة الدفعة — سيتلقى العميل إشعاراً");
      } catch (e: any) {
        console.error("Error scheduling payment:", e);
        notify("فشل جدولة الدفعة");
      } finally {
        setSavingPayment(false);
      }
      return;
    }

    if (!paymentDate) return;
    if (!paymentMethod) {
      notify("من فضلك اختر طريقة الدفع");
      return;
    }
    setSavingPayment(true);
    try {
      const payment = await container.adminRepository.createContractPayment({
        contractId: contract.id,
        amount,
        paymentMethod: paymentMethod,
        notes: paymentNotes || undefined,
        paymentDate,
      });
      // Upload image if present
      if (paymentImageFile) {
        const compressed = await compressImage(paymentImageFile);
        await container.adminRepository.uploadPaymentImage(
          payment.id,
          compressed,
          paymentImageFile.name.replace(/\.[^.]+$/, '.jpg')
        );
      }
      resetAddPaymentForm();
      await loadPayments();
      onPaymentsChange?.();
    } catch (e: any) {
      console.error("Error adding payment:", e);
    } finally {
      setSavingPayment(false);
    }
  };

  const handleDeletePayment = async (id: string) => {
    try {
      await container.adminRepository.deleteContractPayment(id);
      await loadPayments();
      onPaymentsChange?.();
    } catch (e) {
      console.error("Error deleting payment:", e);
    }
  };

  const startConvertToPaid = (p: ContractPayment) => {
    setEditingMethodPaymentId(null);
    setConvertingPaymentId(p.id);
    setConvertMethod(p.paymentMethod && p.paymentMethod !== "gateway" ? p.paymentMethod : "");
    setConvertDate(new Date().toISOString().split("T")[0]);
    setConvertNotes(p.notes || "");
    setConvertImageFile(null);
  };

  const startEditMethod = (p: ContractPayment) => {
    setConvertingPaymentId(null);
    setEditingMethodPaymentId(p.id);
    setEditMethodValue(p.paymentMethod && p.paymentMethod !== "gateway" ? p.paymentMethod : "");
  };

  const handleSaveMethodEdit = async (paymentId: string) => {
    if (!editMethodValue) {
      notify("من فضلك اختر طريقة الدفع");
      return;
    }
    setSavingMethodEdit(true);
    try {
      await container.adminRepository.updateScheduledPaymentMethod(paymentId, editMethodValue);
      setEditingMethodPaymentId(null);
      await loadPayments();
      onPaymentsChange?.();
      notify("تم تحديث طريقة الدفع المتوقعة");
    } catch (e: any) {
      console.error("Error updating scheduled payment method:", e);
      notify("فشل تحديث طريقة الدفع");
    } finally {
      setSavingMethodEdit(false);
    }
  };

  const handleConvertToPaid = async (paymentId: string) => {
    if (!convertDate) return;
    if (!convertMethod) {
      notify("من فضلك اختر طريقة الدفع");
      return;
    }
    setConvertingSaving(true);
    try {
      await container.adminRepository.markContractPaymentPaid({
        id: paymentId,
        paymentMethod: convertMethod,
        paymentDate: convertDate,
        notes: convertNotes || null,
      });
      if (convertImageFile) {
        const compressed = await compressImage(convertImageFile);
        await container.adminRepository.uploadPaymentImage(
          paymentId,
          compressed,
          convertImageFile.name.replace(/\.[^.]+$/, '.jpg')
        );
      }
      setConvertingPaymentId(null);
      await loadPayments();
      onPaymentsChange?.();
      notify("تم تسجيل الدفعة كمدفوعة");
    } catch (e: any) {
      console.error("Error converting payment to paid:", e);
      notify("فشل تحويل الدفعة لمدفوعة");
    } finally {
      setConvertingSaving(false);
    }
  };

  const handleSendGatewayPayment = async (payment: ContractPayment) => {
    setSendingGatewayId(payment.id);
    try {
      // functions.invoke() attaches the admin's own session JWT automatically,
      // which the function now requires; amount/client are re-derived server-side.
      const { error: invokeError } = await supabase.functions.invoke("create-upayment-charge", {
        body: {
          paymentId:   payment.id,
          paymentType: "contract",
        },
      });
      if (invokeError) {
        throw new Error(invokeError.message || "فشل إنشاء رابط الدفع");
      }
      await loadPayments();
      notify("تم إرسال رابط الدفع للعميل ✓");
    } catch (e: any) {
      console.error("handleSendGatewayPayment error:", e);
      notify(e.message || "فشل إرسال رابط الدفع");
    } finally {
      setSendingGatewayId(null);
    }
  };

  const handleDeleteContractImage = async () => {
    if (!contract.contractImageUrl) return;
    setDeletingImage(true);
    try {
      await container.adminRepository.deleteContractImage(contract.id, contract.contractImageUrl);
      await refreshContractDetails?.();
      notify("تم حذف صورة العقد");
      setConfirmDeleteImage(false);
    } catch (e) {
      console.error("Error deleting contract image:", e);
      notify("فشل حذف الصورة");
    } finally {
      setDeletingImage(false);
    }
  };

  return (
    <div
      className="contract-details-overlay"
      style={{
        position: "fixed",
        inset: 0,
        background: "rgba(0, 0, 0, 0.4)",
        backdropFilter: "blur(4px)",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        zIndex: 100,
      }}
    >
      <div
        className="card contract-details-modal"
        style={{
          width: "90%",
          maxWidth: "900px",
          height: "90vh",
          display: "flex",
          flexDirection: "column",
          padding: 0,
          boxShadow: "var(--shadow-lg)",
          overflow: "hidden",
        }}
      >
        <div
          className="contract-details-header"
          style={{
            padding: "20px 24px",
            borderBottom: "1px solid var(--color-border)",
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            background: "var(--bg-app)",
          }}
        >
          <div className="contract-details-header-main" style={{ display: "flex", gap: "12px", alignItems: "center" }}>
            <div
              style={{
                padding: "8px",
                background: "var(--primary-light)",
                borderRadius: "8px",
                color: "var(--color-primary)",
              }}
            >
              <FileText size={24} />
            </div>
            <div>
              <h3
                className="contract-details-title"
                style={{
                  margin: 0,
                  fontSize: "1.25rem",
                  color: "var(--text-primary)",
                  fontWeight: 700,
                }}
              >
                عقد رقم {contract.code}
              </h3>
              <div
                className="contract-details-created"
                style={{
                  fontSize: "0.85rem",
                  color: "var(--text-tertiary)",
                  marginTop: "2px",
                }}
              >
                تم الانشاء:{" "}
                {formatDateTime(contract.createdAt)}
              </div>
            </div>
          </div>
          <div className="contract-details-header-actions" style={{ display: "flex", gap: "12px", alignItems: "center" }}>
            <StatusPicker
              status={contract.status}
              onChange={(s: string) => onStatusChange?.(s)}
            />
            <button
              onClick={onClose}
              className="icon-button"
              title="إغلاق"
              style={{
                background: "transparent",
                border: "none",
                cursor: "pointer",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
              }}
            >
              <X size={20} />
            </button>
          </div>
        </div>

        <div
          className="contract-details-tabs"
          style={{
            display: "flex",
            padding: "0 24px",
            borderBottom: "1px solid var(--color-border)",
            background: "var(--bg-subtle)",
          }}
        >
          <button
            className="contract-details-tab"
            onClick={() => setActiveTab("summary")}
            style={{
              padding: "16px 24px",
              background: "transparent",
              border: "none",
              borderBottom: `2px solid ${activeTab === "summary" ? "var(--color-primary)" : "transparent"}`,
              color:
                activeTab === "summary"
                  ? "var(--color-primary)"
                  : "var(--text-secondary)",
              fontWeight: activeTab === "summary" ? 700 : 500,
              cursor: "pointer",
            }}
          >
            <LayoutList
              size={16}
              style={{
                display: "inline-block",
                marginLeft: "8px",
                verticalAlign: "text-bottom",
              }}
            />
            ملخص العقد
          </button>
          <button
            className="contract-details-tab"
            onClick={() => setActiveTab("visits")}
            style={{
              padding: "16px 24px",
              background: "transparent",
              border: "none",
              borderBottom: `2px solid ${activeTab === "visits" ? "var(--color-primary)" : "transparent"}`,
              color:
                activeTab === "visits"
                  ? "var(--color-primary)"
                  : "var(--text-secondary)",
              fontWeight: activeTab === "visits" ? 700 : 500,
              cursor: "pointer",
            }}
          >
            <Calendar
              size={16}
              style={{
                display: "inline-block",
                marginLeft: "8px",
                verticalAlign: "text-bottom",
              }}
            />
            الزيارات ({visits.length || "-"})
          </button>
          <button
            className="contract-details-tab"
            onClick={() => setActiveTab("payments")}
            style={{
              padding: "16px 24px",
              background: "transparent",
              border: "none",
              borderBottom: `2px solid ${activeTab === "payments" ? "var(--color-primary)" : "transparent"}`,
              color:
                activeTab === "payments"
                  ? "var(--color-primary)"
                  : "var(--text-secondary)",
              fontWeight: activeTab === "payments" ? 700 : 500,
              cursor: "pointer",
            }}
          >
            <DollarSign
              size={16}
              style={{
                display: "inline-block",
                marginLeft: "8px",
                verticalAlign: "text-bottom",
              }}
            />
            الدفعات ({payments.length || "-"})
          </button>
          <button
            className="contract-details-tab"
            onClick={() => setActiveTab("tasks")}
            style={{
              padding: "16px 24px",
              background: "transparent",
              border: "none",
              borderBottom: `2px solid ${activeTab === "tasks" ? "var(--color-primary)" : "transparent"}`,
              color: activeTab === "tasks" ? "var(--color-primary)" : "var(--text-secondary)",
              fontWeight: activeTab === "tasks" ? 700 : 500,
              cursor: "pointer",
            }}
          >
            <ClipboardList
              size={16}
              style={{ display: "inline-block", marginLeft: "8px", verticalAlign: "text-bottom" }}
            />
            المهام ({standaloneTasks.length || "-"})
          </button>
        </div>

        <div
          className="contract-details-body"
          style={{
            padding: "24px",
            overflowY: "auto",
            flex: 1,
            position: "relative",
          }}
        >
          {activeTab === "summary" && (
            <div
              className="contract-details-summary"
              style={{ display: "flex", flexDirection: "column", gap: "24px" }}
            >
              <div
                className="contract-details-kpis"
                style={{
                  display: "grid",
                  gridTemplateColumns: "repeat(4, 1fr)",
                  gap: "16px",
                }}
              >
                <div
                  style={{
                    padding: "16px",
                    background: "var(--bg-subtle)",
                    borderRadius: "12px",
                    border: "1px solid var(--color-border)",
                  }}
                >
                  <div
                    style={{
                      fontSize: "0.85rem",
                      color: "var(--text-secondary)",
                      marginBottom: "8px",
                    }}
                  >
                    القيمة الإجمالية
                  </div>
                  <div
                    style={{
                      fontSize: "1.25rem",
                      fontWeight: 800,
                      color: "var(--color-primary)",
                    }}
                  >
                    {contract.totalValue?.toLocaleString()}{" "}
                    <span style={{ fontSize: "0.8rem" }}>د.ك</span>
                  </div>
                </div>
                <div
                  style={{
                    padding: "16px",
                    background: "var(--bg-subtle)",
                    borderRadius: "12px",
                    border: "1px solid var(--color-border)",
                  }}
                >
                  <div
                    style={{
                      fontSize: "0.85rem",
                      color: "var(--text-secondary)",
                      marginBottom: "8px",
                    }}
                  >
                    نهاية العقد
                  </div>
                  <div
                    style={{
                      fontSize: "1rem",
                      fontWeight: 600,
                      color: "var(--text-primary)",
                    }}
                  >
                    {contract.endDate ? formatDate(contract.endDate) : ""}
                  </div>
                </div>
                <div
                  style={{
                    padding: "16px",
                    background: "var(--bg-subtle)",
                    borderRadius: "12px",
                    border: "1px solid var(--color-border)",
                  }}
                >
                  <div
                    style={{
                      fontSize: "0.85rem",
                      color: "var(--text-secondary)",
                      marginBottom: "8px",
                    }}
                  >
                    نوع العقد
                  </div>
                  <div
                    style={{
                      fontSize: "1rem",
                      fontWeight: 600,
                      color: "var(--text-primary)",
                    }}
                  >
                    {typeName}
                  </div>
                </div>
                <div
                  style={{
                    padding: "16px",
                    background: "var(--bg-subtle)",
                    borderRadius: "12px",
                    border: "1px solid var(--color-border)",
                  }}
                >
                  <div
                    style={{
                      fontSize: "0.85rem",
                      color: "var(--text-secondary)",
                      marginBottom: "8px",
                    }}
                  >
                    الخط الجغرافي
                  </div>
                  <div
                    style={{
                      fontSize: "1rem",
                      fontWeight: 600,
                      color: "var(--text-primary)",
                    }}
                  >
                    {lineName}
                  </div>
                </div>
              </div>

              <div
                className="contract-details-summary-grid"
                style={{
                  display: "grid",
                  gridTemplateColumns: "1.5fr 1fr",
                  gap: "24px",
                }}
              >
                <div
                  className="contract-details-main-col"
                  style={{
                    display: "flex",
                    flexDirection: "column",
                    gap: "24px",
                  }}
                >
                  <div
                    style={{
                      border: "1px solid var(--color-border)",
                      borderRadius: "12px",
                      overflow: "hidden",
                    }}
                  >
                    <div
                      style={{
                        background: "var(--neutral-50)",
                        padding: "12px 16px",
                        borderBottom: "1px solid var(--color-border)",
                        fontWeight: 600,
                        color: "var(--text-primary)",
                        display: "flex",
                        alignItems: "center",
                        gap: "8px",
                      }}
                    >
                      <UserIcon size={16} /> بيانات العميل والمستفيد
                    </div>
                    <div
                      className="contract-details-client-grid"
                      style={{
                        padding: "16px",
                        display: "grid",
                        gridTemplateColumns: "1fr 1fr",
                        gap: "16px",
                      }}
                    >
                      <div className="detail-item">
                        <label
                          style={{
                            fontSize: "0.8rem",
                            color: "var(--text-tertiary)",
                          }}
                        >
                          العميل الرئيسي
                        </label>
                        <div style={{ fontSize: "1rem", fontWeight: 600 }}>
                          {client?.fullName || "غير معروف"}
                        </div>
                      </div>
                      <div className="detail-item">
                        <label
                          style={{
                            fontSize: "0.8rem",
                            color: "var(--text-tertiary)",
                          }}
                        >
                          رقم الهاتف
                        </label>
                        <div
                          style={{
                            fontFamily: "monospace",
                            direction: "ltr",
                            textAlign: "right",
                          }}
                        >
                          {client?.phone || ""}
                        </div>
                      </div>
                      {(contract.contractUserName ||
                        contract.contractUserPhone) && (
                        <>
                          <div
                            className="contract-details-divider"
                            style={{
                              gridColumn: "span 2",
                              height: "1px",
                              background: "var(--color-border)",
                              margin: "4px 0",
                            }}
                          />
                          <div className="detail-item">
                            <label
                              style={{
                                fontSize: "0.8rem",
                                color: "var(--text-tertiary)",
                              }}
                            >
                              اسم الحارس
                            </label>
                            <div>{contract.contractUserName || ""}</div>
                          </div>
                          <div className="detail-item">
                            <label
                              style={{
                                fontSize: "0.8rem",
                                color: "var(--text-tertiary)",
                              }}
                            >
                              هاتف الحارس
                            </label>
                            <div
                              style={{
                                fontFamily: "monospace",
                                direction: "ltr",
                                textAlign: "right",
                              }}
                            >
                              {contract.contractUserPhone || ""}
                            </div>
                          </div>
                        </>
                      )}
                    </div>
                  </div>

                  <div
                    style={{
                      border: "1px solid var(--color-border)",
                      borderRadius: "12px",
                      overflow: "hidden",
                    }}
                  >
                    <div
                      style={{
                        background: "var(--neutral-50)",
                        padding: "12px 16px",
                        borderBottom: "1px solid var(--color-border)",
                        fontWeight: 600,
                        color: "var(--text-primary)",
                        display: "flex",
                        alignItems: "center",
                        gap: "8px",
                      }}
                    >
                      <MapPin size={16} /> تفاصيل العنوان والموقع
                    </div>
                    <div style={{ padding: "16px" }}>
                      <div
                        className="contract-details-address-grid"
                        style={{
                          display: "grid",
                          gridTemplateColumns: "repeat(3, 1fr)",
                          gap: "16px 12px",
                        }}
                      >
                        <div className="detail-item">
                          <label
                            style={{
                              fontSize: "0.8rem",
                              color: "var(--text-tertiary)",
                            }}
                          >
                            المنطقة
                          </label>
                          <div style={{ fontWeight: 600 }}>
                            {zoneName || ""}
                          </div>
                        </div>
                        <div className="detail-item">
                          <label
                            style={{
                              fontSize: "0.8rem",
                              color: "var(--text-tertiary)",
                            }}
                          >
                            القطعة
                          </label>
                          <div>{contract.blockNumber || ""}</div>
                        </div>
                        <div className="detail-item">
                          <label
                            style={{
                              fontSize: "0.8rem",
                              color: "var(--text-tertiary)",
                            }}
                          >
                            الشارع
                          </label>
                          <div>{contract.street || ""}</div>
                        </div>
                        <div className="detail-item">
                          <label
                            style={{
                              fontSize: "0.8rem",
                              color: "var(--text-tertiary)",
                            }}
                          >
                            الجادة
                          </label>
                          <div>{contract.avenue || ""}</div>
                        </div>
                        <div className="detail-item">
                          <label
                            style={{
                              fontSize: "0.8rem",
                              color: "var(--text-tertiary)",
                            }}
                          >
                            المنزل
                          </label>
                          <div>{contract.house || ""}</div>
                        </div>
                      </div>
                      {contract.addressDetails && (
                        <div
                          style={{
                            marginTop: "16px",
                            padding: "12px",
                            background: "var(--yellow-50)",
                            borderRadius: "8px",
                            border: "1px solid var(--yellow-200)",
                          }}
                        >
                          <div
                            style={{
                              fontSize: "0.75rem",
                              color: "var(--yellow-800)",
                              marginBottom: "4px",
                              fontWeight: 600,
                            }}
                          >
                            ملاحظات العنوان
                          </div>
                          <div
                            style={{
                              fontSize: "0.9rem",
                              color: "var(--text-primary)",
                            }}
                          >
                            {contract.addressDetails}
                          </div>
                        </div>
                      )}
                      {palmInfo && palmInfo.isPalm && (
                        <div style={{ marginTop: '12px', padding: '12px', background: 'var(--green-50)', borderRadius: '8px', border: '1px solid var(--green-200)' }}>
                          <div style={{ fontSize: '0.8rem', color: 'var(--green-700)', marginBottom: '6px', fontWeight: 700 }}>تفاصيل النخيل</div>
                          {speciesToShow === 'baladi' ? (
                            <div style={{ background: 'white', padding: '8px', borderRadius: '6px', border: '1px solid var(--color-border)' }}>
                              <div style={{ fontWeight: 700, marginBottom: '6px' }}>بلدي</div>
                              <div style={{ fontSize: '0.9rem', color: 'var(--text-primary)' }}>
                                كبير ومثمر: {palmInfo.baladi?.largeProductive ?? 0}
                                <br />
                                كبير وغير مثمر: {palmInfo.baladi?.largeNonProductive ?? 0}
                                <br />
                                صغير ومثمر: {palmInfo.baladi?.smallProductive ?? 0}
                                <br />
                                صغير وغير مثمر: {palmInfo.baladi?.smallNonProductive ?? 0}
                              </div>
                            </div>
                          ) : (
                            <div style={{ background: 'white', padding: '8px', borderRadius: '6px', border: '1px solid var(--color-border)' }}>
                              <div style={{ fontWeight: 700, marginBottom: '6px' }}>واشنطونيا</div>
                              <div style={{ fontSize: '0.9rem', color: 'var(--text-primary)' }}>
                                كبير ومثمر: {palmInfo.washingtonia?.largeProductive ?? 0}
                                <br />
                                كبير وغير مثمر: {palmInfo.washingtonia?.largeNonProductive ?? 0}
                                <br />
                                صغير ومثمر: {palmInfo.washingtonia?.smallProductive ?? 0}
                                <br />
                                صغير وغير مثمر: {palmInfo.washingtonia?.smallNonProductive ?? 0}
                              </div>
                            </div>
                          )}
                        </div>
                      )}

                      {cleanedNotes && (
                        <div
                          style={{
                            marginTop: "12px",
                            padding: "12px",
                            background: "var(--orange-50)",
                            borderRadius: "8px",
                            border: "1px solid var(--orange-200)",
                          }}
                        >
                          <div
                            style={{
                              fontSize: "0.75rem",
                              color: "var(--orange-700)",
                              marginBottom: "4px",
                              fontWeight: 600,
                            }}
                          >
                            ملاحظات العقد
                          </div>
                          <div
                            style={{
                              fontSize: "0.9rem",
                              color: "var(--text-primary)",
                              whiteSpace: "pre-wrap",
                            }}
                          >
                            {cleanedNotes}
                          </div>
                        </div>
                      )}
                      {contract.kuwaitFinderUrl && (
                        <div style={{ marginTop: "16px" }}>
                          <a
                            href={contract.kuwaitFinderUrl}
                            target="_blank"
                            rel="noreferrer"
                            style={{
                              display: "flex",
                              alignItems: "center",
                              gap: "8px",
                              padding: "10px",
                              borderRadius: "8px",
                              width: "100%",
                              justifyContent: "center",
                              background: "var(--bg-subtle)",
                              border: "1px solid var(--color-border)",
                              color: "var(--text-primary)",
                              textDecoration: "none",
                              fontWeight: 500,
                            }}
                          >
                            <MapPin size={16} />
                            عرض الموقع في Kuwait Finder
                          </a>
                        </div>
                      )}
                    </div>
                  </div>
                </div>

                <div
                  className="contract-details-side-col"
                  style={{
                    display: "flex",
                    flexDirection: "column",
                    gap: "24px",
                  }}
                >
                  {contract.contractImageUrl ? (
                    <div
                      style={{
                        border: "1px solid var(--color-border)",
                        borderRadius: "12px",
                        overflow: "hidden",
                      }}
                    >
                      <div
                        style={{
                          background: "var(--neutral-50)",
                          padding: "10px 16px",
                          borderBottom: "1px solid var(--color-border)",
                          fontWeight: 600,
                          color: "var(--text-primary)",
                          display: "flex",
                          alignItems: "center",
                          gap: "8px",
                        }}
                      >
                        <ImageIcon size={16} />
                        <span style={{ flex: 1 }}>صورة العقد</span>

                        {confirmDeleteImage ? (
                          <div style={{ display: "flex", alignItems: "center", gap: "6px" }}>
                            <span style={{ fontSize: "0.82rem", color: "var(--color-error)", fontWeight: 500 }}>
                              حذف الصورة؟
                            </span>
                            <button
                              type="button"
                              onClick={handleDeleteContractImage}
                              disabled={deletingImage}
                              style={{
                                padding: "4px 10px",
                                borderRadius: "6px",
                                border: "none",
                                background: "var(--color-error)",
                                color: "#fff",
                                fontSize: "0.8rem",
                                fontWeight: 600,
                                cursor: "pointer",
                                display: "flex",
                                alignItems: "center",
                                gap: "4px",
                              }}
                            >
                              {deletingImage ? <Loader2 size={12} className="spin" /> : null}
                              تأكيد
                            </button>
                            <button
                              type="button"
                              onClick={() => setConfirmDeleteImage(false)}
                              disabled={deletingImage}
                              style={{
                                padding: "4px 10px",
                                borderRadius: "6px",
                                border: "1px solid var(--color-border)",
                                background: "transparent",
                                fontSize: "0.8rem",
                                cursor: "pointer",
                              }}
                            >
                              إلغاء
                            </button>
                          </div>
                        ) : (
                          <button
                            type="button"
                            onClick={() => setConfirmDeleteImage(true)}
                            title="حذف صورة العقد"
                            style={{
                              padding: "4px 6px",
                              borderRadius: "6px",
                              border: "1px solid transparent",
                              background: "transparent",
                              color: "var(--text-tertiary)",
                              cursor: "pointer",
                              display: "flex",
                              alignItems: "center",
                              transition: "color 0.15s, background 0.15s",
                            }}
                            onMouseEnter={(e) => {
                              (e.currentTarget as HTMLButtonElement).style.color = "var(--color-error)";
                              (e.currentTarget as HTMLButtonElement).style.background = "var(--color-error-bg)";
                            }}
                            onMouseLeave={(e) => {
                              (e.currentTarget as HTMLButtonElement).style.color = "var(--text-tertiary)";
                              (e.currentTarget as HTMLButtonElement).style.background = "transparent";
                            }}
                          >
                            <Trash2 size={15} />
                          </button>
                        )}
                      </div>
                      <div
                        style={{
                          position: "relative",
                          height: "200px",
                          background: "var(--neutral-100)",
                          display: "flex",
                          justifyContent: "center",
                        }}
                      >
                        <img
                          src={contract.contractImageUrl}
                          alt="Contract"
                          style={{
                            maxWidth: "100%",
                            height: "100%",
                            objectFit: "contain",
                          }}
                        />
                        <div
                          style={{
                            position: "absolute",
                            inset: 0,
                            display: "flex",
                            alignItems: "center",
                            justifyContent: "center",
                            background: "rgba(0,0,0,0.3)",
                            opacity: 0,
                            transition: "opacity 0.2s",
                          }}
                          onMouseEnter={(e) =>
                            (e.currentTarget.style.opacity = "1")
                          }
                          onMouseLeave={(e) =>
                            (e.currentTarget.style.opacity = "0")
                          }
                        >
                          <a
                            href={contract.contractImageUrl}
                            target="_blank"
                            rel="noreferrer"
                            style={{
                              background: "var(--color-primary)",
                              color: "white",
                              padding: "8px 16px",
                              borderRadius: "8px",
                              textDecoration: "none",
                              fontWeight: 600,
                            }}
                          >
                            تكبير الصورة
                          </a>
                        </div>
                      </div>
                    </div>
                  ) : null}

                  <div
                    style={{
                      border: "1px solid var(--color-border)",
                      borderRadius: "12px",
                      overflow: "hidden",
                      flex: 1,
                    }}
                  >
                    <div
                      style={{
                        background: "var(--neutral-50)",
                        padding: "12px 16px",
                        borderBottom: "1px solid var(--color-border)",
                        fontWeight: 600,
                        color: "var(--text-primary)",
                        display: "flex",
                        alignItems: "center",
                        gap: "8px",
                      }}
                    >
                      <ClipboardList size={16} /> ملخص البنود والزيارات
                    </div>
                    <div
                      className="contract-details-terms-scroll"
                      style={{
                        padding: "0",
                        maxHeight: "400px",
                        overflowY: "auto",
                      }}
                    >
                      {contract.terms && contract.terms.length > 0 ? (
                        contract.terms.map((term: any, idx: number) => {
                          if (term.isExcluded) return null;
                          return (
                            <div
                              key={idx}
                              style={{
                                padding: "16px",
                                borderBottom: "1px solid var(--color-border)",
                                backgroundColor: "#fff",
                              }}
                            >
                              <div
                                style={{
                                  fontWeight: 700,
                                  fontSize: "0.95rem",
                                  marginBottom: "12px",
                                  color: "var(--text-primary)",
                                  display: "flex",
                                  gap: "8px",
                                  alignItems: "flex-start",
                                  background: "var(--neutral-50)",
                                  padding: "8px",
                                  borderRadius: "8px",
                                }}
                              >
                                <div
                                  style={{
                                    width: "24px",
                                    height: "24px",
                                    borderRadius: "6px",
                                    background: "var(--primary-light)",
                                    color: "var(--color-primary)",
                                    display: "flex",
                                    alignItems: "center",
                                    justifyContent: "center",
                                    flexShrink: 0,
                                  }}
                                >
                                  <FileText size={14} />
                                </div>
                                <div style={{ lineHeight: 1.4, flex: 1 }}>
                                  {term.content || (
                                    <span
                                      style={{
                                        color: "var(--text-tertiary)",
                                        fontStyle: "italic",
                                      }}
                                    >
                                      بند رقم {idx + 1} (بدون نص)
                                    </span>
                                  )}
                                </div>
                              </div>

                              {term.visits && term.visits.filter((v: any) => !v.isExcluded).length > 0 && (
                                <div
                                  style={{
                                    marginTop: "12px",
                                    paddingRight: "12px",
                                    borderRight: "2px solid var(--neutral-200)",
                                  }}
                                >
                                  {term.visits.filter((v: any) => !v.isExcluded).map((v: any, vi: number) => (
                                    <div
                                      key={vi}
                                      style={{ marginBottom: "12px" }}
                                    >
                                      <div
                                        style={{
                                          display: "flex",
                                          alignItems: "center",
                                          gap: "8px",
                                          marginBottom: "8px",
                                          color: "var(--text-secondary)",
                                          fontWeight: 600,
                                          fontSize: "0.9rem",
                                          background: "var(--neutral-50)",
                                          padding: "6px 10px",
                                          borderRadius: "6px",
                                        }}
                                      >
                                        <Truck size={14} />
                                        <span>
                                          نوع الزيارة:{" "}
                                          {v.description || "بدون وصف"}
                                        </span>
                                      </div>

                                      {v.tasks && v.tasks.length > 0 && (
                                        <div style={{ paddingRight: "22px" }}>
                                          <div
                                            style={{
                                              fontSize: "0.75rem",
                                              color: "var(--text-tertiary)",
                                              marginBottom: "4px",
                                              fontWeight: 600,
                                            }}
                                          >
                                            المهام المطلوبة:
                                          </div>
                                          <div
                                            style={{
                                              display: "flex",
                                              flexDirection: "column",
                                              gap: "6px",
                                            }}
                                          >
                                            {v.tasks.map(
                                              (task: any, ti: number) => (
                                                <div
                                                  key={ti}
                                                  style={{
                                                    display: "flex",
                                                    alignItems: "center",
                                                    gap: "8px",
                                                    fontSize: "0.85rem",
                                                    color:
                                                      "var(--text-secondary)",
                                                  }}
                                                >
                                                  <span
                                                    style={{
                                                      width: "4px",
                                                      height: "4px",
                                                      borderRadius: "50%",
                                                      background:
                                                        "var(--text-tertiary)",
                                                    }}
                                                  ></span>
                                                  {task.title}
                                                </div>
                                              ),
                                            )}
                                          </div>
                                        </div>
                                      )}
                                    </div>
                                  ))}
                                </div>
                              )}
                            </div>
                          );
                        })
                      ) : (
                        <div
                          style={{
                            padding: "16px",
                            textAlign: "center",
                            color: "var(--text-tertiary)",
                          }}
                        >
                          لا توجد بنود إضافية
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}
          {activeTab === "visits" && (
            <div className="contract-details-visits"
              style={{
                display: "flex",
                flexDirection: "column",
                gap: "16px",
                paddingBottom: "40px",
              }}
            >
              {loadingVisits ? (
                <div
                  style={{
                    display: "flex",
                    flexDirection: "column",
                    alignItems: "center",
                    justifyContent: "center",
                    padding: "60px",
                    color: "var(--text-tertiary)",
                  }}
                >
                  <Loader2
                    size={32}
                    className="animate-spin"
                    style={{
                      marginBottom: "16px",
                      color: "var(--color-primary)",
                    }}
                  />
                  <span>جاري تحميل سجل الزيارات...</span>
                </div>
              ) : visits.length > 0 ? (
                <>
                  {getTermVisitGroups().map((group, gi) => {
                    const isTermExpanded = expandedTerms.has(gi);
                    const completedCount = group.visits.filter((v: any) => v.status === "completed").length;
                    const totalCount = group.visits.length;
                    
                    return (
                      <div
                        key={gi}
                        style={{
                          border: "1px solid var(--color-border)",
                          borderRadius: "12px",
                          overflow: "hidden",
                          background: "#fff",
                          boxShadow: "0 2px 4px rgba(0,0,0,0.02)",
                        }}
                      >
                        {/* Term Header */}
                        <div
                          onClick={() => toggleTerm(gi)}
                          style={{
                            padding: "14px 20px",
                            background: "linear-gradient(135deg, var(--primary-light), var(--neutral-50))",
                            display: "flex",
                            justifyContent: "space-between",
                            alignItems: "center",
                            cursor: "pointer",
                            userSelect: "none",
                            borderBottom: isTermExpanded ? "1px solid var(--color-border)" : "none",
                          }}
                        >
                          <div style={{ display: "flex", alignItems: "center", gap: "12px", flex: 1, minWidth: 0 }}>
                            <div
                              style={{
                                width: "36px",
                                height: "36px",
                                borderRadius: "10px",
                                background: "var(--color-primary)",
                                color: "#fff",
                                display: "flex",
                                alignItems: "center",
                                justifyContent: "center",
                                flexShrink: 0,
                                fontSize: "0.85rem",
                                fontWeight: 700,
                              }}
                            >
                              {gi + 1}
                            </div>
                            <div style={{ minWidth: 0, flex: 1 }}>
                              <div
                                style={{
                                  fontWeight: 700,
                                  fontSize: "0.95rem",
                                  color: "var(--text-primary)",
                                  lineHeight: 1.4,
                                  overflow: "hidden",
                                  textOverflow: "ellipsis",
                                  whiteSpace: "nowrap",
                                }}
                              >
                                {group.term.content || `بند رقم ${gi + 1}`}
                              </div>
                              <div style={{ fontSize: "0.8rem", color: "var(--text-tertiary)", marginTop: "2px" }}>
                                {totalCount} زيارة • {completedCount} مكتملة
                              </div>
                            </div>
                          </div>
                          <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
                            {totalCount > 0 && (
                              <div style={{
                                width: "60px", height: "6px", borderRadius: "3px",
                                background: "var(--neutral-200)", overflow: "hidden",
                              }}>
                                <div style={{
                                  width: `${totalCount > 0 ? (completedCount / totalCount) * 100 : 0}%`,
                                  height: "100%", borderRadius: "3px",
                                  background: completedCount === totalCount ? "var(--green-500)" : "var(--color-primary)",
                                  transition: "width 0.3s",
                                }} />
                              </div>
                            )}
                            <ChevronLeft
                              size={20}
                              style={{
                                color: "var(--text-secondary)",
                                transform: isTermExpanded ? "rotate(-90deg)" : "rotate(0deg)",
                                transition: "transform 0.2s",
                              }}
                            />
                          </div>
                        </div>

                        {/* Term's Visits */}
                        {isTermExpanded && (
                          <div style={{ padding: "12px", display: "flex", flexDirection: "column", gap: "10px" }}>
                            {group.visits.length > 0 ? group.visits.map((visit: any, vi: number) => {
                              const isVisitExpanded = expandedVisits.has(visit.id);
                              const isLoadingDetail = loadingDetails.has(visit.id);
                              const executions = visitExecutions[visit.id] || [];
                              const photos = visitPhotos[visit.id] || [];
                              const directVisitPhotos = visitLevelPhotos[visit.id] || [];
                              const statusConfig = getVisitStatusStyle(visit.status);

                              return (
                                <div
                                  key={visit.id || vi}
                                  id={`visit-row-${visit.id}`}
                                  style={{
                                    border: `1px solid ${initialVisitId === visit.id ? "var(--color-primary)" : "var(--color-border)"}`,
                                    borderRadius: "10px",
                                    overflow: "hidden",
                                    background: "#fff",
                                    scrollMarginTop: 80,
                                  }}
                                >
                                  {/* Visit Header */}
                                  <div
                                    onClick={() => {
                                      toggleVisit(visit.id);
                                      if (!expandedVisits.has(visit.id)) {
                                        loadVisitDetails(visit);
                                        if (!supervisorNotes[visit.id]) {
                                          loadSupervisorNotes(visit.id);
                                        }
                                      }
                                    }}
                                    style={{
                                      padding: "12px 16px",
                                      background: statusConfig.bg,
                                      display: "flex",
                                      justifyContent: "space-between",
                                      alignItems: "center",
                                      cursor: "pointer",
                                      userSelect: "none",
                                      borderBottom: isVisitExpanded ? "1px solid var(--color-border)" : "none",
                                    }}
                                  >
                                    <div style={{ display: "flex", alignItems: "center", gap: "12px" }}>
                                      <Calendar size={16} style={{ color: statusConfig.color }} />
                                      <div>
                                        <div style={{ fontWeight: 600, fontSize: "0.9rem", color: "var(--text-primary)" }}>
                                          {visit.notes || "زيارة بدون وصف"}
                                        </div>
                                        <div style={{ fontSize: "0.75rem", color: "var(--text-tertiary)", marginTop: "1px" }}>
                                          {formatDate(visit.visitDate)}
                                          {" • "}
                                          {new Date(visit.visitDate).toLocaleDateString("ar-EG", { weekday: "long", numberingSystem: "latn" })}
                                        </div>
                                        {visit.completedAt ? (
                                          <div style={{ fontSize: "0.75rem", color: "var(--text-tertiary)", marginTop: "4px", display: "flex", alignItems: "center", gap: "6px" }}>
                                            <Clock size={12} />
                                            <span>
                                              {new Intl.DateTimeFormat("ar-EG", {
                                                dateStyle: "medium",
                                                timeStyle: "short",
                                                numberingSystem: "latn",
                                              }).format(new Date(visit.completedAt))}
                                            </span>
                                          </div>
                                        ) : null}
                                      </div>
                                    </div>
                                    <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
                                      <Badge variant={statusConfig.variant} style={{ padding: "4px 10px", fontSize: "0.75rem" }}>
                                        {statusConfig.label}
                                      </Badge>
                                      <ChevronDown
                                        size={16}
                                        style={{
                                          color: "var(--text-tertiary)",
                                          transform: isVisitExpanded ? "rotate(180deg)" : "rotate(0deg)",
                                          transition: "transform 0.2s",
                                        }}
                                      />
                                    </div>
                                  </div>

                                  {/* Visit Details */}
                                  {isVisitExpanded && (
                                    <div style={{ padding: "16px", display: "flex", flexDirection: "column", gap: "16px" }}>
                                      {visit.summary && (
                                        <div style={{
                                          padding: "12px",
                                          borderRadius: "8px",
                                          border: "1px solid var(--green-200)",
                                          background: "var(--green-50)",
                                        }}>
                                          <div style={{
                                            fontSize: "0.85rem",
                                            fontWeight: 700,
                                            marginBottom: "6px",
                                            color: "var(--green-700)",
                                            display: "flex",
                                            alignItems: "center",
                                            gap: "6px",
                                          }}>
                                            <FileText size={14} />
                                            ملخص الزيارة
                                          </div>
                                          <div style={{
                                            fontSize: "0.85rem",
                                            color: "var(--text-secondary)",
                                            lineHeight: 1.6,
                                            whiteSpace: "pre-wrap",
                                          }}>
                                            {visit.summary}
                                          </div>
                                        </div>
                                      )}

                                      {/* Supervisor Notes */}
                                      <div style={{
                                        padding: "12px",
                                        borderRadius: "8px",
                                        border: "1px solid var(--color-border)",
                                        background: "var(--bg-subtle)",
                                      }}>
                                        <div style={{
                                          fontSize: "0.85rem",
                                          fontWeight: 700,
                                          marginBottom: "10px",
                                          color: "var(--text-secondary)",
                                          display: "flex",
                                          alignItems: "center",
                                          gap: "6px",
                                        }}>
                                          <FileText size={15} />
                                          ملاحظات المشرف
                                        </div>
                                        <SupervisorNotesEditor
                                          visitId={visit.id}
                                          notes={supervisorNotes[visit.id] || []}
                                          onAddNote={(content, visibility) => handleAddNote(visit.id, content, visibility)}
                                          onUpdateNote={(noteId, content, visibility) => handleUpdateNote(visit.id, noteId, content, visibility)}
                                          onDeleteNote={(noteId) => handleDeleteNote(visit.id, noteId)}
                                          isLoading={!!noteActionLoading[visit.id]}
                                        />
                                      </div>

                                      {/* Tasks Section */}
                                      <div>
                                        <div style={{ fontSize: "0.85rem", fontWeight: 700, marginBottom: "10px", color: "var(--text-secondary)", display: "flex", alignItems: "center", gap: "6px" }}>
                                          <CheckSquare size={15} />
                                          المهام ({visit.tasks?.length || 0})
                                        </div>
                                        {visit.tasks && visit.tasks.length > 0 ? (
                                          <div style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
                                            {visit.tasks.map((task: any, ti: number) => {
                                              const isCompleted = task.status === "completed" || task.status === "verified";
                                              const taskExecs = executions.filter((e: any) => e.taskId === task.id);
                                              const taskPhotos = photos.filter((p: any) => taskExecs.some((e: any) => e.id === p.executionId));
                                              
                                              return (
                                                <div key={ti} style={{
                                                  padding: "10px 12px",
                                                  borderRadius: "8px",
                                                  border: `1px solid ${isCompleted ? "var(--green-200)" : "var(--color-border)"}`,
                                                  background: isCompleted ? "var(--green-50)" : "var(--bg-subtle)",
                                                }}>
                                                  <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
                                                    <div style={{
                                                      width: "20px", height: "20px", borderRadius: "5px",
                                                      border: `2px solid ${isCompleted ? "var(--green-500)" : "var(--neutral-400)"}`,
                                                      background: isCompleted ? "var(--green-500)" : "#fff",
                                                      display: "flex", alignItems: "center", justifyContent: "center",
                                                      color: "#fff", flexShrink: 0,
                                                    }}>
                                                      {isCompleted && <Check size={13} strokeWidth={3} />}
                                                    </div>
                                                    <span style={{
                                                      fontSize: "0.9rem", fontWeight: 500,
                                                      color: isCompleted ? "var(--text-secondary)" : "var(--text-primary)",
                                                      textDecoration: isCompleted ? "line-through" : "none",
                                                      flex: 1,
                                                    }}>
                                                      {task.title}
                                                    </span>
                                                    {task.status && (
                                                      <Badge
                                                        variant={isCompleted ? "success" : task.status === "rejected" ? "error" : "default"}
                                                        style={{ fontSize: "0.65rem", padding: "2px 6px" }}
                                                      >
                                                        {task.status === "completed" ? "مكتمل" : task.status === "verified" ? "تم التحقق" : task.status === "rejected" ? "مرفوض" : "معلّق"}
                                                      </Badge>
                                                    )}
                                                  </div>
                                                  
                                                  {/* Task Execution Notes */}
                                                  {taskExecs.length > 0 && taskExecs.some((e: any) => e.notes) && (
                                                    <div style={{ marginTop: "8px", paddingRight: "30px" }}>
                                                      {taskExecs.filter((e: any) => e.notes).map((exec: any) => (
                                                        <div key={exec.id} style={{
                                                          fontSize: "0.8rem", color: "var(--text-tertiary)",
                                                          padding: "6px 10px", background: "var(--yellow-50)",
                                                          borderRadius: "6px", border: "1px solid var(--yellow-200)",
                                                          marginBottom: "4px",
                                                        }}>
                                                          <MessageCircle size={12} style={{ display: "inline", verticalAlign: "text-bottom", marginLeft: "4px" }} />
                                                          {" "}{exec.notes}
                                                        </div>
                                                      ))}
                                                    </div>
                                                  )}

                                                  {/* Task Photos */}
                                                  {taskPhotos.length > 0 && (
                                                    <div style={{ marginTop: "8px", paddingRight: "30px" }}>
                                                      <div style={{ display: "flex", gap: "8px", flexWrap: "wrap" }}>
                                                        {taskPhotos.map((photo: any) => (
                                                          <a
                                                            key={photo.id}
                                                            href={photo.photoUrl}
                                                            target="_blank"
                                                            rel="noreferrer"
                                                            style={{
                                                              width: "64px", height: "64px", borderRadius: "8px",
                                                              overflow: "hidden", border: "1px solid var(--color-border)",
                                                              position: "relative", display: "block",
                                                            }}
                                                          >
                                                            <img
                                                              src={photo.photoUrl}
                                                              alt={photo.photoType === "before" ? "قبل" : "بعد"}
                                                              style={{ width: "100%", height: "100%", objectFit: "cover" }}
                                                            />
                                                            <span style={{
                                                              position: "absolute", bottom: 0, left: 0, right: 0,
                                                              background: "rgba(0,0,0,0.6)", color: "#fff",
                                                              fontSize: "0.6rem", textAlign: "center", padding: "1px 0",
                                                            }}>
                                                              {photo.photoType === "before" ? "قبل" : "بعد"}
                                                            </span>
                                                          </a>
                                                        ))}
                                                      </div>
                                                    </div>
                                                  )}
                                                </div>
                                              );
                                            })}
                                          </div>
                                        ) : (
                                          <div style={{
                                            padding: "16px", textAlign: "center",
                                            background: "var(--bg-subtle)", borderRadius: "8px",
                                            color: "var(--text-tertiary)", fontSize: "0.85rem",
                                            border: "1px dashed var(--color-border)",
                                          }}>
                                            لا توجد مهام مسجلة لهذه الزيارة
                                          </div>
                                        )}
                                      </div>

                                      {/* Visit-level photos uploaded on visit completion */}
                                      {directVisitPhotos.length > 0 && (
                                        <div>
                                          <div style={{ fontSize: "0.85rem", fontWeight: 700, marginBottom: "10px", color: "var(--text-secondary)", display: "flex", alignItems: "center", gap: "6px" }}>
                                            <Camera size={15} />
                                            صور الزيارة ({directVisitPhotos.length})
                                          </div>
                                          <div style={{ display: "flex", gap: "8px", flexWrap: "wrap" }}>
                                            {directVisitPhotos.map((photo: any) => (
                                              <a
                                                key={photo.id}
                                                href={photo.photoUrl}
                                                target="_blank"
                                                rel="noreferrer"
                                                style={{
                                                  width: "80px", height: "80px", borderRadius: "8px",
                                                  overflow: "hidden", border: "2px solid var(--color-border)",
                                                  position: "relative", display: "block",
                                                  transition: "border-color 0.2s",
                                                }}
                                              >
                                                <img
                                                  src={photo.photoUrl}
                                                  alt="صورة زيارة"
                                                  style={{ width: "100%", height: "100%", objectFit: "cover" }}
                                                />
                                              </a>
                                            ))}
                                          </div>
                                        </div>
                                      )}

                                      {/* Task photos captured while executing tasks */}
                                      {photos.length > 0 && (
                                        <div>
                                          <div style={{ fontSize: "0.85rem", fontWeight: 700, marginBottom: "10px", color: "var(--text-secondary)", display: "flex", alignItems: "center", gap: "6px" }}>
                                            <ImageIcon size={15} />
                                            صور تنفيذ المهام ({photos.length})
                                          </div>
                                          <div style={{ display: "flex", gap: "8px", flexWrap: "wrap" }}>
                                            {photos.map((photo: any) => (
                                              <a
                                                key={photo.id}
                                                href={photo.photoUrl}
                                                target="_blank"
                                                rel="noreferrer"
                                                style={{
                                                  width: "80px", height: "80px", borderRadius: "8px",
                                                  overflow: "hidden", border: "2px solid var(--color-border)",
                                                  position: "relative", display: "block",
                                                  transition: "border-color 0.2s",
                                                }}
                                              >
                                                <img
                                                  src={photo.photoUrl}
                                                  alt={photo.photoType === "before" ? "قبل" : "بعد"}
                                                  style={{ width: "100%", height: "100%", objectFit: "cover" }}
                                                />
                                                <span style={{
                                                  position: "absolute", bottom: 0, left: 0, right: 0,
                                                  background: photo.photoType === "before" ? "rgba(234,179,8,0.85)" : "rgba(34,197,94,0.85)",
                                                  color: "#fff", fontSize: "0.65rem", textAlign: "center", padding: "2px 0", fontWeight: 600,
                                                }}>
                                                  {photo.photoType === "before" ? "قبل" : "بعد"}
                                                </span>
                                              </a>
                                            ))}
                                          </div>
                                        </div>
                                      )}

                                      {/* Visit Comments */}
                                      {(() => {
                                        const visitComments = comments.filter((c: any) => !c.visitId || c.visitId === visit.id);
                                        if (visitComments.length === 0) return null;

                                        return (
                                          <div>
                                            <div style={{ fontSize: "0.85rem", fontWeight: 700, marginBottom: "10px", color: "var(--text-secondary)", display: "flex", alignItems: "center", gap: "6px" }}>
                                              <MessageCircle size={15} />
                                              تعليقات الزيارة
                                            </div>
                                            <div style={{ display: "flex", flexDirection: "column", gap: "6px" }}>
                                              {visitComments.map((c: any) => (
                                                <div key={c.id} style={{
                                                  padding: "10px 12px", borderRadius: "8px",
                                                  background: "var(--bg-subtle)", border: "1px solid var(--color-border)",
                                                }}>
                                                  <div style={{ fontSize: "0.75rem", color: "var(--text-tertiary)", marginBottom: "4px" }}>
                                                    {c.authorName || "العميل"}
                                                  </div>
                                                  <div style={{ fontSize: "0.85rem", color: "var(--text-primary)", lineHeight: 1.5 }}>
                                                    {c.comment}
                                                  </div>
                                                  {c.attachmentPath && (
                                                    <div style={{ marginTop: "8px" }}>
                                                      <a href={c.attachmentPath} target="_blank" rel="noreferrer" style={{ display: "inline-block", width: "80px", height: "80px", borderRadius: "8px", overflow: "hidden", border: "2px solid var(--color-border)" }}>
                                                        <img src={c.attachmentPath} alt="مرفق" style={{ width: "100%", height: "100%", objectFit: "cover" }} />
                                                      </a>
                                                    </div>
                                                  )}

                                                  <div style={{ fontSize: "0.7rem", color: "var(--text-tertiary)", marginTop: "4px" }}>
                                                    {formatDateTime(c.createdAt)}
                                                  </div>
                                                </div>
                                              ))}
                                            </div>
                                          </div>
                                        );
                                      })()}

                                      {isLoadingDetail && (
                                        <div style={{ display: "flex", alignItems: "center", gap: "8px", padding: "8px", color: "var(--text-tertiary)", fontSize: "0.8rem" }}>
                                          <Loader2 size={14} className="animate-spin" />
                                          جاري تحميل التفاصيل...
                                        </div>
                                      )}
                                    </div>
                                  )}
                                </div>
                              );
                            }) : (
                              <div style={{
                                padding: "20px", textAlign: "center",
                                color: "var(--text-tertiary)", fontSize: "0.85rem",
                              }}>
                                لا توجد زيارات لهذا البند
                              </div>
                            )}
                          </div>
                        )}
                      </div>
                    );
                  })}
                </>
              ) : (
                <div
                  style={{
                    padding: "60px",
                    textAlign: "center",
                    color: "var(--text-tertiary)",
                    background: "var(--bg-card)",
                    borderRadius: "12px",
                    border: "1px dashed var(--color-border)",
                    marginTop: "20px",
                  }}
                >
                  <div
                    style={{
                      width: "64px",
                      height: "64px",
                      borderRadius: "50%",
                      background: "var(--neutral-100)",
                      margin: "0 auto 16px",
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                    }}
                  >
                    <Calendar size={32} style={{ opacity: 0.5 }} />
                  </div>
                  <p
                    style={{
                      fontSize: "1.1rem",
                      fontWeight: 600,
                      color: "var(--text-secondary)",
                    }}
                  >
                    لا توجد زيارات
                  </p>
                  <p style={{ marginTop: "8px" }}>
                    لم يتم إنشاء أي زيارات لهذا العقد حتى الآن.
                  </p>
                </div>
              )}
            </div>
          )}

          {activeTab === "tasks" && (
            <div className="contract-details-tasks" style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <div style={{ fontWeight: 800, color: "var(--text-primary)", fontSize: "1rem" }}>المهام المرتبطة بالعقد</div>
                <div style={{ display: "flex", gap: 8 }}>
                  <button className="button primary" onClick={() => setShowCreateTask(true)} style={{ display: "inline-flex", alignItems: "center", gap: 8 }}>
                    <Plus size={14} /> إنشاء مهمة مرتبطة
                  </button>
                </div>
              </div>

              {loadingStandaloneTasks ? (
                <div style={{ padding: 24, textAlign: "center" }}>
                  <Loader2 size={28} className="animate-spin" />
                  <div style={{ marginTop: 8, color: "var(--text-tertiary)" }}>جاري تحميل المهام...</div>
                </div>
              ) : standaloneTasks.length === 0 ? (
                <div style={{ padding: 16, textAlign: "center", color: "var(--text-tertiary)" }}>لا توجد مهام مرتبطة بهذا العقد</div>
              ) : (
                <div style={{ overflowX: "auto" }}>
                  <table style={{ width: "100%", borderCollapse: "collapse", minWidth: 800 }}>
                    <thead>
                      <tr>
                        <th style={thStyle}>المهمة</th>
                        <th style={thStyle}>التاريخ</th>
                        <th style={thStyle}>المشرف</th>
                        <th style={thStyle}>الحالة</th>
                        <th style={thStyle}>التكلفة</th>
                        <th style={{ ...thStyle, textAlign: "center" }}>الإجراءات</th>
                      </tr>
                    </thead>
                    <tbody>
                      {standaloneTasks.map((t) => (
                        <tr key={t.id} style={{ borderBottom: "1px solid var(--color-border)" }}>
                          <td style={tdStyle}>{t.title}</td>
                          <td style={tdStyle}>{renderTaskTimestamp(t)}</td>
                          <td style={tdStyle}>{t.supervisorId ? supervisorsMap[t.supervisorId] || "—" : "—"}</td>
                          <td style={{ ...tdStyle }}>{getTaskStatusLabel(t.status)}</td>
                          <td style={tdStyle}>{t.cost != null ? Number(t.cost).toFixed(2) + ' د.ك' : '—'}</td>
                          <td style={{ ...tdStyle, textAlign: "center", display: "flex", gap: 8, justifyContent: "center", alignItems: "center" }}>
                            <button
                              className="button secondary"
                              onClick={() => setViewingStandaloneTaskId(t.id)}
                              style={{ display: "inline-flex", alignItems: "center", gap: 4, padding: "4px 12px" }}
                            >
                              <Eye size={14} />
                              عرض
                            </button>
                            <button
                              className="button secondary"
                              onClick={() => setEditingStandaloneTaskId(t.id)}
                              style={{ display: "inline-flex", alignItems: "center", gap: 4, padding: "4px 12px" }}
                            >
                              <Pencil size={14} />
                              تعديل
                            </button>
                            <button
                              className="button"
                              onClick={() => handleDeleteStandaloneTask(t.id)}
                              disabled={deletingStandaloneTaskId === t.id}
                              style={{
                                display: "inline-flex",
                                alignItems: "center",
                                gap: 4,
                                padding: "4px 8px",
                                background: "var(--color-error-bg)",
                                color: "var(--color-error)",
                                border: "none",
                                cursor: deletingStandaloneTaskId === t.id ? "not-allowed" : "pointer",
                                borderRadius: 6,
                                opacity: deletingStandaloneTaskId === t.id ? 0.7 : 1,
                              }}
                            >
                              <Trash2 size={14} />
                              {deletingStandaloneTaskId === t.id ? "جاري الحذف..." : "حذف"}
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          )}

          {activeTab === "payments" && (
            <div className="contract-details-payments" style={{ display: "flex", flexDirection: "column", gap: "20px" }}>
              {/* Payment Summary Cards */}
              <div className="contract-details-payments-kpis" style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: "16px" }}>
                <div style={{ padding: "16px", background: "var(--bg-subtle)", borderRadius: "12px", border: "1px solid var(--color-border)" }}>
                  <div style={{ fontSize: "0.85rem", color: "var(--text-secondary)", marginBottom: "8px" }}>إجمالي العقد</div>
                  <div style={{ fontSize: "1.25rem", fontWeight: 800, color: "var(--text-primary)" }}>
                    {contract.totalValue?.toLocaleString()} <span style={{ fontSize: "0.8rem" }}>د.ك</span>
                  </div>
                </div>
                <div style={{ padding: "16px", background: "var(--color-success-bg)", borderRadius: "12px", border: "1px solid var(--green-200)" }}>
                  <div style={{ fontSize: "0.85rem", color: "var(--color-success)", marginBottom: "8px" }}>المدفوع</div>
                  <div style={{ fontSize: "1.25rem", fontWeight: 800, color: "var(--color-success)" }}>
                    {totalPaid.toLocaleString()} <span style={{ fontSize: "0.8rem" }}>د.ك</span>
                  </div>
                </div>
                <div style={{ padding: "16px", background: remaining > 0 ? "var(--color-warning-bg)" : "var(--color-success-bg)", borderRadius: "12px", border: `1px solid ${remaining > 0 ? "var(--orange-200)" : "var(--green-200)"}` }}>
                  <div style={{ fontSize: "0.85rem", color: remaining > 0 ? "var(--color-warning)" : "var(--color-success)", marginBottom: "8px" }}>المتبقي</div>
                  <div style={{ fontSize: "1.25rem", fontWeight: 800, color: remaining > 0 ? "var(--color-warning)" : "var(--color-success)" }}>
                    {remaining.toLocaleString()} <span style={{ fontSize: "0.8rem" }}>د.ك</span>
                  </div>
                </div>
              </div>

              {/* Progress Bar */}
              <div style={{ background: "var(--neutral-100)", borderRadius: "8px", height: "10px", overflow: "hidden" }}>
                <div style={{ height: "100%", width: `${paidPercent}%`, background: paidPercent >= 100 ? "var(--color-success)" : "var(--color-primary)", borderRadius: "8px", transition: "width 0.5s ease" }} />
              </div>
              <div style={{ display: "flex", justifyContent: "space-between", fontSize: "0.8rem", color: "var(--text-tertiary)" }}>
                <span>نسبة السداد: {paidPercent.toFixed(1)}%</span>
                <span>{payments.length} دفعة</span>
              </div>

              {/* Add Payment Button */}
              {!showAddPayment && (
                <button
                  onClick={() => setShowAddPayment(true)}
                  style={{
                    display: "flex", alignItems: "center", justifyContent: "center", gap: "8px",
                    padding: "12px", borderRadius: "10px", border: "2px dashed var(--color-border)",
                    background: "var(--bg-subtle)", color: "var(--color-primary)", fontWeight: 600,
                    fontSize: "0.9rem", cursor: "pointer",
                  }}
                >
                  <Plus size={18} /> إضافة دفعة
                </button>
              )}

              {/* Unified Add Payment Form */}
              {showAddPayment && (
                <div className="contract-details-add-payment" style={{
                  border: "1px solid var(--color-border)", borderRadius: "12px",
                  padding: "20px", background: "var(--bg-card)", boxShadow: "var(--shadow-sm)",
                }}>
                  <div style={{ fontWeight: 700, fontSize: "1rem", color: "var(--text-primary)", marginBottom: "16px", display: "flex", alignItems: "center", gap: "8px" }}>
                    <CreditCard size={18} style={{ color: "var(--color-primary)" }} />
                    إضافة دفعة جديدة
                  </div>

                  {/* kind toggle: paid now vs scheduled */}
                  <div style={{ display: "flex", gap: "8px", marginBottom: "16px", background: "var(--neutral-50)", padding: "4px", borderRadius: "10px", border: "1px solid var(--color-border)", width: "fit-content" }}>
                    <button
                      type="button"
                      onClick={() => setPaymentKind("paid")}
                      style={{
                        padding: "8px 16px", borderRadius: "8px", fontSize: "0.85rem", fontWeight: 600,
                        border: "none", cursor: "pointer",
                        background: paymentKind === "paid" ? "var(--color-primary)" : "transparent",
                        color: paymentKind === "paid" ? "var(--text-on-primary)" : "var(--text-secondary)",
                      }}
                    >
                      مدفوعة الآن
                    </button>
                    <button
                      type="button"
                      onClick={() => setPaymentKind("scheduled")}
                      style={{
                        padding: "8px 16px", borderRadius: "8px", fontSize: "0.85rem", fontWeight: 600,
                        border: "none", cursor: "pointer",
                        background: paymentKind === "scheduled" ? "var(--green-700)" : "transparent",
                        color: paymentKind === "scheduled" ? "#fff" : "var(--text-secondary)",
                      }}
                    >
                      مجدولة لتاريخ
                    </button>
                  </div>

                  <div className="contract-details-payment-fields" style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "16px" }}>
                    <div style={{ display: "flex", flexDirection: "column", gap: "6px" }}>
                      <label style={{ fontSize: "0.85rem", fontWeight: 500, color: "var(--text-secondary)" }}>
                        المبلغ <span style={{ color: "var(--color-error)" }}>*</span>
                      </label>
                      <input
                        type="number"
                        step="0.01"
                        min="0.01"
                        placeholder="0.000"
                        value={paymentAmount}
                        onChange={e => setPaymentAmount(e.target.value)}
                        style={{
                          padding: "10px 12px", borderRadius: "8px",
                          border: `1px solid ${amountExceedsLimit ? "var(--color-error)" : "var(--color-border)"}`,
                          fontSize: "0.95rem", outline: "none", direction: "ltr",
                        }}
                      />
                      <span style={{ fontSize: "0.75rem", color: amountExceedsLimit ? "var(--color-error)" : "var(--text-tertiary)" }}>
                        الحد الأقصى المسموح به: {maxAllowedNewAmount.toLocaleString()} د.ك
                      </span>
                    </div>

                    {paymentKind === "paid" ? (
                      <>
                        <div style={{ display: "flex", flexDirection: "column", gap: "6px" }}>
                          <label style={{ fontSize: "0.85rem", fontWeight: 500, color: "var(--text-secondary)" }}>
                            طريقة الدفع
                          </label>
                          <CustomSelect
                            value={paymentMethod}
                            onChange={val => setPaymentMethod(val as PaymentMethod)}
                            options={PAYMENT_METHODS.map(m => ({ id: m.value, label: m.label }))}
                            placeholder="اختر طريقة الدفع"
                            width="100%"
                          />
                        </div>
                        <div style={{ display: "flex", flexDirection: "column", gap: "6px" }}>
                          <label style={{ fontSize: "0.85rem", fontWeight: 500, color: "var(--text-secondary)" }}>
                            تاريخ الدفع <span style={{ color: "var(--color-error)" }}>*</span>
                          </label>
                          <input
                            type="date"
                            value={paymentDate}
                            onChange={e => setPaymentDate(e.target.value)}
                            style={{
                              padding: "10px 12px", borderRadius: "8px", border: "1px solid var(--color-border)",
                              fontSize: "0.9rem", outline: "none",
                            }}
                          />
                        </div>
                        <div style={{ display: "flex", flexDirection: "column", gap: "6px" }}>
                          <label style={{ fontSize: "0.85rem", fontWeight: 500, color: "var(--text-secondary)" }}>
                            صورة التحويل
                          </label>
                          <input
                            ref={paymentFileRef}
                            type="file"
                            accept="image/*"
                            style={{ display: "none" }}
                            onChange={e => {
                              const f = e.target.files?.[0];
                              if (f && f.type.startsWith("image/")) setPaymentImageFile(f);
                              e.target.value = "";
                            }}
                          />
                          <button
                            type="button"
                            onClick={() => paymentFileRef.current?.click()}
                            style={{
                              padding: "10px 12px", borderRadius: "8px", border: "1px solid var(--color-border)",
                              fontSize: "0.85rem", cursor: "pointer", display: "flex", alignItems: "center",
                              gap: "8px", background: paymentImageFile ? "var(--green-50)" : "#fff",
                              color: paymentImageFile ? "var(--color-success)" : "var(--text-secondary)",
                            }}
                          >
                            <Upload size={16} />
                            {paymentImageFile ? paymentImageFile.name : "اختر صورة..."}
                          </button>
                        </div>
                      </>
                    ) : (
                      <>
                        <div style={{ display: "flex", flexDirection: "column", gap: "6px" }}>
                          <label style={{ fontSize: "0.85rem", fontWeight: 500, color: "var(--text-secondary)" }}>
                            تاريخ الاستحقاق <span style={{ color: "var(--color-error)" }}>*</span>
                          </label>
                          <input
                            type="date"
                            value={scheduledDueDate}
                            onChange={e => setScheduledDueDate(e.target.value)}
                            style={{ padding: "10px 12px", borderRadius: "8px", border: "1px solid var(--color-border)", fontSize: "0.9rem", outline: "none" }}
                          />
                        </div>
                        <div style={{
                          border: "1px solid var(--color-primary)", borderRadius: "10px",
                          padding: "12px", background: "var(--primary-light)",
                          display: "flex", flexDirection: "column", gap: "8px",
                        }}>
                          <label style={{ display: "flex", alignItems: "center", gap: "6px", fontSize: "0.82rem", fontWeight: 700, color: "var(--color-primary)" }}>
                            <Clock size={14} />
                            طريقة الدفع المتوقعة <span style={{ color: "var(--color-error)" }}>*</span>
                          </label>
                          <CustomSelect
                            value={paymentMethod}
                            onChange={val => setPaymentMethod(val as PaymentMethod)}
                            options={PAYMENT_METHODS.filter(m => m.value !== "gateway").map(m => ({ id: m.value, label: m.label }))}
                            placeholder="اختر طريقة الدفع"
                            width="100%"
                          />
                        </div>
                      </>
                    )}

                    <div className="contract-details-payment-notes" style={{ gridColumn: "span 2", display: "flex", flexDirection: "column", gap: "6px" }}>
                      <label style={{ fontSize: "0.85rem", fontWeight: 500, color: "var(--text-secondary)" }}>ملاحظات</label>
                      <input
                        type="text"
                        placeholder="ملاحظات اختيارية..."
                        value={paymentNotes}
                        onChange={e => setPaymentNotes(e.target.value)}
                        style={{
                          padding: "10px 12px", borderRadius: "8px", border: "1px solid var(--color-border)",
                          fontSize: "0.9rem", outline: "none",
                        }}
                      />
                    </div>
                  </div>

                  {paymentKind === "scheduled" && (
                    <p style={{ marginTop: "10px", fontSize: "0.78rem", color: "var(--text-tertiary)" }}>
                      سيتلقى العميل إشعاراً قبل تاريخ الاستحقاق، ويمكنه الدفع عبر بوابة UPayments.
                    </p>
                  )}

                  <div className="contract-details-add-payment-actions" style={{ display: "flex", gap: "10px", marginTop: "16px", justifyContent: "flex-end" }}>
                    <button
                      onClick={resetAddPaymentForm}
                      style={{
                        padding: "10px 20px", borderRadius: "8px", border: "1px solid var(--color-border)",
                        background: "#fff", cursor: "pointer", fontWeight: 600, color: "var(--text-secondary)",
                      }}
                    >
                      إلغاء
                    </button>
                    <button
                      onClick={handleSubmitPayment}
                      disabled={
                        savingPayment ||
                        !paymentAmount ||
                        amountExceedsLimit ||
                        !paymentMethod ||
                        (paymentKind === "paid" ? !paymentDate : !scheduledDueDate)
                      }
                      style={{
                        padding: "10px 24px", borderRadius: "8px", border: "none",
                        background: savingPayment ? "var(--neutral-400)" : (paymentKind === "scheduled" ? "var(--green-700)" : "var(--green-600)"),
                        color: "#fff", cursor: savingPayment ? "wait" : "pointer", fontWeight: 600,
                        display: "flex", alignItems: "center", gap: "8px",
                      }}
                    >
                      {savingPayment ? <Loader2 size={16} className="animate-spin" /> : <Check size={16} />}
                      {savingPayment ? "جار الحفظ..." : (paymentKind === "scheduled" ? "جدولة الدفعة" : "حفظ الدفعة")}
                    </button>
                  </div>
                </div>
              )}

              {/* Payments List */}
              {loadingPayments ? (
                <div style={{ display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", padding: "40px", color: "var(--text-tertiary)" }}>
                  <Loader2 size={28} className="animate-spin" style={{ marginBottom: "12px", color: "var(--color-primary)" }} />
                  <span>جاري تحميل الدفعات...</span>
                </div>
              ) : payments.length > 0 ? (
                <div className="contract-details-payments-list" style={{ display: "flex", flexDirection: "column", gap: "10px" }}>
                  {payments.map((p, idx) => (
                    <div className="contract-details-payment-item" key={p.id} style={{
                      padding: "16px", borderRadius: "12px", border: "1px solid var(--color-border)",
                      background: "var(--bg-card)", display: "flex", flexDirection: "column", gap: "12px",
                      transition: "box-shadow 0.2s",
                    }}>
                      <div style={{ display: "flex", alignItems: "center", gap: "16px" }}>
                        <div style={{
                          width: "40px", height: "40px", borderRadius: "10px",
                          background: "var(--color-success-bg)", color: "var(--color-success)",
                          display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0,
                        }}>
                          <DollarSign size={20} />
                        </div>
                        <div className="contract-details-payment-main" style={{ flex: 1, minWidth: 0 }}>
                          <div style={{ display: "flex", alignItems: "center", gap: "10px", marginBottom: "4px", flexWrap: "wrap" }}>
                            <span style={{ fontWeight: 700, fontSize: "1.05rem", color: p.gatewayStatus === "pending" ? "var(--color-warning)" : "var(--color-success)" }}>
                              {p.amount.toLocaleString("ar-KW", { minimumFractionDigits: 3 })} د.ك
                            </span>
                            {(() => {
                              const badge = getGatewayBadge(p);
                              if (badge) return (
                                <span style={{ padding: "2px 10px", borderRadius: "20px", fontSize: "0.75rem", fontWeight: 600, background: badge.bg, color: badge.color }}>
                                  {badge.label}
                                </span>
                              );
                              return (
                                <span style={{ padding: "2px 10px", borderRadius: "20px", fontSize: "0.75rem", fontWeight: 600, background: "var(--neutral-100)", color: "var(--text-secondary)" }}>
                                  {getMethodLabel(p.paymentMethod)}
                                </span>
                              );
                            })()}
                            {p.dueDate && p.gatewayStatus !== "paid" && (
                              <span style={{
                                padding: "2px 10px", borderRadius: "20px", fontSize: "0.75rem", fontWeight: 600,
                                background: "transparent", border: "1px dashed var(--color-border)", color: "var(--text-tertiary)",
                                display: "inline-flex", alignItems: "center", gap: "4px",
                              }}>
                                <Clock size={11} />
                                متوقعة: {getMethodLabel(p.paymentMethod)}
                              </span>
                            )}
                            {p.gatewayFeeAmount != null && p.gatewayFeeAmount > 0 && (
                              <span style={{ fontSize: "0.7rem", color: "var(--text-tertiary)" }}>
                                رسوم: {p.gatewayFeeAmount.toFixed(3)}
                              </span>
                            )}
                          </div>
                          <div className="contract-details-payment-meta" style={{ display: "flex", gap: "16px", fontSize: "0.8rem", color: "var(--text-tertiary)" }}>
                            <span>{p.dueDate ? `استحقاق: ${p.dueDate}` : formatDate(p.paymentDate)}</span>
                            {p.notes && <span>• {p.notes}</span>}
                          </div>
                        </div>
                        <div className="contract-details-payment-actions" style={{ display: "flex", gap: "8px", alignItems: "center", flexWrap: "wrap", justifyContent: "flex-end", flexShrink: 0 }}>
                          {/* Convert scheduled/unpaid payment to manually paid */}
                          {p.dueDate && p.gatewayStatus !== "paid" && (
                            <button
                              onClick={() => startConvertToPaid(p)}
                              title="تحويل لمدفوعة"
                              style={{
                                height: "36px", padding: "0 14px", borderRadius: "8px", fontSize: "0.8rem", fontWeight: 600,
                                border: "1px solid var(--color-primary)", background: "var(--primary-light)", color: "var(--color-primary)",
                                cursor: "pointer", display: "flex", alignItems: "center", gap: "6px",
                                whiteSpace: "nowrap", flexShrink: 0,
                              }}
                            >
                              <Check size={14} />
                              تحويل لمدفوعة
                            </button>
                          )}
                          {/* Send Now button for scheduled (not yet sent to gateway) */}
                          {p.dueDate && (!p.gatewayStatus || p.gatewayStatus === 'failed' || p.gatewayStatus === 'cancelled') && (
                            <button
                              onClick={() => handleSendGatewayPayment(p)}
                              disabled={sendingGatewayId === p.id}
                              title="إرسال رابط الدفع الآن"
                              style={{
                                height: "36px", padding: "0 14px", borderRadius: "8px", fontSize: "0.8rem", fontWeight: 600,
                                border: "1px solid var(--green-400)", background: "var(--green-600)", color: "#fff",
                                cursor: sendingGatewayId === p.id ? "wait" : "pointer",
                                display: "flex", alignItems: "center", gap: "6px",
                                whiteSpace: "nowrap", flexShrink: 0,
                              }}
                            >
                              {sendingGatewayId === p.id ? <Loader2 size={14} className="animate-spin" /> : <CreditCard size={14} />}
                              إرسال الآن
                            </button>
                          )}
                          {/* Edit the planned payment method of a scheduled/unpaid payment */}
                          {p.dueDate && p.gatewayStatus !== "paid" && (
                            <button
                              onClick={() => startEditMethod(p)}
                              title="تعديل طريقة الدفع المتوقعة"
                              style={{ width: "36px", height: "36px", borderRadius: "8px", border: "1px solid var(--color-primary)", background: "#fff", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center", color: "var(--color-primary)", flexShrink: 0 }}
                            >
                              <Pencil size={16} />
                            </button>
                          )}
                          {/* Copy gateway link */}
                          {p.gatewayStatus === "pending" && p.paymentGatewayUrl && (
                            <button
                              onClick={() => { navigator.clipboard.writeText(p.paymentGatewayUrl!); notify("تم نسخ الرابط"); }}
                              title="نسخ رابط الدفع"
                              style={{ width: "36px", height: "36px", borderRadius: "8px", border: "1px solid var(--color-border)", background: "var(--bg-subtle)", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center", color: "var(--text-secondary)", flexShrink: 0 }}
                            >
                              <Eye size={16} />
                            </button>
                          )}
                          {p.transferImageUrl && (
                            <button
                              onClick={() => setViewingImage(p.transferImageUrl!)}
                              title="عرض صورة التحويل"
                              style={{ width: "36px", height: "36px", borderRadius: "8px", border: "1px solid var(--color-border)", background: "var(--bg-subtle)", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center", color: "var(--text-secondary)", flexShrink: 0 }}
                            >
                              <ImageIcon size={16} />
                            </button>
                          )}
                          <button
                            onClick={() => handleDeletePayment(p.id)}
                            title="حذف الدفعة"
                            style={{ width: "36px", height: "36px", borderRadius: "8px", border: "1px solid var(--color-border)", background: "var(--bg-subtle)", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center", color: "var(--color-error)", flexShrink: 0, marginInlineStart: "4px" }}
                          >
                            <Trash2 size={16} />
                          </button>
                        </div>
                      </div>

                      {/* Inline "convert to paid" form */}
                      {convertingPaymentId === p.id && (
                        <div style={{
                          border: "1px solid var(--color-primary)", borderRadius: "10px",
                          padding: "14px", background: "var(--primary-light)",
                          display: "grid", gridTemplateColumns: "1fr 1fr", gap: "12px",
                        }}>
                          <div style={{ display: "flex", flexDirection: "column", gap: "6px" }}>
                            <label style={{ fontSize: "0.8rem", fontWeight: 500, color: "var(--text-secondary)" }}>طريقة الدفع</label>
                            <CustomSelect
                              value={convertMethod}
                              onChange={val => setConvertMethod(val as PaymentMethod)}
                              options={PAYMENT_METHODS.filter(m => m.value !== "gateway").map(m => ({ id: m.value, label: m.label }))}
                              placeholder="اختر طريقة الدفع"
                              width="100%"
                            />
                          </div>
                          <div style={{ display: "flex", flexDirection: "column", gap: "6px" }}>
                            <label style={{ fontSize: "0.8rem", fontWeight: 500, color: "var(--text-secondary)" }}>تاريخ الدفع</label>
                            <input
                              type="date"
                              value={convertDate}
                              onChange={e => setConvertDate(e.target.value)}
                              style={{ padding: "8px 10px", borderRadius: "8px", border: "1px solid var(--color-border)", fontSize: "0.85rem", outline: "none" }}
                            />
                          </div>
                          <div style={{ display: "flex", flexDirection: "column", gap: "6px" }}>
                            <label style={{ fontSize: "0.8rem", fontWeight: 500, color: "var(--text-secondary)" }}>صورة التحويل (اختياري)</label>
                            <input
                              ref={convertFileRef}
                              type="file"
                              accept="image/*"
                              style={{ display: "none" }}
                              onChange={e => {
                                const f = e.target.files?.[0];
                                if (f && f.type.startsWith("image/")) setConvertImageFile(f);
                                e.target.value = "";
                              }}
                            />
                            <button
                              type="button"
                              onClick={() => convertFileRef.current?.click()}
                              style={{
                                padding: "8px 10px", borderRadius: "8px", border: "1px solid var(--color-border)",
                                fontSize: "0.8rem", cursor: "pointer", display: "flex", alignItems: "center",
                                gap: "6px", background: convertImageFile ? "var(--green-50)" : "#fff",
                                color: convertImageFile ? "var(--color-success)" : "var(--text-secondary)",
                              }}
                            >
                              <Upload size={14} />
                              {convertImageFile ? convertImageFile.name : "اختر صورة..."}
                            </button>
                          </div>
                          <div style={{ display: "flex", flexDirection: "column", gap: "6px" }}>
                            <label style={{ fontSize: "0.8rem", fontWeight: 500, color: "var(--text-secondary)" }}>ملاحظات</label>
                            <input
                              type="text"
                              value={convertNotes}
                              onChange={e => setConvertNotes(e.target.value)}
                              style={{ padding: "8px 10px", borderRadius: "8px", border: "1px solid var(--color-border)", fontSize: "0.85rem", outline: "none" }}
                            />
                          </div>
                          <div style={{ gridColumn: "span 2", display: "flex", gap: "8px", justifyContent: "flex-end" }}>
                            <button
                              onClick={() => setConvertingPaymentId(null)}
                              style={{ padding: "8px 16px", borderRadius: "8px", border: "1px solid var(--color-border)", background: "#fff", cursor: "pointer", fontWeight: 600, fontSize: "0.85rem" }}
                            >
                              إلغاء
                            </button>
                            <button
                              onClick={() => handleConvertToPaid(p.id)}
                              disabled={convertingSaving || !convertDate || !convertMethod}
                              style={{
                                padding: "8px 18px", borderRadius: "8px", border: "none",
                                background: convertingSaving ? "var(--neutral-400)" : "var(--color-primary)",
                                color: "#fff", cursor: convertingSaving ? "wait" : "pointer", fontWeight: 600, fontSize: "0.85rem",
                                display: "flex", alignItems: "center", gap: "6px",
                              }}
                            >
                              {convertingSaving ? <Loader2 size={14} className="animate-spin" /> : <Check size={14} />}
                              {convertingSaving ? "جار الحفظ..." : "تأكيد الدفع"}
                            </button>
                          </div>
                        </div>
                      )}

                      {/* Inline "edit planned payment method" form */}
                      {editingMethodPaymentId === p.id && (
                        <div style={{
                          border: "1px solid var(--color-primary)", borderRadius: "10px",
                          padding: "14px", background: "var(--primary-light)",
                          display: "flex", flexDirection: "column", gap: "12px",
                        }}>
                          <div style={{ display: "flex", alignItems: "center", gap: "8px", fontWeight: 700, fontSize: "0.82rem", color: "var(--color-primary)" }}>
                            <Pencil size={14} />
                            تعديل الطريقة المتوقعة
                          </div>
                          <div style={{ display: "flex", gap: "12px", alignItems: "flex-end", flexWrap: "wrap" }}>
                            <div style={{ display: "flex", flexDirection: "column", gap: "6px", minWidth: "180px" }}>
                              <label style={{ fontSize: "0.8rem", fontWeight: 500, color: "var(--text-secondary)" }}>طريقة الدفع</label>
                              <CustomSelect
                                value={editMethodValue}
                                onChange={val => setEditMethodValue(val as PaymentMethod)}
                                options={PAYMENT_METHODS.filter(m => m.value !== "gateway").map(m => ({ id: m.value, label: m.label }))}
                                placeholder="اختر طريقة الدفع"
                                width="180px"
                              />
                            </div>
                            <div style={{ display: "flex", gap: "8px" }}>
                              <button
                                onClick={() => setEditingMethodPaymentId(null)}
                                style={{ padding: "8px 16px", borderRadius: "8px", border: "1px solid var(--color-border)", background: "#fff", cursor: "pointer", fontWeight: 600, fontSize: "0.85rem" }}
                              >
                                إلغاء
                              </button>
                              <button
                                onClick={() => handleSaveMethodEdit(p.id)}
                                disabled={savingMethodEdit || !editMethodValue}
                                style={{
                                  padding: "8px 18px", borderRadius: "8px", border: "none",
                                  background: savingMethodEdit ? "var(--neutral-400)" : "var(--color-primary)",
                                  color: "#fff", cursor: savingMethodEdit ? "wait" : "pointer", fontWeight: 600, fontSize: "0.85rem",
                                  display: "flex", alignItems: "center", gap: "6px",
                                }}
                              >
                                {savingMethodEdit ? <Loader2 size={14} className="animate-spin" /> : <Check size={14} />}
                                {savingMethodEdit ? "جار الحفظ..." : "حفظ"}
                              </button>
                            </div>
                          </div>
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              ) : (
                <div style={{
                  padding: "40px", textAlign: "center", color: "var(--text-tertiary)",
                  background: "var(--bg-card)", borderRadius: "12px",
                  border: "1px dashed var(--color-border)",
                }}>
                  <div style={{
                    width: "56px", height: "56px", borderRadius: "50%", background: "var(--neutral-100)",
                    margin: "0 auto 12px", display: "flex", alignItems: "center", justifyContent: "center",
                  }}>
                    <DollarSign size={28} style={{ opacity: 0.4 }} />
                  </div>
                  <p style={{ fontWeight: 600, color: "var(--text-secondary)", margin: "0 0 4px" }}>لا توجد دفعات</p>
                  <p style={{ margin: 0, fontSize: "0.85rem" }}>لم يتم تسجيل أي دفعات لهذا العقد حتى الآن.</p>
                </div>
              )}

              {/* Image Viewer Modal */}
              {viewingImage && (
                <div
                  onClick={() => setViewingImage(null)}
                  style={{
                    position: "fixed", inset: 0, background: "rgba(0,0,0,0.7)",
                    display: "flex", alignItems: "center", justifyContent: "center",
                    zIndex: 200, cursor: "pointer", backdropFilter: "blur(4px)",
                  }}
                >
                  <img
                    src={viewingImage}
                    alt="صورة التحويل"
                    style={{ maxWidth: "90%", maxHeight: "90%", borderRadius: "12px", objectFit: "contain" }}
                    onClick={e => e.stopPropagation()}
                  />
                </div>
              )}
            </div>
          )}

          {showCreateTask && (
            <CreateStandaloneTaskModal
              initialContractId={contract.id}
              initialLineId={contract.lineId}
              initialZoneId={contract.zoneId}
              onClose={() => setShowCreateTask(false)}
              onSuccess={async () => {
                setShowCreateTask(false);
                setActiveTab("tasks");
                await loadStandaloneTasks();
              }}
            />
          )}

          {editingStandaloneTaskId && (
            <StandaloneTaskDetailsPage
              taskId={editingStandaloneTaskId}
              onClose={async () => {
                setEditingStandaloneTaskId(null);
                await loadStandaloneTasks();
              }}
            />
          )}

          {viewingStandaloneTaskId && (
            <StandaloneTaskDetailsPage
              taskId={viewingStandaloneTaskId}
              viewOnly
              onClose={async () => {
                setViewingStandaloneTaskId(null);
                await loadStandaloneTasks();
              }}
            />
          )}
        </div>
      </div>
    </div>
  );
};
