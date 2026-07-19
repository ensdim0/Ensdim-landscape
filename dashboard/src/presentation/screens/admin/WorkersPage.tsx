import { useEffect, useRef, useState } from "react";
import { container } from "@infrastructure/di/container";
import { Worker } from "@domain/entities/Worker";
import { LoadingState, ErrorState } from "@presentation/components/States";
import { useToast } from "@presentation/components/ToastProvider";
import { useTour } from "@presentation/components/tour/useTour";
import { useSearchParams } from "react-router-dom";
import { syncWorkerVisaNotifications } from "@presentation/notifications/syncWorkerVisaNotifications";
import {
  HardHat,
  Plus,
  X,
  Save,
  Pencil,
  Trash2,
  Loader2,
  Search,
  Phone,
  Calendar,
  DollarSign,
  FileText,
  AlertTriangle,
  Users,
} from "lucide-react";

const formatDate = (d: string) => {
  if (!d) return "—";
  return new Date(d).toLocaleDateString("ar-EG", { year: "numeric", month: "short", day: "numeric" });
};

const daysUntil = (d: string) => {
  const diff = Math.ceil((new Date(d).getTime() - Date.now()) / 86400000);
  return diff;
};

export const WorkersPage = () => {
  const [workers, setWorkers] = useState<Worker[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [visaFilter, setVisaFilter] = useState<"all" | "valid" | "expiring" | "expired">("all");
  const [searchParams] = useSearchParams();
  const workerIdFromNotification = searchParams.get("workerId");
  const openedWorkerIdRef = useRef<string | null>(null);

  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [editingWorker, setEditingWorker] = useState<Worker | null>(null);
  const [confirmDelete, setConfirmDelete] = useState<{ worker: Worker } | null>(null);
  const [deleting, setDeleting] = useState(false);

  const { notify } = useToast();
  const repo = container.workerRepository;

  const loadData = async () => {
    try {
      setLoading(true);
      await syncWorkerVisaNotifications();
      const data = await repo.listWorkers();
      setWorkers(data);
    } catch (e: any) {
      console.error("Worker load error:", e);
      setError("تعذر تحميل بيانات العمالة: " + (e?.message || ""));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { loadData(); }, []);

  const handleCreate = async (data: any) => {
    try {
      await repo.createWorker(data);
      notify("تم إضافة العامل بنجاح");
      setIsCreateOpen(false);
      loadData();
    } catch (e: any) {
      console.error("Worker create error:", e);
      notify("فشل إضافة العامل: " + (e?.message || "خطأ غير معروف"));
    }
  };

  const handleUpdate = async (data: any) => {
    try {
      await repo.updateWorker(data);
      notify("تم تحديث بيانات العامل");
      setEditingWorker(null);
      loadData();
    } catch {
      notify("فشل تحديث بيانات العامل");
    }
  };

  const handleDelete = async () => {
    if (!confirmDelete) return;
    setDeleting(true);
    try {
      await repo.deleteWorker(confirmDelete.worker.id);
      notify("تم حذف العامل");
      setConfirmDelete(null);
      loadData();
    } catch {
      notify("فشل حذف العامل");
    } finally {
      setDeleting(false);
    }
  };

  const filtered = workers.filter((w) => {
    const matchesSearch = w.name.includes(search) || w.phone.includes(search);
    if (!matchesSearch) return false;

    const days = daysUntil(w.visaEnd);
    const visaStatus = days < 0 ? "expired" : days <= 30 ? "expiring" : "valid";
    if (visaFilter === "valid" && visaStatus !== "valid") return false;
    if (visaFilter === "expiring" && visaStatus !== "expiring") return false;
    if (visaFilter === "expired" && visaStatus !== "expired") return false;

    return true;
  });

  const totalMonthlySalary = workers.reduce((sum, w) => sum + w.salary, 0);
  const expiringVisa = workers.filter((w) => {
    const d = daysUntil(w.visaEnd);
    return d >= 0 && d <= 30;
  });
  const expiredVisa = workers.filter((w) => daysUntil(w.visaEnd) < 0);

  useEffect(() => {
    if (loading || !workerIdFromNotification) return;
    if (openedWorkerIdRef.current === workerIdFromNotification) return;

    const worker = workers.find((item) => item.id === workerIdFromNotification);
    if (!worker) return;

    openedWorkerIdRef.current = workerIdFromNotification;
    setEditingWorker(worker);
  }, [loading, workerIdFromNotification, workers]);

  useTour(
    "admin-workers",
    loading || error
      ? []
      : [
          {
            target: ".workers-page-header",
            title: "إدارة العمالة",
            content: "من هنا تشوف عدد العمالة المسجلة وتضيف عامل جديد.",
          },
          {
            target: ".workers-page-stats",
            title: "تنبيهات التأشيرة",
            content: "إجمالي الرواتب الشهرية، وعدد العمال اللي تأشيرتهم قربت تنتهي أو انتهت بالفعل.",
          },
          {
            target: ".workers-page-table-card",
            title: "قائمة العمالة",
            content: "من هنا تعدّل بيانات أي عامل أو تحذفه.",
          },
        ]
  );

  if (loading) return <LoadingState />;
  if (error) return <ErrorState text={error} />;

  return (
    <div className="workers-page" style={{ position: "relative", height: "calc(100vh - 140px)", overflow: "hidden", display: "flex", flexDirection: "column", gap: "16px" }}>
      {/* Header */}
      <div className="workers-page-header" style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "0px", padding: "0 4px", flexShrink: 0 }}>
        <h2 className="workers-page-title" style={{ margin: 0, display: "flex", alignItems: "center", gap: "12px", fontSize: "1.25rem", color: "#1a2a10", fontWeight: 800 }}>
          <div style={{ padding: "8px", background: "#eef3e8", borderRadius: "8px", color: "var(--primary)", display: "flex" }}>
            <HardHat size={24} />
          </div>
          إدارة العمالة
          <span style={{ fontSize: "0.85rem", color: "#b0b8ae", fontWeight: "400" }}>({workers.length})</span>
        </h2>
        <button className="button workers-page-create-button" onClick={() => setIsCreateOpen(true)}>
          <Plus size={18} /> إضافة عامل
        </button>
      </div>

      {/* Toolbar Section - Filters & Search */}
      <div className="workers-page-toolbar" style={{
        backgroundColor: 'var(--bg-card)',
        padding: '16px',
        borderRadius: 'var(--radius-lg)',
        boxShadow: 'var(--shadow-sm)',
        display: 'flex',
        flexWrap: 'wrap',
        gap: '16px',
        alignItems: 'center',
        border: '1px solid var(--color-border)'
      }}>
        {/* Search */}
        <div className="workers-page-search" style={{ flex: 1, minWidth: '240px', position: 'relative' }}>
          <Search size={18} style={{ position: 'absolute', top: '50%', transform: 'translateY(-50%)', right: '12px', color: 'var(--text-tertiary)' }} />
          <input
            className="input workers-page-search-input"
            placeholder="بحث بالاسم أو الرقم..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            style={{
              width: '100%',
              paddingRight: '40px',
              borderRadius: 'var(--radius-md)',
              borderColor: 'var(--color-border)',
              height: '42px'
            }}
          />
        </div>

        {/* Visa Status Filter Buttons */}
        <div className="workers-page-filters" style={{ display: 'flex', background: 'var(--neutral-50)', padding: '4px', borderRadius: 'var(--radius-md)', border: '1px solid var(--color-border)' }}>
          {[
            { id: 'all', label: 'الكل' },
            { id: 'valid', label: 'سارية' },
            { id: 'expiring', label: 'تنتهي قريباً' },
            { id: 'expired', label: 'منتهية' }
          ].map((filter) => (
            <button
              key={filter.id}
              className="workers-page-filter-button"
              onClick={() => setVisaFilter(filter.id as any)}
              style={{
                padding: '6px 12px',
                borderRadius: '6px',
                fontSize: '0.85rem',
                fontWeight: 500,
                color: visaFilter === filter.id ? 'var(--text-on-primary)' : 'var(--text-secondary)',
                backgroundColor: visaFilter === filter.id ? 
                  (filter.id === 'expired' ? '#dc2626' : filter.id === 'expiring' ? '#d97706' : filter.id === 'valid' ? '#16a34a' : 'var(--color-primary)') 
                  : 'transparent',
                border: 'none',
                cursor: 'pointer',
                transition: 'all 0.2s'
              }}
            >
              {filter.label}
            </button>
          ))}
        </div>
      </div>

      {/* Stats */}
      <div className="workers-page-stats" style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))", gap: "12px", marginBottom: "0px", flexShrink: 0 }}>
        <StatCard className="workers-page-stat-card" icon={Users} label="إجمالي العمالة" value={workers.length} color="#30461F" bg="#eef3e8" />
        <StatCard className="workers-page-stat-card" icon={DollarSign} label="إجمالي المرتبات / شهر" value={`${totalMonthlySalary.toLocaleString()} د.ك`} color="#EA8E20" bg="#fef6eb" />
        <StatCard className="workers-page-stat-card" icon={AlertTriangle} label="تأشيرة تنتهي قريباً" value={expiringVisa.length} color="#d97706" bg="#fffbeb" />
        <StatCard className="workers-page-stat-card" icon={Calendar} label="تأشيرة منتهية" value={expiredVisa.length} color="#dc2626" bg="#fef2f2" />
      </div>

      {/* Table */}
      <div className="card workers-page-table-card" style={{ padding: 0, overflow: "hidden", flex: 1, display: "flex", flexDirection: "column", border: "1px solid #e4e0d8", minHeight: 0 }}>
        <div className="workers-page-table-scroll" style={{ overflowY: "auto", height: "100%" }}>
          <table className="table workers-page-table" style={{ margin: 0, width: "100%", borderCollapse: "separate", borderSpacing: 0 }}>
            <thead className="workers-page-table-head" style={{ position: "sticky", top: 0, zIndex: 10, background: "#FBF9F5" }}>
              <tr>
                <Th>الاسم</Th>
                <Th>رقم الموبايل</Th>
                <Th>بداية التأشيرة</Th>
                <Th>نهاية التأشيرة</Th>
                <Th>حالة التأشيرة</Th>
                <Th>المرتب</Th>
                <Th>ملاحظات</Th>
                <Th center>الإجراءات</Th>
              </tr>
            </thead>
            <tbody className="workers-page-table-body">
              {filtered.length === 0 && (
                <tr className="workers-page-empty-row">
                  <td colSpan={8} style={{ textAlign: "center", padding: "48px", color: "#b0b8ae" }}>لا توجد بيانات عمالة</td>
                </tr>
              )}
              {filtered.map((w) => {
                const days = daysUntil(w.visaEnd);
                const isExpired = days < 0;
                const isExpiring = days >= 0 && days <= 30;
                return (
                  <tr key={w.id} className="workers-page-row" style={{ background: "white", borderBottom: "1px solid #f5f3ef" }}>
                    <td className="workers-page-cell workers-page-cell-name" data-label="الاسم" style={{ padding: "16px", fontWeight: "700", color: "#1a2a10" }}>
                      <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
                        <div style={{
                          width: "32px", height: "32px", borderRadius: "50%", flexShrink: 0,
                          background: "#eef3e8", color: "#30461F", display: "flex",
                          alignItems: "center", justifyContent: "center", fontSize: "0.8rem", fontWeight: "700"
                        }}>
                          {w.name.charAt(0)}
                        </div>
                        {w.name}
                      </div>
                    </td>
                    <td className="workers-page-cell workers-page-cell-phone" data-label="رقم الموبايل" style={{ padding: "16px", color: "#2d3a2a", fontSize: "0.9rem", direction: "ltr", textAlign: "right" }}>
                      {w.phone}
                    </td>
                    <td className="workers-page-cell workers-page-cell-visa-start" data-label="بداية التأشيرة" style={{ padding: "16px", color: "#7c857a", fontSize: "0.85rem" }}>
                      {formatDate(w.visaStart)}
                    </td>
                    <td className="workers-page-cell workers-page-cell-visa-end" data-label="نهاية التأشيرة" style={{ padding: "16px", color: "#7c857a", fontSize: "0.85rem" }}>
                      {formatDate(w.visaEnd)}
                    </td>
                    <td className="workers-page-cell workers-page-cell-status" data-label="حالة التأشيرة" style={{ padding: "16px" }}>
                      {isExpired ? (
                        <span style={{ display: "inline-block", padding: "4px 10px", borderRadius: "20px", fontSize: "0.8rem", fontWeight: "600", background: "#fee2e2", color: "#dc2626", border: "1px solid #fecaca" }}>
                          منتهية ({Math.abs(days)} يوم)
                        </span>
                      ) : isExpiring ? (
                        <span style={{ display: "inline-block", padding: "4px 10px", borderRadius: "20px", fontSize: "0.8rem", fontWeight: "600", background: "#fffbeb", color: "#d97706", border: "1px solid #fef3c7" }}>
                          تنتهي خلال {days} يوم
                        </span>
                      ) : (
                        <span style={{ display: "inline-block", padding: "4px 10px", borderRadius: "20px", fontSize: "0.8rem", fontWeight: "600", background: "#eef3e8", color: "#30461F", border: "1px solid #dce8d0" }}>
                          سارية ({days} يوم)
                        </span>
                      )}
                    </td>
                    <td className="workers-page-cell workers-page-cell-salary" data-label="المرتب" style={{ padding: "16px", fontWeight: "700", color: "#1a2a10" }}>
                      {w.salary.toLocaleString()} <span style={{ fontWeight: "400", color: "#b0b8ae", fontSize: "0.8rem" }}>د.ك</span>
                    </td>
                    <td className="workers-page-cell workers-page-cell-notes" data-label="ملاحظات" style={{ padding: "16px", color: "#7c857a", fontSize: "0.85rem", maxWidth: "180px", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                      {w.notes || <span style={{ color: "#d4cfc5" }}>—</span>}
                    </td>
                    <td className="workers-page-cell workers-page-cell-actions" data-label="الإجراءات" style={{ textAlign: "center", padding: "16px" }}>
                      <div className="workers-page-actions" style={{ display: "flex", gap: "8px", justifyContent: "center" }}>
                        <button className="icon-button" title="تعديل" onClick={() => setEditingWorker(w)}><Pencil size={18} /></button>
                        <button className="icon-button" title="حذف" onClick={() => setConfirmDelete({ worker: w })} style={{ color: "#ef4444" }}><Trash2 size={18} /></button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* Modals */}
      {isCreateOpen && <WorkerFormModal title="إضافة عامل جديد" onClose={() => setIsCreateOpen(false)} onSubmit={handleCreate} />}
      {editingWorker && <WorkerFormModal title="تعديل بيانات العامل" worker={editingWorker} onClose={() => setEditingWorker(null)} onSubmit={handleUpdate} />}
      {confirmDelete && (
        <ConfirmDeleteModal
          name={confirmDelete.worker.name}
          loading={deleting}
          onConfirm={handleDelete}
          onClose={() => !deleting && setConfirmDelete(null)}
        />
      )}
    </div>
  );
};


const Th = ({ children, center }: { children: React.ReactNode; center?: boolean }) => (
  <th style={{ padding: "16px", color: "#7c857a", fontSize: "0.85rem", fontWeight: "600", borderBottom: "1px solid #e4e0d8", background: "#FBF9F5", textAlign: center ? "center" : undefined, whiteSpace: "nowrap" }}>{children}</th>
);

const StatCard = ({ icon: Icon, label, value, color, bg, className }: any) => (
  <div className={`card ${className ?? ""}`.trim()} style={{ padding: "16px 20px", display: "flex", alignItems: "center", gap: "14px" }}>
    <div style={{ width: "42px", height: "42px", borderRadius: "10px", background: bg, display: "flex", alignItems: "center", justifyContent: "center" }}>
      <Icon size={22} color={color} />
    </div>
    <div>
      <div style={{ fontSize: "0.8rem", color: "#7c857a", fontWeight: "500" }}>{label}</div>
      <div style={{ fontSize: "1.15rem", fontWeight: "800", color: "#1a2a10", marginTop: "2px" }}>{value}</div>
    </div>
  </div>
);

const WorkerFormModal = ({ title, worker, onClose, onSubmit }: {
  title: string; worker?: Worker; onClose: () => void;
  onSubmit: (data: any) => void;
}) => {
  const [name, setName] = useState(worker?.name || "");
  const [phone, setPhone] = useState(worker?.phone || "");
  const [visaStart, setVisaStart] = useState(worker?.visaStart || "");
  const [visaEnd, setVisaEnd] = useState(worker?.visaEnd || "");
  const [salary, setSalary] = useState(worker?.salary?.toString() || "");
  const [notes, setNotes] = useState(worker?.notes || "");
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim() || !phone.trim() || !visaStart || !visaEnd || !salary) return;
    setSubmitting(true);
    await onSubmit({
      ...(worker ? { id: worker.id } : {}),
      name: name.trim(),
      phone: phone.trim(),
      visaStart,
      visaEnd,
      salary: Number(salary),
      notes: notes.trim() || null,
    });
    setSubmitting(false);
  };

  return (
    <Modal title={title} onClose={onClose} overlayClassName="workers-modal-overlay" modalClassName="workers-modal-card">
      <form className="workers-modal-form" onSubmit={handleSubmit} style={{ display: "flex", flexDirection: "column", gap: "20px" }}>
        <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
          <FormField label="اسم العامل" icon={HardHat} required>
            <input className="input" placeholder="الاسم الكامل" value={name} onChange={(e) => setName(e.target.value)}
              style={{ paddingRight: "40px", borderColor: "#e4e0d8" }} />
          </FormField>
          <FormField label="رقم الموبايل" icon={Phone} required>
            <input className="input" placeholder="مثال: +96550012345" value={phone} onChange={(e) => setPhone(e.target.value)}
              style={{ paddingRight: "40px", borderColor: "#e4e0d8" }} />
          </FormField>
          <div className="workers-modal-date-grid" style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "12px" }}>
            <FormField label="بداية التأشيرة" icon={Calendar} required>
              <input type="date" className="input" value={visaStart} onChange={(e) => setVisaStart(e.target.value)}
                style={{ paddingRight: "40px", borderColor: "#e4e0d8" }} />
            </FormField>
            <FormField label="نهاية التأشيرة" icon={Calendar} required>
              <input type="date" className="input" value={visaEnd} onChange={(e) => setVisaEnd(e.target.value)}
                style={{ paddingRight: "40px", borderColor: "#e4e0d8" }} />
            </FormField>
          </div>
          <FormField label="المرتب (د.ك)" icon={DollarSign} required>
            <input type="number" className="input" placeholder="0" value={salary} onChange={(e) => setSalary(e.target.value)}
              min="0" step="0.5" style={{ paddingRight: "40px", borderColor: "#e4e0d8" }} />
          </FormField>
          <FormField label="ملاحظات" icon={FileText}>
            <textarea className="input" placeholder="ملاحظات إضافية (اختياري)..." value={notes} onChange={(e) => setNotes(e.target.value)}
              rows={2} style={{ paddingRight: "40px", borderColor: "#e4e0d8", resize: "vertical" }} />
          </FormField>
        </div>
        <div className="workers-modal-actions" style={{ display: "flex", gap: "12px", marginTop: "8px", borderTop: "1px solid #f5f3ef", paddingTop: "16px" }}>
          <button className="button" style={{ flex: 1, justifyContent: "center" }} type="submit" disabled={submitting}>
            {submitting ? <Loader2 size={18} className="spin" /> : worker ? <Save size={18} /> : <Plus size={18} />}
            {submitting ? "جار الحفظ..." : worker ? "حفظ التغييرات" : "إضافة العامل"}
          </button>
          <button className="button secondary" type="button" onClick={onClose} disabled={submitting}>إلغاء</button>
        </div>
      </form>
    </Modal>
  );
};

