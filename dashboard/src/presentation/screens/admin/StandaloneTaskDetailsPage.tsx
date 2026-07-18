import React, { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { container } from "@infrastructure/di/container";
import { useToast } from "@presentation/components/ToastProvider";
import { CustomSelect } from "@presentation/components/CustomSelect";
import { StandaloneTask } from "@domain/entities/StandaloneTask";
import { PaymentMethod } from "@domain/entities/ContractPayment";
import { User } from "@domain/entities/User";
import { X, FileText } from "lucide-react";
import { formatDateTime } from "@shared/utils/date";

const PAYMENT_METHOD_OPTIONS: { id: PaymentMethod; label: string }[] = [
  { id: "cash",    label: "نقدي"      },
  { id: "transfer",label: "رابط"      },
  { id: "cheque",  label: "شيك"       },
  { id: "card",    label: "ومض"       },
  { id: "gateway", label: "UPayments" },
];

const toDateTimeLocalValue = (value?: string | null) => {
  if (!value) return "";

  if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(value)) return value;
  if (/^\d{4}-\d{2}-\d{2}$/.test(value)) return `${value}T00:00`;

  const normalized = value.includes(" ") && !value.includes("T") ? value.replace(" ", "T") : value;
  const parsed = new Date(normalized);
  if (Number.isNaN(parsed.getTime())) return "";

  const pad = (n: number) => String(n).padStart(2, "0");
  return `${parsed.getFullYear()}-${pad(parsed.getMonth() + 1)}-${pad(parsed.getDate())}T${pad(parsed.getHours())}:${pad(parsed.getMinutes())}`;
};

