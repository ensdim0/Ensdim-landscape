import React, { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { container } from "@infrastructure/di/container";
import { LoadingState, ErrorState } from "@presentation/components/States";
import { useToast } from "@presentation/components/ToastProvider";
import { StandaloneTask } from "@domain/entities/StandaloneTask";
import { User } from "@domain/entities/User";
import { Contract } from "@domain/entities/Contract";
import { Eye, Plus, Trash2, ChevronDown, ChevronUp, Pencil, Search } from "lucide-react";
import { CustomSelect } from "@presentation/components/CustomSelect";
import { CreateStandaloneTaskModal } from "./AssignTaskPage";
import { StandaloneTaskDetailsPage } from "./StandaloneTaskDetailsPage";
import { formatTime } from "@shared/utils/date";

const STATUS_OPTIONS = [
  { id: "ALL", label: "كل الحالات" },
  { id: "pending", label: "قيد الانتظار" },
  { id: "in_progress", label: "جاري التنفيذ" },
  { id: "completed", label: "مكتملة" },
  { id: "cancelled", label: "ملغاة" },
];

const PAYMENT_STATUS_OPTIONS = [
  { id: "ALL", label: "كل حالات الدفع" },
  { id: "paid", label: "مدفوع" },
  { id: "unpaid", label: "غير مدفوع" },
];

export const StandaloneTasksPage: React.FC = () => {
  const navigate = useNavigate();
  const { notify } = useToast();

  const [tasks, setTasks] = useState<StandaloneTask[]>([]);
  const [supervisors, setSupervisors] = useState<User[]>([]);
  const [contracts, setContracts] = useState<Contract[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [editingTaskId, setEditingTaskId] = useState<string | null>(null);
  const [viewingTaskId, setViewingTaskId] = useState<string | null>(null);

  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState("ALL");
  const [supervisorFilter, setSupervisorFilter] = useState("ALL");
  const [paymentFilter, setPaymentFilter] = useState("ALL");

  useEffect(() => {
    let mounted = true;
    const load = async () => {
      try {
        setLoading(true);
        const [t, s, ctrs] = await Promise.all([
          container.adminRepository.listStandaloneTasks(),
          container.adminRepository.listSupervisors(),
          container.adminRepository.listContracts(),
        ]);
        if (!mounted) return;
        setTasks(t);
        setSupervisors(s);
        setContracts(ctrs);
      } catch (e) {
        console.error(e);
        if (mounted) setError("تعذر تحميل المهام");
      } finally {
        if (mounted) setLoading(false);
      }
    };
    load();
    return () => {
      mounted = false;
    };
  }, []);

  const supervisorsMap = useMemo(() => {
    const m: Record<string, User> = {};
    supervisors.forEach((s) => (m[s.id] = s));
    return m;
  }, [supervisors]);

  const contractsMap = useMemo(() => {
    const m: Record<string, Contract> = {};
    contracts.forEach((c) => (m[c.id] = c));
    return m;
  }, [contracts]);

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

  const [isMobile, setIsMobile] = useState<boolean>(() => {
    if (typeof window === "undefined") return false;
    return window.matchMedia("(max-width: 768px)").matches;
  });

  useEffect(() => {
    if (typeof window === "undefined") return;
    const mq = window.matchMedia("(max-width: 768px)");
    const handler = (e: MediaQueryListEvent) => setIsMobile(e.matches);
    if (mq.addEventListener) mq.addEventListener("change", handler);
    else mq.addListener(handler as any);
    return () => {
      if (mq.removeEventListener) mq.removeEventListener("change", handler as any);
      else mq.removeListener(handler as any);
    };
  }, []);

  const [expandedId, setExpandedId] = useState<string | null>(null);

  const handleDelete = async (id: string) => {
    if (!confirm("هل تريد حذف هذه المهمة؟")) return;
    try {
      await container.adminRepository.deleteStandaloneTask(id);
      notify("تم حذف المهمة");
      setTasks((prev) => prev.filter((t) => t.id !== id));
    } catch (e) {
      notify("فشل حذف المهمة");
    }
  };

  const getStatusLabel = (status: string) => {
    const labels: Record<string, string> = {
      pending: "قيد الانتظار",
      in_progress: "جاري التنفيذ",
      completed: "مكتملة",
      cancelled: "ملغاة",
    };
    return labels[status] || status;
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case "completed":
        return "var(--color-success)";
      case "in_progress":
        return "var(--color-warning)";
      case "cancelled":
        return "var(--color-error)";
      default:
        return "var(--text-secondary)";
    }
  };

  const getStatusBg = (status: string) => {
    switch (status) {
      case "completed":
        return "var(--color-success-bg)";
      case "in_progress":
        return "var(--color-warning-bg)";
      case "cancelled":
        return "var(--color-error-bg)";
      default:
        return "var(--bg-subtle)";
    }
  };

  const PAYMENT_METHOD_LABELS: Record<string, string> = {
    cash: "نقدي",
    transfer: "رابط",
    cheque: "شيك",
    card: "ومض",
  };

  const getPaymentInfo = (task: StandaloneTask) => {
    if (task.paymentStatus === "paid") {
      return {
        label: "مدفوع",
        color: "var(--color-success)",
        bg: "var(--color-success-bg)",
        methodLabel: task.paymentMethod ? PAYMENT_METHOD_LABELS[task.paymentMethod] ?? task.paymentMethod : "—",
      };
    }
    return { label: "غير مدفوع", color: "var(--color-error)", bg: "var(--color-error-bg)", methodLabel: "—" };
  };

  const filteredTasks = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    const qDigits = q.replace(/\D/g, "");
    return tasks.filter((t) => {
      const supervisorName = t.supervisorId ? supervisorsMap[t.supervisorId]?.fullName ?? "" : "";
      const matchesSearch =
        !q ||
        t.title.toLowerCase().includes(q) ||
        (t.clientName ?? "").toLowerCase().includes(q) ||
        supervisorName.toLowerCase().includes(q) ||
        (qDigits && (t.clientPhone ?? "").replace(/\D/g, "").includes(qDigits));
      const matchesStatus = statusFilter === "ALL" || t.status === statusFilter;
      const matchesSupervisor = supervisorFilter === "ALL" || t.supervisorId === supervisorFilter;
      const matchesPayment = paymentFilter === "ALL" || t.paymentStatus === paymentFilter;
      return matchesSearch && matchesStatus && matchesSupervisor && matchesPayment;
    });
  }, [tasks, searchQuery, statusFilter, supervisorFilter, paymentFilter, supervisorsMap]);

  if (loading) return <LoadingState />;
  if (error) return <ErrorState text={error} />;

  const containerPadding = isMobile ? 16 : 32;
  const headerStyle: React.CSSProperties = isMobile
    ? { display: "flex", flexDirection: "column", gap: 12, alignItems: "flex-start" }
    : { display: "flex", justifyContent: "space-between", alignItems: "center" };

  return (
    <div style={{ padding: containerPadding, display: "flex", flexDirection: "column", gap: isMobile ? 16 : 24 }}>
      <div style={headerStyle}>
        <div>
          <h1 style={{ margin: 0, fontSize: "1.5rem", fontWeight: 800, color: "var(--text-primary)" }}>
            المهام المستقلة
          </h1>
          <p style={{ margin: "6px 0 0", color: "var(--text-tertiary)", fontSize: isMobile ? "0.9rem" : undefined }}>
            عرض وإدارة المهام المستقلة المسندة للمشرفين
          </p>
        </div>

        <button
          className="button primary"
          onClick={() => setShowCreateModal(true)}
          style={{ display: "inline-flex", alignItems: "center", gap: 8 }}
        >
          <Plus size={16} />
          إنشاء مهمة جديدة
        </button>
      </div>

      <div
        className="card"
        style={{
          padding: isMobile ? 12 : 16,
          display: "flex",
          flexWrap: "wrap",
          gap: 10,
          alignItems: "center",
          border: "1px solid var(--color-border)",
        }}
      >
        <div style={{ position: "relative", flex: "1 1 240px", minWidth: 200 }}>
          <Search size={16} style={{ position: "absolute", top: "50%", transform: "translateY(-50%)", right: 12, color: "var(--text-tertiary)" }} />
          <input
            type="text"
            className="input"
            placeholder="بحث بالاسم، العميل، الهاتف، أو المشرف..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            style={{ width: "100%", paddingRight: 36, height: 40, borderRadius: "var(--radius-md)", borderColor: "var(--color-border)" }}
          />
        </div>

        <CustomSelect value={statusFilter} onChange={setStatusFilter} options={STATUS_OPTIONS} placeholder="كل الحالات" width="160px" />
        <CustomSelect
          value={supervisorFilter}
          onChange={setSupervisorFilter}
          options={[{ id: "ALL", label: "كل المشرفين" }, ...supervisors.map((s) => ({ id: s.id, label: s.fullName }))]}
          placeholder="كل المشرفين"
          width="180px"
          searchable
        />
        <CustomSelect value={paymentFilter} onChange={setPaymentFilter} options={PAYMENT_STATUS_OPTIONS} placeholder="كل حالات الدفع" width="170px" />

        <div style={{ marginInlineStart: "auto", color: "var(--text-tertiary)", fontSize: "0.85rem", whiteSpace: "nowrap" }}>
          {filteredTasks.length} من {tasks.length} مهمة
        </div>
      </div>

      <div className="card" style={{ padding: 0, overflow: "hidden" }}>
        {isMobile ? (
          <div>
            {filteredTasks.length === 0 ? (
              <div style={{ padding: 16, textAlign: "center", color: "var(--text-tertiary)" }}>
                {tasks.length === 0 ? "لا توجد مهام حالياً. ابدأ بإنشاء مهمة جديدة!" : "لا توجد نتائج مطابقة للبحث/الفلترة"}
              </div>
            ) : (
              filteredTasks.map((t) => {
                const expanded = expandedId === t.id;
                return (
                  <div
                    key={t.id}
                    style={{
                      padding: 10,
                      borderBottom: "1px solid var(--color-border)",
                      display: "flex",
                      flexDirection: "column",
                      gap: 6,
                    }}
                  >
                    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: 8 }}>
                      <div style={{ display: "flex", gap: 8, alignItems: "center", minWidth: 0, flex: 1 }}>
                        <div style={{ flex: 1, minWidth: 0 }}>
                          <div style={{ fontWeight: 800, color: "var(--text-primary)", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{t.title}</div>
                          <div style={{ color: "var(--text-tertiary)", fontSize: "0.85rem", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
                            {t.clientName || "—"} • {formatShortTimestamp(t)}
                          </div>
                          {t.supervisorReport ? (
                            <div title={t.supervisorReport} style={{ color: "var(--text-secondary)", fontSize: "0.82rem", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis", marginTop: 4 }}>
                              {t.supervisorReport.length > 70 ? t.supervisorReport.substring(0, 70) + '...' : t.supervisorReport}
                            </div>
                          ) : null}
                        </div>
                        <span style={{ ...badgeStyle(getStatusColor(t.status), getStatusBg(t.status)), marginLeft: 8 }}>{getStatusLabel(t.status)}</span>
                      </div>

                      <div style={{ display: "flex", gap: 6, alignItems: "center" }}>
                        <button className="button icon-only" onClick={() => setViewingTaskId(t.id)} aria-label="عرض" style={{ padding: 6 }}>
                          <Eye size={16} />
                        </button>
                        <button className="button icon-only" onClick={() => setEditingTaskId(t.id)} aria-label="تعديل" style={{ padding: 6 }}>
                          <Pencil size={16} />
                        </button>
                        <button className="button icon-only" onClick={() => handleDelete(t.id)} aria-label="حذف" style={{ padding: 6, background: "var(--color-error-bg)", color: "var(--color-error)" }}>
                          <Trash2 size={16} />
                        </button>
                        <button className="button icon-only" onClick={() => setExpandedId(expanded ? null : t.id)} aria-label={expanded ? "طي" : "تفاصيل"} style={{ padding: 6 }}>
                          {expanded ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
                        </button>
                      </div>
                    </div>

                    {expanded && (
                      <div style={{ marginTop: 6, display: "flex", flexDirection: "column", gap: 8 }}>
                        {t.description && <div style={{ color: "var(--text-tertiary)", fontSize: "0.95rem" }}>{t.description}</div>}
                        {(t as any).supervisorReport && (
                          <div style={{ background: "var(--bg-subtle)", padding: 8, borderRadius: 6, color: "var(--text-primary)" }}>
                            <strong style={{ display: "block", marginBottom: 6 }}>تقرير المشرف</strong>
                            <div style={{ whiteSpace: "pre-wrap" }}>{(t as any).supervisorReport}</div>
                          </div>
                        )}
                        <div style={{ display: "flex", gap: 12, flexWrap: "wrap", color: "var(--text-primary)", fontSize: "0.95rem", justifyContent: "space-between" }}>
                          <div style={{ minWidth: 0 }}>
                            <div><strong style={{ fontWeight: 700, marginRight: 6 }}>المشرف:</strong> {t.supervisorId ? supervisorsMap[t.supervisorId]?.fullName || "—" : "—"}</div>
                            <div><strong style={{ fontWeight: 700, marginRight: 6 }}>الهاتف:</strong> {t.clientPhone || "—"}</div>
                            <div><strong style={{ fontWeight: 700, marginRight: 6 }}>العقد:</strong> {(t as any).contractId ? (contractsMap[(t as any).contractId]?.code ?? "—") : "—"}</div>
                            <div><strong style={{ fontWeight: 700, marginRight: 6 }}>التكلفة:</strong> {(t as any).cost != null ? Number((t as any).cost).toFixed(2) + ' د.ك' : "—"}</div>
                            <div><strong style={{ fontWeight: 700, marginRight: 6 }}>حالة الدفع:</strong> <span style={badgeStyle(getPaymentInfo(t).color, getPaymentInfo(t).bg)}>{getPaymentInfo(t).label}</span></div>
                            <div><strong style={{ fontWeight: 700, marginRight: 6 }}>طريقة الدفع:</strong> {getPaymentInfo(t).methodLabel}</div>
                          </div>
                          <div style={{ display: "flex", gap: 8 }}>
                            <button className="button secondary" onClick={() => setEditingTaskId(t.id)} style={{ display: "inline-flex", alignItems: "center", gap: 8, padding: "6px 12px" }}>
                              <Pencil size={14} /> تعديل
                            </button>
                          </div>
                        </div>
                      </div>
                    )}
                  </div>
                );
              })
            )}
          </div>
        ) : (
          <div className="dashboard-table-wrap">
            <table className="dashboard-table" style={{ minWidth: "1100px" }}>
              <thead>
                <tr>
                  <th>المهمة</th>
                  <th>العميل</th>
                  <th>الهاتف</th>
                  <th>المشرف</th>
                  <th>التاريخ</th>
                  <th>العقد</th>
                  <th>تقرير المشرف</th>
                  <th>التكلفة</th>
                  <th style={{ textAlign: "center" }}>حالة الدفع</th>
                  <th style={{ textAlign: "center" }}>طريقة الدفع</th>
                  <th style={{ textAlign: "center" }}>الحالة</th>
                  <th style={{ textAlign: "center" }}>الإجراءات</th>
                </tr>
              </thead>
              <tbody>
                {filteredTasks.length === 0 ? (
                  <tr>
                    <td colSpan={12} className="dashboard-empty">
                      {tasks.length === 0 ? "لا توجد مهام حالياً. ابدأ بإنشاء مهمة جديدة!" : "لا توجد نتائج مطابقة للبحث/الفلترة"}
                    </td>
                  </tr>
                ) : (
                filteredTasks.map((t) => (
                  <tr key={t.id}>
                    <td style={{ whiteSpace: "normal" }}>
                      <div style={{ fontWeight: 600 }}>{t.title}</div>
                      {t.description && (
                        <p className="muted" style={{ margin: "4px 0 0 0", fontSize: "0.78rem" }}>
                          {t.description.substring(0, 50)}...
                        </p>
                      )}
                    </td>
                    <td>{t.clientName || "—"}</td>
                    <td>{t.clientPhone || "—"}</td>
                    <td>{t.supervisorId ? supervisorsMap[t.supervisorId]?.fullName || "—" : "—"}</td>
                    <td>{renderTaskTimestamp(t)}</td>
                    <td>{(t as any).contractId ? (contractsMap[(t as any).contractId]?.code ?? "—") : "—"}</td>
                    <td className="muted" style={{ whiteSpace: "normal" }} title={t.supervisorReport ?? ''}>{t.supervisorReport ? (t.supervisorReport.length > 80 ? t.supervisorReport.substring(0, 80) + '...' : t.supervisorReport) : '—'}</td>
                    <td>{(t as any).cost != null ? Number((t as any).cost).toFixed(2) + ' د.ك' : "—"}</td>
                    <td style={{ textAlign: "center" }}>
                      <span style={badgeStyle(getPaymentInfo(t).color, getPaymentInfo(t).bg)}>
                        {getPaymentInfo(t).label}
                      </span>
                    </td>
                    <td style={{ textAlign: "center" }}>{getPaymentInfo(t).methodLabel}</td>
                    <td style={{ textAlign: "center" }}>
                      <span style={badgeStyle(getStatusColor(t.status), getStatusBg(t.status))}>
                        {getStatusLabel(t.status)}
                      </span>
                    </td>
                    <td style={{ textAlign: "center" }}>
                      <div style={{ display: "flex", gap: 8, justifyContent: "center" }}>
                      <button
                        className="button secondary"
                        onClick={() => setViewingTaskId(t.id)}
                        title="عرض"
                        style={{ display: "inline-flex", alignItems: "center", justifyContent: "center", padding: 6, width: 30, height: 30 }}
                      >
                        <Eye size={14} />
                      </button>
                      <button
                        className="button secondary"
                        onClick={() => setEditingTaskId(t.id)}
                        title="تعديل"
                        style={{ display: "inline-flex", alignItems: "center", justifyContent: "center", padding: 6, width: 30, height: 30 }}
                      >
                        <Pencil size={14} />
                      </button>
                      <button
                        className="button"
                        onClick={() => handleDelete(t.id)}
                        title="حذف"
                        style={{
                          display: "inline-flex",
                          alignItems: "center",
                          justifyContent: "center",
                          padding: 6,
                          width: 30,
                          height: 30,
                          background: "var(--color-error-bg)",
                          color: "var(--color-error)",
                          border: "none",
                          cursor: "pointer",
                          borderRadius: 6,
                        }}
                      >
                        <Trash2 size={14} />
                      </button>
                      </div>
                    </td>
                  </tr>
                ))
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {showCreateModal && (
        <CreateStandaloneTaskModal
          onClose={() => setShowCreateModal(false)}
          onSuccess={async () => {
            setShowCreateModal(false);
            // Reload tasks
            try {
              const updated = await container.adminRepository.listStandaloneTasks();
              setTasks(updated);
            } catch (e) {
              console.error(e);
            }
          }}
        />
      )}

      {editingTaskId && (
        <StandaloneTaskDetailsPage
          taskId={editingTaskId}
          onClose={async () => {
            setEditingTaskId(null);
            // Reload tasks
            try {
              const updated = await container.adminRepository.listStandaloneTasks();
              setTasks(updated);
            } catch (e) {
              console.error(e);
            }
          }}
        />
      )}
      {viewingTaskId && (
        <StandaloneTaskDetailsPage
          taskId={viewingTaskId}
          viewOnly
          onClose={async () => {
            setViewingTaskId(null);
            try {
              const updated = await container.adminRepository.listStandaloneTasks();
              setTasks(updated);
            } catch (e) {
              console.error(e);
            }
          }}
        />
      )}
    </div>
  );
};

const badgeStyle = (color: string, bg: string): React.CSSProperties => ({
  display: "inline-block",
  padding: "3px 10px",
  borderRadius: 999,
  fontSize: "0.78rem",
  fontWeight: 700,
  color,
  background: bg,
});