const FormField = ({ label, icon: Icon, required, children }: { label: string; icon: any; required?: boolean; children: React.ReactNode }) => (
  <label style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
    <span style={{ fontSize: "0.9rem", fontWeight: "600", color: "#2d3a2a" }}>
      {label} {required && <span style={{ color: "red" }}>*</span>}
    </span>
    <div style={{ position: "relative" }}>
      <Icon size={18} style={{ position: "absolute", top: "10px", right: "12px", color: "#b0b8ae" }} />
      {children}
    </div>
  </label>
);

const Modal = ({ title, onClose, children, overlayClassName, modalClassName }: {
  title: string;
  onClose: () => void;
  children: React.ReactNode;
  overlayClassName?: string;
  modalClassName?: string;
}) => (
  <div className={overlayClassName} style={{ position: "fixed", inset: 0, background: "rgba(0,0,0,0.5)", backdropFilter: "blur(4px)", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 100 }}>
    <div className={`card ${modalClassName ?? ""}`.trim()} style={{ width: "100%", maxWidth: "500px", maxHeight: "90vh", overflowY: "auto", padding: "24px" }}>
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

const ConfirmDeleteModal = ({ name, loading, onConfirm, onClose }: {
  name: string; loading: boolean; onConfirm: () => void; onClose: () => void;
}) => (
  <Modal title="تأكيد الحذف" onClose={onClose} overlayClassName="workers-modal-overlay" modalClassName="workers-modal-card">
    <div style={{ display: "flex", flexDirection: "column", gap: "20px" }}>
      <p style={{ margin: 0, color: "#7c857a", lineHeight: "1.6" }}>
        هل أنت متأكد من حذف العامل
        <strong style={{ color: "#1a2a10", margin: "0 4px" }}>{name}</strong>؟
      </p>
      <div className="workers-modal-actions" style={{ display: "flex", gap: "12px", borderTop: "1px solid #f5f3ef", paddingTop: "16px" }}>
        <button className="button danger" onClick={onConfirm} disabled={loading} style={{ flex: 1, justifyContent: "center" }}>
          {loading ? <Loader2 size={18} className="spin" /> : <Trash2 size={18} />}
          {loading ? "جار الحذف..." : "تأكيد الحذف"}
        </button>
        <button className="button secondary" onClick={onClose} disabled={loading}>إلغاء</button>
      </div>
    </div>
  </Modal>
);