export const StandaloneTaskDetailsPage: React.FC<{ taskId?: string; onClose?: () => void; viewOnly?: boolean }> = ({ taskId: propTaskId, onClose, viewOnly = false }) => {
  const navigate = useNavigate();
  const { taskId: paramTaskId } = useParams<{ taskId: string }>();
  const taskIdToUse = propTaskId || paramTaskId;
  const { notify } = useToast();

  const [loading, setLoading] = useState(true);
  const [task, setTask] = useState<StandaloneTask | null>(null);
  const [supervisors, setSupervisors] = useState<User[]>([]);
  const [contracts, setContracts] = useState<any[]>([]);
  const [lines, setLines] = useState<any[]>([]);
  const [zones, setZones] = useState<any[]>([]);

  // form state
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [address, setAddress] = useState("");
  const [taskDate, setTaskDate] = useState("");
  const [notes, setNotes] = useState("");
  const [supervisorReport, setSupervisorReport] = useState<string | null>(null);
  const [supervisorId, setSupervisorId] = useState<string | null>(null);
  const [supervisorTouched, setSupervisorTouched] = useState(false);
  const [contractId, setContractId] = useState<string | null>(null);
  const [lineId, setLineId] = useState<string | null>(null);
  const [zoneId, setZoneId] = useState<string | null>(null);
  const [cost, setCost] = useState<string | null>(null);
  const [status, setStatus] = useState<string>("pending");
  const [updating, setUpdating] = useState(false);
  const [showFullReport, setShowFullReport] = useState(false);
  const [paymentStatus, setPaymentStatus] = useState<"unpaid" | "paid">("unpaid");
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethod | "">("");

  useEffect(() => {
    let mounted = true;
    const load = async () => {
      try {
        setLoading(true);
        if (!taskIdToUse) throw new Error("معرّف المهمة غير موجود");

        const tasks = await container.adminRepository.listStandaloneTasks();
        const found = tasks.find((t) => t.id === taskIdToUse);
        if (!found) throw new Error("المهمة غير موجودة");

        const [sups, ctrs, lns] = await Promise.all([
          container.adminRepository.listSupervisors(),
          container.adminRepository.listContracts(),
          container.lineRepository.listLines(),
        ]);

        if (!mounted) return;
        setTask(found);
        setSupervisors(sups);
        setContracts(ctrs);
        setLines(lns);

        setTitle(found.title);
        setDescription(found.description || "");
        setAddress(found.address || "");
        setTaskDate(toDateTimeLocalValue(found.taskDate));
        setNotes(found.notes || "");
        setSupervisorReport((found as any).supervisorReport ?? null);
        setSupervisorId(found.supervisorId || null);
        setContractId((found as any).contractId ?? null);
        setLineId((found as any).lineId ?? null);
        setZoneId((found as any).zoneId ?? null);
        setCost((found as any).cost != null ? String((found as any).cost) : null);
        setStatus(found.status || "pending");
        setPaymentStatus((found.paymentStatus as "unpaid" | "paid") || "unpaid");
        setPaymentMethod((found.paymentMethod as PaymentMethod) || "");

        if ((found as any).lineId) {
          try {
            const zns = await container.lineRepository.listZones((found as any).lineId);
            if (!mounted) return;
            setZones(zns);
          } catch (e) {
            console.error("Failed to load zones:", e);
          }
        }
      } catch (e: any) {
        console.error(e);
        notify(e?.message || "تعذر تحميل المهمة");
      } finally {
        if (mounted) setLoading(false);
      }
    };
    load();
    return () => { mounted = false; };
  }, [taskIdToUse]);

  useEffect(() => {
    let mounted = true;
    const loadZones = async () => {
      if (!lineId) {
        setZones([]);
        setZoneId(null);
        return;
      }
      try {
        const zns = await container.lineRepository.listZones(lineId);
        if (!mounted) return;
        setZones(zns);
      } catch (e) {
        console.error("Failed to load zones when line changed:", e);
        setZones([]);
      }
    };
    loadZones();
    return () => { mounted = false; };
  }, [lineId]);

  useEffect(() => {
    // When a contract is selected, auto-fill its line, zone and default supervisor (if assigned to that line)
    let mounted = true;
    const applyContractLocation = async () => {
      if (!contractId) {
        setLineId(null);
        setZoneId(null);
        return;
      }

      const selected = contracts.find((c) => c.id === contractId);
      if (!selected) {
        setLineId(null);
        setZoneId(null);
        return;
      }

      // If contract has a lineId, select it and load zones (use existing effect)
      if (selected.lineId) {
        setLineId(selected.lineId);

        // If user didn't manually change supervisor, pick the supervisor assigned to the line
        if (!supervisorTouched && supervisors && supervisors.length > 0) {
          const assigned = supervisors.find(s => s.assignedLineId === selected.lineId);
          if (assigned) setSupervisorId(assigned.id);
        }
      } else {
        setLineId(null);
      }

      // Select zone if present on contract
      if ((selected as any).zoneId) {
        setZoneId((selected as any).zoneId);
      } else {
        setZoneId(null);
      }
    };

    applyContractLocation();
    return () => { mounted = false; };
  }, [contractId, contracts, supervisors, supervisorTouched]);

  const handleUpdate = async () => {
    if (!task) return;
    if (!title.trim()) {
      notify("من فضلك أدخل اسم المهمة");
      return;
    }
    if (paymentStatus === "paid" && !paymentMethod) {
      notify("من فضلك اختر طريقة الدفع");
      return;
    }
    // Allow saving even when fields are empty — send null for empty values
    setUpdating(true);
    try {
      const payload: any = {
        title: title.trim() || null,
        description: description.trim() || null,
        address: address.trim() || null,
        taskDate: taskDate || null,
        notes: notes.trim() || null,
        supervisorReport: supervisorReport ? supervisorReport.trim() : null,
        supervisorId: supervisorId || null,
        contractId: contractId ?? null,
        lineId: lineId ?? null,
        zoneId: zoneId ?? null,
        cost: cost ? parseFloat(cost) : null,
        status,
        paymentStatus,
        paymentMethod: paymentStatus === "paid" ? paymentMethod : null,
      };

      const updated = await container.adminRepository.updateStandaloneTask(task.id, payload);
      notify("تم تحديث المهمة بنجاح");
      setTask(updated);
      if (onClose) onClose(); else navigate('/admin/tasks');
    } catch (err: any) {
      console.error(err);
      notify(err?.message || "فشل تحديث المهمة");
    } finally {
      setUpdating(false);
    }
  };

  const statusLabel = (s?: string) => {
    switch (s) {
      case "pending": return "قيد الانتظار";
      case "in_progress": return "جاري التنفيذ";
      case "completed": return "مكتملة";
      case "cancelled": return "ملغاة";
      default: return s || "—";
    }
  };

  const statusStyle = (s?: string) => {
    switch (s) {
      case "pending": return { bg: "var(--neutral-100)", color: "var(--neutral-700)" };
      case "in_progress": return { bg: "var(--orange-100)", color: "var(--orange-700)" };
      case "completed": return { bg: "var(--color-success-bg)", color: "var(--color-success)" };
      case "cancelled": return { bg: "var(--color-error-bg)", color: "var(--color-error)" };
      default: return { bg: "var(--neutral-100)", color: "var(--neutral-700)" };
    }
  };

  const TASK_STATUS_OPTIONS = [
    { value: 'pending', label: 'قيد الانتظار', bg: 'var(--neutral-100)', color: 'var(--neutral-700)', dot: 'var(--neutral-400)' },
    { value: 'in_progress', label: 'جاري التنفيذ', bg: 'var(--orange-100)', color: 'var(--orange-700)', dot: 'var(--orange-500)' },
    { value: 'completed', label: 'مكتملة', bg: 'var(--color-success-bg)', color: 'var(--color-success)', dot: 'var(--green-500)' },
    { value: 'cancelled', label: 'ملغاة', bg: 'var(--color-error-bg)', color: 'var(--color-error)', dot: 'var(--color-error)' },
  ];

  const TaskStatusPicker = ({ status, onChange }: { status: string; onChange: (s: string) => void }) => {
    const [open, setOpen] = useState(false);
    const ref = React.useRef<HTMLDivElement | null>(null);
    const current = TASK_STATUS_OPTIONS.find(o => o.value === status) ?? { value: status, label: status, bg: 'var(--neutral-100)', color: 'var(--neutral-700)', dot: 'var(--neutral-400)' };

    useEffect(() => {
      if (!open) return;
      const handleClick = (e: MouseEvent) => { if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false); };
      document.addEventListener('mousedown', handleClick);
      return () => document.removeEventListener('mousedown', handleClick);
    }, [open]);

    return (
      <div ref={ref} style={{ position: 'relative', display: 'inline-block' }}>
        <button onClick={() => setOpen(!open)} style={{ padding: '6px 12px', borderRadius: 20, fontSize: '0.8rem', fontWeight: 600, background: current.bg, color: current.color, border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 8, transition: 'opacity 0.2s', width: 110, justifyContent: 'center' }}>
          <span style={{ width: 8, height: 8, borderRadius: '50%', background: current.dot }} />
          {current.label}
        </button>
        {open && (
          <div style={{ position: 'absolute', top: 'calc(100% + 4px)', left: '50%', transform: 'translateX(-50%)', background: 'var(--bg-card)', borderRadius: 'var(--radius-md)', border: '1px solid var(--color-border)', boxShadow: 'var(--shadow-md)', zIndex: 60, padding: 4, minWidth: 140, overflow: 'hidden' }}>
            {TASK_STATUS_OPTIONS.map(opt => (
              <button key={opt.value} onClick={() => { onChange(opt.value); setOpen(false); }} style={{ width: '100%', display: 'flex', alignItems: 'center', gap: '10px', padding: '10px', border: 'none', borderRadius: 'var(--radius-sm)', background: status === opt.value ? 'var(--neutral-50)' : 'transparent', color: 'var(--text-primary)', fontSize: '0.85rem', cursor: 'pointer', textAlign: 'right' }}>
                <span style={{ width: 8, height: 8, borderRadius: '50%', background: opt.dot }} />
                {opt.label}
              </button>
            ))}
          </div>
        )}
      </div>
    );
  };

  const handleStatusChange = async (newStatus: string) => {
    if (!task) return;
    if (newStatus === status) return;
    try {
      const updated = await container.adminRepository.updateStandaloneTaskStatus(task.id, newStatus);
      setTask(updated);
      setStatus(updated.status);
      notify('تم تغيير حالة المهمة');
    } catch (e) {
      console.error('Failed to update task status', e);
      notify('فشل تغيير حالة المهمة');
    }
  };

  const truncate = (s: string | null | undefined, n = 120) => {
    if (!s) return null;
    return s.length > n ? s.substring(0, n) + '...' : s;
  };

  if (loading) return null;
  if (!task) return null;

  return (
    <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.4)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 120, overflow: 'hidden' }}>
      <div style={{ width: '92%', maxWidth: 820, maxHeight: 'calc(100vh - 40px)', background: 'var(--bg-card)', padding: 12, borderRadius: 8, boxShadow: 'var(--shadow-lg)', overflow: 'hidden', display: 'flex', flexDirection: 'column', gap: 8 }}>
        {/* header */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
            <div style={{ padding: 6, background: 'var(--primary-light)', borderRadius: 8, color: 'var(--color-primary)' }}><FileText size={20} /></div>
            <div>
              <div style={{ fontSize: '1rem', fontWeight: 700, color: 'var(--text-primary)' }}>{viewOnly ? 'عرض المهمة' : 'تعديل المهمة'}</div>
              <div style={{ fontSize: '0.82rem', color: 'var(--text-tertiary)' }}>{title} {task.taskDate ? '• ' + formatDateTime(task.taskDate) : ''}</div>
            </div>
          </div>

          <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            {!viewOnly ? (
              <TaskStatusPicker status={status} onChange={handleStatusChange} />
            ) : (
              <div style={{ padding: '4px 10px', borderRadius: 16, fontWeight: 700, ...statusStyle(status) }}>{statusLabel(status)}</div>
            )}
            <button onClick={() => (onClose ? onClose() : navigate('/admin/tasks'))} className='icon-button' style={{ border: 'none', background: 'transparent' }}><X size={18} /></button>
          </div>
        </div>

        {/* scrollable body */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8, overflowY: 'auto', flex: 1, minHeight: 0 }}>
        {/* meta row */}
        <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', color: 'var(--text-secondary)', fontSize: '0.9rem' }}>
          <div><strong style={{ fontWeight: 700, marginRight: 6 }}>المشرف:</strong> {supervisorId ? supervisors.find(s => s.id === supervisorId)?.fullName || '—' : '—'}</div>
          <div><strong style={{ fontWeight: 700, marginRight: 6 }}>الهاتف:</strong> {task.clientPhone || '—'}</div>
          <div><strong style={{ fontWeight: 700, marginRight: 6 }}>العقد:</strong> {contractId ? (contracts.find(c => c.id === contractId)?.code ?? '—') : '—'}</div>
          <div><strong style={{ fontWeight: 700, marginRight: 6 }}>التكلفة:</strong> {cost != null ? Number(cost).toFixed(2) + ' د.ك' : '—'}</div>
          <div><strong style={{ fontWeight: 700, marginRight: 6 }}>الخط / المنطقة:</strong> {`${lines.find(l => l.id === lineId)?.name ?? (task as any).lineName ?? '—'} / ${zones.find(z => z.id === zoneId)?.name ?? (task as any).zoneName ?? '—'}`}</div>
          <div>
            <strong style={{ fontWeight: 700, marginRight: 6 }}>حالة الدفع:</strong>
            <span style={{ padding: '2px 10px', borderRadius: 12, fontWeight: 700, fontSize: '0.82rem', background: paymentStatus === 'paid' ? 'var(--color-success-bg)' : 'var(--color-error-bg)', color: paymentStatus === 'paid' ? 'var(--color-success)' : 'var(--color-error)' }}>{paymentStatus === 'paid' ? 'مدفوع' : 'غير مدفوع'}</span>
          </div>
        </div>

        {/* form - compact (reordered for logical flow) */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {/* Client / Contract / Location */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
            <div>
              <div style={{ fontSize: '0.88rem', color: 'var(--text-primary)', marginBottom: 6 }}>ربط بعقد (اختياري)</div>
              <CustomSelect value={contractId ?? ''} onChange={val => setContractId(val as string | null)} options={[{ id: '', label: '-- لا يوجد عقد --' }, ...contracts.map(c => ({ id: c.id, label: `${c.code || '—'} (${c.clientName ?? c.contractUserName ?? '—'})` }))]} placeholder='اختر عقد' width='100%' searchable disabled={viewOnly} />
            </div>
            <div>
              <div style={{ fontSize: '0.88rem', color: 'var(--text-primary)', marginBottom: 6 }}>الخط / المنطقة</div>
              <div style={{ display: 'flex', gap: 8 }}>
                <CustomSelect value={lineId ?? ''} onChange={val => { setLineId(val as string | null); setZoneId(null); }} options={[{ id: '', label: '-- لا يوجد خط --' }, ...lines.map(l => ({ id: l.id, label: l.name }))]} placeholder='اختر الخط' width='50%' disabled={viewOnly} />
                <CustomSelect value={zoneId ?? ''} onChange={val => setZoneId(val as string | null)} options={[{ id: '', label: '-- لا توجد منطقة --' }, ...zones.map(z => ({ id: z.id, label: z.name }))]} placeholder='اختر المنطقة' width='50%' disabled={viewOnly || !lineId} />
              </div>
            </div>
          </div>

          {/* Address */}
          <div>
            <div style={{ fontSize: '0.88rem', color: 'var(--text-primary)', marginBottom: 6 }}>العنوان</div>
            <input className='input' value={address} onChange={e => setAddress(e.target.value)} disabled={viewOnly} />
          </div>

          {/* Task title and description */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: 8 }}>
            <div>
              <div style={{ fontSize: '0.88rem', color: 'var(--text-primary)', marginBottom: 6 }}>اسم المهمة</div>
              <input className='input' value={title} onChange={e => setTitle(e.target.value)} disabled={viewOnly} required />
            </div>
            <div>
              <div style={{ fontSize: '0.88rem', color: 'var(--text-primary)', marginBottom: 6 }}>وصف المهمة</div>
              <textarea className='input' rows={2} value={description} onChange={e => setDescription(e.target.value)} style={{ resize: 'none', minHeight: 48 }} disabled={viewOnly} />
            </div>
          </div>

          {/* Date / Supervisor / Cost / Status */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
            <div>
              <div style={{ fontSize: '0.88rem', color: 'var(--text-primary)', marginBottom: 6 }}>تاريخ ووقت المهمة</div>
              <input className='input' type='datetime-local' value={taskDate} onChange={e => setTaskDate(e.target.value)} disabled={viewOnly} />
            </div>
            <div>
              <div style={{ fontSize: '0.88rem', color: 'var(--text-primary)', marginBottom: 6 }}>المشرف</div>
              <CustomSelect value={supervisorId ?? ''} onChange={val => { setSupervisorTouched(true); setSupervisorId(val as string | null); }} options={[{ id: '', label: '-- لا يوجد مشرف --' }, ...supervisors.map(s => ({ id: s.id, label: s.fullName }))]} placeholder='اختر مشرف' width='100%' disabled={viewOnly} />
            </div>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
            <div>
              <div style={{ fontSize: '0.88rem', color: 'var(--text-primary)', marginBottom: 6 }}>التكلفة</div>
              <input className='input' type='number' step='0.01' value={cost ?? ''} onChange={e => setCost(e.target.value ? e.target.value : null)} disabled={viewOnly} />
            </div>
            <div>
              <div style={{ fontSize: '0.88rem', color: 'var(--text-primary)', marginBottom: 6 }}>حالة المهمة</div>
              <CustomSelect value={status ?? 'pending'} onChange={val => setStatus(val as string)} options={TASK_STATUS_OPTIONS.map(o => ({ id: o.value, label: o.label }))} placeholder='اختر الحالة' width='100%' disabled={viewOnly} />
            </div>
          </div>

          {/* Payment status / method */}
          <div style={{ display: 'grid', gridTemplateColumns: paymentStatus === 'paid' ? '1fr 1fr' : '1fr', gap: 8 }}>
            <div>
              <div style={{ fontSize: '0.88rem', color: 'var(--text-primary)', marginBottom: 6 }}>حالة الدفع</div>
              <CustomSelect value={paymentStatus} onChange={val => setPaymentStatus(val as "unpaid" | "paid")} options={[{ id: 'unpaid', label: 'غير مدفوع' }, { id: 'paid', label: 'مدفوع' }]} placeholder='اختر حالة الدفع' width='100%' disabled={viewOnly} />
            </div>
            {paymentStatus === 'paid' && (
              <div>
                <div style={{ fontSize: '0.88rem', color: 'var(--text-primary)', marginBottom: 6 }}>طريقة الدفع</div>
                <CustomSelect value={paymentMethod} onChange={val => setPaymentMethod(val as PaymentMethod)} options={PAYMENT_METHOD_OPTIONS} placeholder='اختر طريقة الدفع' width='100%' disabled={viewOnly} />
              </div>
            )}
          </div>

          {/* Notes and supervisor report */}
          <div>
            <div style={{ fontSize: '0.88rem', color: 'var(--text-primary)', marginBottom: 6 }}>ملاحظات إضافية</div>
            <textarea className='input' rows={1} value={notes} onChange={e => setNotes(e.target.value)} style={{ resize: 'none', minHeight: 36 }} disabled={viewOnly} />
          </div>

          {supervisorReport ? (
            <div style={{ background: 'var(--bg-subtle)', padding: 8, borderRadius: 8 }}>
              <strong style={{ display: 'block', marginBottom: 6 }}>تقرير المشرف</strong>
              <div style={{ whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{truncate(supervisorReport, 150)}</div>
              {!viewOnly && supervisorReport.length > 150 ? <div style={{ marginTop: 6 }}><button className='button small' onClick={() => setShowFullReport(true)}>عرض كامل</button></div> : null}
            </div>
          ) : null}
        </div>
        </div>

        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 6 }}>
          {!viewOnly ? (
            <>
              <button className='button primary' onClick={() => handleUpdate()} disabled={updating || title.trim() === ''}>{updating ? 'جاري الحفظ...' : 'حفظ التعديلات'}</button>
              <button className='button secondary' onClick={() => (onClose ? onClose() : navigate('/admin/tasks'))}>إلغاء</button>
            </>
          ) : (
            <button className='button secondary' onClick={() => (onClose ? onClose() : navigate('/admin/tasks'))}>إغلاق</button>
          )}
        </div>

        {showFullReport && (
          <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 200 }}>
            <div style={{ width: '80%', maxWidth: 720, maxHeight: '80vh', background: 'var(--bg-card)', padding: 16, borderRadius: 8, overflow: 'auto' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <strong>تقرير المشرف</strong>
                <button className='icon-button' onClick={() => setShowFullReport(false)}><X size={16} /></button>
              </div>
              <div style={{ marginTop: 12, whiteSpace: 'pre-wrap' }}>{supervisorReport}</div>
            </div>
          </div>
        )}

      </div>
    </div>
  );
};

export default StandaloneTaskDetailsPage;
