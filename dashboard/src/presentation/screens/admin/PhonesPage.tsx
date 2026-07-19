import { useEffect, useState } from "react";
import { container } from "@infrastructure/di/container";
import { CompanyPhone } from "@domain/entities/CompanyPhone";
import { LoadingState, ErrorState } from "@presentation/components/States";
import { useToast } from "@presentation/components/ToastProvider";
import { useTour } from "@presentation/components/tour/useTour";
import {
  Phone,
  Plus,
  X,
  Save,
  Pencil,
  Trash2,
  Power,
  FileText,
  AlertTriangle,
  Loader2,
  Search,
  MapPin,
} from "lucide-react";

export const PhonesPage = () => {
  const [phones, setPhones] = useState<CompanyPhone[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState("");

  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [editingPhone, setEditingPhone] = useState<CompanyPhone | null>(null);
  const [confirmDelete, setConfirmDelete] = useState<{ phone: CompanyPhone } | null>(null);
  const [deleting, setDeleting] = useState(false);

  const { notify } = useToast();
  const repo = container.phoneRepository;

  const loadData = async () => {
    try {
      setLoading(true);
      const data = await repo.listPhones();
      setPhones(data);
    } catch {
      setError("تعذر تحميل بيانات الهواتف");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { loadData(); }, []);

  const handleCreate = async (data: any) => {
    try {
      await repo.createPhone(data);
      notify("تم إضافة الهاتف بنجاح");
      setIsCreateOpen(false);
      loadData();
    } catch {
      notify("فشل إضافة الهاتف");
    }
  };

  const handleUpdate = async (data: any) => {
    try {
      await repo.updatePhone(data);
      notify("تم تحديث بيانات الهاتف");
      setEditingPhone(null);
      loadData();
    } catch {
      notify("فشل تحديث الهاتف");
    }
  };

  const handleToggleStatus = async (p: CompanyPhone) => {
    try {
      await repo.updatePhone({
        id: p.id, phoneNumber: p.phoneNumber, phoneName: p.phoneName,
        notes: p.notes, isActive: p.status !== "active"
      });
      loadData();
    } catch {
      notify("فشل تحديث الحالة");
    }
  };

  const handleDeletePhone = async () => {
    if (!confirmDelete) return;
    setDeleting(true);
    try {
      await repo.deletePhone(confirmDelete.phone.id);
      notify("تم حذف الهاتف");
      setConfirmDelete(null);
      loadData();
    } catch {
      notify("فشل حذف الهاتف");
    } finally {
      setDeleting(false);
    }
  };

  const filtered = phones.filter(p =>
    p.phoneNumber.includes(search) || (p.phoneName || "").includes(search)
  );

  useTour(
    "admin-phones",
    loading || error
      ? []
      : [
          {
            target: ".phones-page-header",
            title: "إدارة هواتف الشركة",
            content: "من هنا تدوّر على هاتف بالرقم أو الاسم، وتضيف هاتف جديد.",
          },
          {
            target: ".phones-page-stats",
            title: "نظرة سريعة",
            content: "إجمالي الهواتف، النشطة منها، وكام هاتف مربوط بخطوط سير.",
          },
          {
            target: ".phones-page-table-card",
            title: "قائمة الهواتف",
            content: "من هنا تعدّل بيانات أي هاتف، توقفه، أو تحذفه.",
          },
        ]
  );

  if (loading) return <LoadingState />;
  if (error) return <ErrorState text={error} />;

  return (
    <div className="phones-page" style={{ position: "relative", height: "calc(100vh - 140px)", overflow: "hidden", display: "flex", flexDirection: "column" }}>
      {/* Header */}
      <div className="phones-page-header" style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "16px", padding: "0 4px", flexShrink: 0 }}>
        <h2 className="phones-page-title" style={{ margin: 0, display: "flex", alignItems: "center", gap: "12px", fontSize: "1.25rem", color: "#1a2a10" }}>
          <div style={{ padding: "8px", background: "#eef3e8", borderRadius: "8px", color: "var(--primary)", display: "flex" }}>
            <Phone size={24} />
          </div>
          إدارة هواتف الشركة
          <span style={{ fontSize: "0.85rem", color: "#b0b8ae", fontWeight: "400" }}>({phones.length})</span>
        </h2>
        <div className="phones-page-toolbar" style={{ display: "flex", gap: "12px", alignItems: "center" }}>
          <div className="phones-page-search" style={{ position: "relative" }}>
            <Search size={16} style={{ position: "absolute", top: "10px", right: "12px", color: "#b0b8ae" }} />
            <input className="input phones-page-search-input" placeholder="بحث بالرقم أو الاسم... مثال: 50012345" value={search} onChange={e => setSearch(e.target.value)}
              style={{ paddingRight: "36px", width: "240px", borderColor: "#e4e0d8" }} />
          </div>
          <button className="button phones-page-create-button" onClick={() => setIsCreateOpen(true)}>
            <Plus size={18} /> إضافة هاتف
          </button>
        </div>
      </div>

      {/* Stats */}
      <div className="phones-page-stats" style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: "12px", marginBottom: "16px", flexShrink: 0 }}>
        <StatCard icon={Phone} label="إجمالي الهواتف" value={phones.length} color="#30461F" bg="#eef3e8" />
        <StatCard icon={Power} label="هواتف نشطة" value={phones.filter(p => p.status === "active").length} color="#16a34a" bg="#eef3e8" />
        <StatCard icon={MapPin} label="مربوطة بخطوط" value={phones.filter(p => (p.lineCount || 0) > 0).length} color="#EA8E20" bg="#fef6eb" />
      </div>

      {/* Table */}
      <div className="card phones-page-table-card" style={{ padding: 0, overflow: "hidden", flex: 1, display: "flex", flexDirection: "column", border: "1px solid #e4e0d8", minHeight: 0 }}>
        <div className="phones-page-table-scroll" style={{ overflowY: "auto", height: "100%" }}>
          <table className="table phones-page-table" style={{ margin: 0, width: "100%", borderCollapse: "separate", borderSpacing: 0 }}>
            <thead style={{ position: "sticky", top: 0, zIndex: 10, background: "#FBF9F5" }}>
              <tr>
                <Th>رقم الهاتف</Th>
                <Th>اسم الهاتف</Th>
                <Th center>الخطوط المربوطة</Th>
                <Th>ملاحظات</Th>
                <Th>الحالة</Th>
                <Th center>الإجراءات</Th>
              </tr>
            </thead>
            <tbody>
              {filtered.length === 0 && (
                <tr className="phones-page-empty-row"><td colSpan={6} style={{ textAlign: "center", padding: "48px", color: "#b0b8ae" }}>لا توجد هواتف</td></tr>
              )}
              {filtered.map(p => (
                <tr key={p.id} className="phones-page-row" style={{ background: "white", borderBottom: "1px solid #f5f3ef" }}>
                  <td className="phones-page-cell phones-page-cell-number" data-label="رقم الهاتف" style={{ padding: "16px", fontWeight: "700", color: "#1a2a10" }}>
                    <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
                      <div style={{ width: "8px", height: "8px", borderRadius: "50%", background: p.status === "active" ? "#10b981" : "#d4cfc5" }} />
                      {p.phoneNumber}
                    </div>
                  </td>
                  <td className="phones-page-cell phones-page-cell-name" data-label="اسم الهاتف" style={{ padding: "16px", color: "#2d3a2a", fontSize: "0.9rem" }}>
                    {p.phoneName || <span style={{ color: "#b0b8ae" }}>—</span>}
                  </td>
                  <td className="phones-page-cell phones-page-cell-lines" data-label="الخطوط المربوطة" style={{ padding: "16px" }}>
                    {(p.lineNames?.length ?? 0) > 0 ? (
                      <div style={{ display: "flex", flexWrap: "wrap", gap: "6px" }}>
                        {p.lineNames!.map((name, i) => (
                          <span key={i} style={{ display: "inline-flex", alignItems: "center", gap: "4px", padding: "3px 10px", borderRadius: "16px", fontSize: "0.8rem", fontWeight: "600", background: "#eef3e8", color: "#30461F", border: "1px solid #dce8d0" }}>
                            <MapPin size={12} />
                            {name}
                          </span>
                        ))}
                      </div>
                    ) : (
                      <span style={{ color: "#d4cfc5", fontSize: "0.85rem" }}>—</span>
                    )}
                  </td>
                  <td className="phones-page-cell phones-page-cell-notes" data-label="ملاحظات" style={{ padding: "16px", color: "#7c857a", fontSize: "0.85rem", maxWidth: "200px", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                    {p.notes || <span style={{ color: "#d4cfc5" }}>—</span>}
                  </td>
                  <td className="phones-page-cell phones-page-cell-status" data-label="الحالة" style={{ padding: "16px" }}>
                    <span style={{
                      display: "inline-block", padding: "4px 10px", borderRadius: "20px", fontSize: "0.8rem", fontWeight: "600",
                      backgroundColor: p.status === "active" ? "#eef3e8" : "#f5f3ef",
                      color: p.status === "active" ? "#30461F" : "#4a5349",
                      border: `1px solid ${p.status === "active" ? "#dce8d0" : "#e4e0d8"}`
                    }}>
                      {p.status === "active" ? "نشط" : "متوقف"}
                    </span>
                  </td>
                  <td className="phones-page-cell phones-page-cell-actions" data-label="الإجراءات" style={{ textAlign: "center", padding: "16px" }}>
                    <div className="phones-page-actions" style={{ display: "flex", gap: "8px", justifyContent: "center" }}>
                      <button className="icon-button" title="تعديل" onClick={() => setEditingPhone(p)}><Pencil size={18} /></button>
                      <button className="icon-button" title="حذف" onClick={() => setConfirmDelete({ phone: p })} style={{ color: "#ef4444" }}><Trash2 size={18} /></button>
                      <button className="icon-button" title={p.status === "active" ? "إيقاف" : "تفعيل"} onClick={() => handleToggleStatus(p)}
                        style={{ color: p.status === "active" ? "#ef4444" : "#10b981" }}>
                        <Power size={18} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Modals */}
      {isCreateOpen && <PhoneFormModal title="إضافة هاتف جديد" onClose={() => setIsCreateOpen(false)} onSubmit={handleCreate} />}
      {editingPhone && <PhoneFormModal title="تعديل بيانات الهاتف" phone={editingPhone} onClose={() => setEditingPhone(null)} onSubmit={handleUpdate} />}
      {confirmDelete && (
        <ConfirmDeleteModal
          name={confirmDelete.phone.phoneNumber}
          loading={deleting}
          onConfirm={handleDeletePhone}
          onClose={() => !deleting && setConfirmDelete(null)}
        />
      )}
    </div>
  );
};


const Th = ({ children, center }: { children: React.ReactNode; center?: boolean }) => (
  <th style={{ padding: "16px", color: "#7c857a", fontSize: "0.85rem", fontWeight: "600", borderBottom: "1px solid #e4e0d8", background: "#FBF9F5", textAlign: center ? "center" : undefined }}>{children}</th>
);

const StatCard = ({ icon: Icon, label, value, color, bg }: any) => (
  <div className="card phones-page-stat-card" style={{ padding: "16px 20px", display: "flex", alignItems: "center", gap: "14px" }}>
    <div style={{ width: "42px", height: "42px", borderRadius: "10px", background: bg, display: "flex", alignItems: "center", justifyContent: "center" }}>
      <Icon size={22} color={color} />
    </div>
    <div>
      <div style={{ fontSize: "0.8rem", color: "#7c857a", fontWeight: "500" }}>{label}</div>
      <div style={{ fontSize: "1.15rem", fontWeight: "800", color: "#1a2a10", marginTop: "2px" }}>{value}</div>
    </div>
  </div>
);

const PhoneFormModal = ({ title, phone, onClose, onSubmit }: {
  title: string; phone?: CompanyPhone; onClose: () => void;
  onSubmit: (data: any) => void;
}) => {
  const isCreateMode = !phone;
  const [phoneNumber, setPhoneNumber] = useState(phone?.phoneNumber || "");
  const [phoneName, setPhoneName] = useState(phone?.phoneName || "");
  const [notes, setNotes] = useState(phone?.notes || "");
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const normalizedPhoneNumber = phoneNumber.trim();
    const normalizedPhoneName = phoneName.trim();
    if (!normalizedPhoneNumber) return;
    if (isCreateMode && !normalizedPhoneName) return;

    setSubmitting(true);
    await onSubmit({
      ...(phone ? { id: phone.id, isActive: phone.status === "active" } : {}),
      phoneNumber: normalizedPhoneNumber,
      phoneName: normalizedPhoneName || null,
      notes: notes.trim() || null,
    });
    setSubmitting(false);
  };

  return (
    <Modal title={title} onClose={onClose}>
      <form onSubmit={handleSubmit} style={{ display: "flex", flexDirection: "column", gap: "20px" }}>
        <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
          <FormField label="رقم الهاتف الكويتي" icon={Phone} required>
            <div style={{ display: "flex", flexDirection: "column", gap: "6px" }}>
              <input className="input" type="tel" inputMode="tel" dir="ltr" placeholder="مثال: 50012345 أو +96550012345" value={phoneNumber} onChange={e => setPhoneNumber(e.target.value)}
                style={{ paddingRight: "40px", borderColor: "#e4e0d8" }} />
              <small style={{ color: "#7c857a", fontSize: "0.78rem" }}>أمثلة كويتية: 50012345 - 60098765 - +96550012345</small>
            </div>
          </FormField>
          <FormField label={isCreateMode ? "اسم الهاتف" : "اسم الهاتف (اختياري)"} icon={FileText} required={isCreateMode}>
            <input className="input" placeholder="مثال: هاتف خط مدينة الكويت" value={phoneName} onChange={e => setPhoneName(e.target.value)} required={isCreateMode}
              style={{ paddingRight: "40px", borderColor: "#e4e0d8" }} />
          </FormField>
          <FormField label="ملاحظات" icon={FileText}>
            <textarea className="input" placeholder="ملاحظات إضافية (اختياري)..." value={notes} onChange={e => setNotes(e.target.value)}
              rows={2} style={{ paddingRight: "40px", borderColor: "#e4e0d8", resize: "vertical" }} />
          </FormField>
        </div>
        <div className="phones-modal-actions" style={{ display: "flex", gap: "12px", marginTop: "8px", borderTop: "1px solid #f5f3ef", paddingTop: "16px" }}>
          <button className="button" style={{ flex: 1, justifyContent: "center" }} type="submit" disabled={submitting}>
            {submitting ? <Loader2 size={18} className="spin" /> : phone ? <Save size={18} /> : <Plus size={18} />}
            {submitting ? "جار الحفظ..." : phone ? "حفظ التغييرات" : "إضافة الهاتف"}
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

const Modal = ({ title, onClose, children }: { title: string; onClose: () => void; children: React.ReactNode }) => (
  <div className="phones-modal-overlay" style={{ position: "fixed", inset: 0, background: "rgba(0,0,0,0.5)", backdropFilter: "blur(4px)", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 100 }}>
    <div className="card phones-modal-card" style={{ width: "100%", maxWidth: "450px", maxHeight: "90vh", overflowY: "auto", padding: "24px" }}>
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

const ConfirmDeleteModal = ({ name, loading, onConfirm, onClose }: { name: string; loading: boolean; onConfirm: () => void; onClose: () => void }) => (
  <div className="phones-confirm-overlay" style={{ position: "fixed", inset: 0, background: "rgba(15, 23, 42, 0.6)", backdropFilter: "blur(4px)", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 110 }}>
    <div className="card phones-confirm-card" style={{ width: "100%", maxWidth: "420px", padding: "32px", textAlign: "center" }}>
      <div style={{ width: "64px", height: "64px", borderRadius: "50%", background: "#fef2f2", display: "flex", alignItems: "center", justifyContent: "center", margin: "0 auto 20px", border: "2px solid #fecaca" }}>
        <AlertTriangle size={32} color="#ef4444" />
      </div>
      <h3 style={{ margin: "0 0 8px", fontSize: "1.2rem", color: "#1a2a10" }}>تأكيد الحذف</h3>
      <p style={{ margin: "0 0 8px", color: "#7c857a", fontSize: "0.95rem" }}>هل أنت متأكد من حذف الهاتف</p>
      <p style={{ margin: "0 0 24px", fontWeight: "700", fontSize: "1.05rem", color: "#1a2a10", background: "#FBF9F5", padding: "10px 16px", borderRadius: "8px", border: "1px solid #e4e0d8", display: "inline-block" }}>"{name}"</p>
      <div className="phones-confirm-actions" style={{ display: "flex", gap: "12px", justifyContent: "center" }}>
        <button onClick={onConfirm} disabled={loading} style={{ flex: 1, padding: "12px 20px", borderRadius: "10px", border: "none", background: loading ? "#fca5a5" : "#ef4444", color: "white", fontWeight: "600", fontSize: "0.95rem", cursor: loading ? "not-allowed" : "pointer", display: "flex", alignItems: "center", justifyContent: "center", gap: "8px" }}>
          {loading ? <Loader2 size={18} className="spin" /> : <Trash2 size={18} />}
          {loading ? "جار الحذف..." : "نعم، احذف"}
        </button>
        <button onClick={onClose} disabled={loading} style={{ flex: 1, padding: "12px 20px", borderRadius: "10px", border: "1px solid #e4e0d8", background: "white", color: "#4a5349", fontWeight: "600", fontSize: "0.95rem", cursor: loading ? "not-allowed" : "pointer" }}>
          إلغاء
        </button>
      </div>
    </div>
  </div>
);
