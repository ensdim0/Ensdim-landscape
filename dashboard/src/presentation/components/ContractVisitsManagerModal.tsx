import React, { useCallback, useEffect, useMemo, useState } from "react";
import { Calendar, CheckSquare, ClipboardList, Clock, Loader2, Plus, Save, Trash2, X } from "lucide-react";

import { container } from "@infrastructure/di/container";
import { Contract } from "@domain/entities/Contract";
import { ContractTask, TaskStatus } from "@domain/entities/ContractTask";
import { Visit, VisitStatus } from "@domain/entities/Visit";
import { formatDate } from "@shared/utils/date";

type VisitRow = Visit & { tasks: ContractTask[] };

type VisitFormState = {
  title: string;
  visitDate: string;
  notes: string;
  status: VisitStatus;
};

type TaskDraft = {
  title: string;
  month: string;
};

const STATUS_OPTIONS: { value: VisitStatus; label: string }[] = [
  { value: "planned", label: "مخططة" },
  { value: "in_progress", label: "جارٍ التنفيذ" },
  { value: "completed", label: "مكتملة" },
  { value: "cancelled", label: "ملغاة" },
];

const STATUS_LABELS: Record<VisitStatus, string> = {
  planned: "مخططة",
  in_progress: "جارٍ التنفيذ",
  completed: "مكتملة",
  cancelled: "ملغاة",
};

const STATUS_COLORS: Record<VisitStatus, { bg: string; color: string }> = {
  planned: { bg: "#eff6ff", color: "#1d4ed8" },
  in_progress: { bg: "#fff7ed", color: "#c2410c" },
  completed: { bg: "#ecfdf3", color: "#15803d" },
  cancelled: { bg: "#fef2f2", color: "#b91c1c" },
};

const TASK_STATUS_OPTIONS: { value: TaskStatus; label: string }[] = [
  { value: "pending", label: "معلق" },
  { value: "completed", label: "مكتمل" },
  { value: "verified", label: "موثق" },
  { value: "rejected", label: "مرفوض" },
];

const UNCATEGORIZED_TERM = "__uncategorized__";

const createEmptyVisitForm = (title = ""): VisitFormState => ({
  title,
  visitDate: "",
  notes: "",
  status: "planned",
});

export const ContractVisitsManagerModal = ({
  contract,
  clientName,
  onClose,
  onSaved,
}: {
  contract: Contract;
  clientName?: string;
  onClose: () => void;
  onSaved?: () => Promise<void> | void;
}) => {
  const [visits, setVisits] = useState<VisitRow[]>([]);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [newVisit, setNewVisit] = useState<VisitFormState>(createEmptyVisitForm());
  const [newVisitTermKey, setNewVisitTermKey] = useState<string>(UNCATEGORIZED_TERM);
  const [newVisitTasks, setNewVisitTasks] = useState<TaskDraft[]>([]);
  const [visitDrafts, setVisitDrafts] = useState<Record<string, VisitFormState>>({});
  const [taskDrafts, setTaskDrafts] = useState<Record<string, TaskDraft>>({});
  const [savingVisitId, setSavingVisitId] = useState<string | null>(null);
  const [deletingVisitId, setDeletingVisitId] = useState<string | null>(null);
  const [updatingTaskId, setUpdatingTaskId] = useState<string | null>(null);
  const [activeTermKey, setActiveTermKey] = useState<string>(UNCATEGORIZED_TERM);

  const termOptions = useMemo(() => {
    const seen = new Set<string>();
    const items: { key: string; label: string }[] = [];

    for (const term of contract.terms || []) {
      const label = (term.content || "").trim();
      if (!label || seen.has(label)) continue;
      seen.add(label);
      items.push({ key: label, label });
    }

    return items;
  }, [contract.terms]);

  const allTermOptions = useMemo(
    () => [...termOptions, { key: UNCATEGORIZED_TERM, label: "زيارات بدون بند" }],
    [termOptions]
  );

  useEffect(() => {
    if (!allTermOptions.some((item) => item.key === activeTermKey)) {
      setActiveTermKey(allTermOptions[0]?.key || UNCATEGORIZED_TERM);
    }
  }, [activeTermKey, allTermOptions]);

  useEffect(() => {
    if (!allTermOptions.some((item) => item.key === newVisitTermKey)) {
      setNewVisitTermKey(activeTermKey || allTermOptions[0]?.key || UNCATEGORIZED_TERM);
    }
  }, [activeTermKey, allTermOptions, newVisitTermKey]);

  useEffect(() => {
    const selected = allTermOptions.find((item) => item.key === newVisitTermKey);
    const nextTitle = selected && selected.key !== UNCATEGORIZED_TERM ? selected.label : "";
    setNewVisit((prev) => (prev.title === nextTitle ? prev : { ...prev, title: nextTitle }));
  }, [allTermOptions, newVisitTermKey]);

  const getTermDefaultTasks = useCallback(
    (termLabel: string): TaskDraft[] => {
      const targetTerm = (contract.terms || []).find((term) => (term.content || "").trim() === termLabel);
      if (!targetTerm) return [];

      const defaults: TaskDraft[] = [];
      (targetTerm.visits || []).forEach((visitTemplate, index) => {
        (visitTemplate.tasks || []).forEach((taskTemplate) => {
          const title = (taskTemplate.title || "").trim();
          if (!title) return;
          defaults.push({ title, month: String(index + 1) });
        });
      });

      return defaults;
    },
    [contract.terms]
  );

  const loadVisits = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const loadedVisits = await container.adminRepository.listVisits(contract.id);
      const visitsWithTasks = await Promise.all(
        loadedVisits.map(async (visit) => ({
          ...visit,
          tasks: await container.adminRepository.listVisitTasks(visit.id),
        }))
      );

      setVisits(visitsWithTasks);
      setVisitDrafts((prev) => {
        const next: Record<string, VisitFormState> = {};
        for (const visit of visitsWithTasks) {
          next[visit.id] = prev[visit.id] ?? {
            title: (visit.title || "").trim(),
            visitDate: visit.visitDate,
            notes: visit.notes || "",
            status: visit.status,
          };
        }
        return next;
      });
      setTaskDrafts((prev) => {
        const next: Record<string, TaskDraft> = {};
        for (const visit of visitsWithTasks) {
          next[visit.id] = prev[visit.id] ?? { title: "", month: "1" };
        }
        return next;
      });
    } catch (loadError: any) {
      console.error("Error loading contract visits:", loadError);
      setError(loadError?.message || "تعذر تحميل الزيارات");
    } finally {
      setLoading(false);
    }
  }, [contract.id]);

  useEffect(() => {
    loadVisits();
  }, [loadVisits]);

  const refreshAfterMutation = useCallback(async () => {
    await loadVisits();
    await onSaved?.();
  }, [loadVisits, onSaved]);

  const addNewVisitTask = () => {
    setNewVisitTasks((prev) => [...prev, { title: "", month: String(prev.length + 1) }]);
  };

  const updateNewVisitTask = (index: number, field: keyof TaskDraft, value: string) => {
    setNewVisitTasks((prev) => prev.map((task, taskIndex) => (taskIndex === index ? { ...task, [field]: value } : task)));
  };

  const removeNewVisitTask = (index: number) => {
    setNewVisitTasks((prev) => prev.filter((_, taskIndex) => taskIndex !== index));
  };

  const handleCreateVisit = async (event: React.FormEvent) => {
    event.preventDefault();
    if (saving) return;

    setSaving(true);
    setError(null);
    try {
      const createdVisit = await container.adminRepository.createVisit({
        contractId: contract.id,
        title: newVisit.title.trim() || undefined,
        visitDate: newVisit.visitDate?.trim() || undefined,
        notes: newVisit.notes.trim() || undefined,
      });

      if (newVisit.status !== "planned") {
        await container.adminRepository.updateVisit({
          id: createdVisit.id,
          status: newVisit.status,
        });
      }

      const tasksToCreate = newVisitTasks.filter((task) => task.title.trim());
      await Promise.all(
        tasksToCreate.map((task) =>
          container.adminRepository.createContractTask({
            visitId: createdVisit.id,
            contractId: contract.id,
            title: task.title.trim(),
            month: Number(task.month) || 1,
          })
        )
      );

      setNewVisit(createEmptyVisitForm());
      setNewVisitTasks([]);
      await refreshAfterMutation();
    } catch (createError: any) {
      console.error("Error creating visit:", createError);
      setError(createError?.message || "تعذر إنشاء الزيارة");
    } finally {
      setSaving(false);
    }
  };

  const handleSaveVisit = async (visitId: string) => {
    if (saving) return;
    const draft = visitDrafts[visitId];
    if (!draft) return;

    setSavingVisitId(visitId);
    setError(null);
    try {
      await container.adminRepository.updateVisit({
        id: visitId,
        title: draft.title.trim() || null,
        visitDate: draft.visitDate,
        notes: draft.notes.trim() || null,
        status: draft.status,
      });
      await refreshAfterMutation();
    } catch (saveError: any) {
      console.error("Error updating visit:", saveError);
      setError(saveError?.message || "تعذر تحديث الزيارة");
    } finally {
      setSavingVisitId(null);
    }
  };

  const handleDeleteVisit = async (visitId: string) => {
    if (deletingVisitId) return;

    const confirmed = window.confirm("هل تريد حذف الزيارة وجميع مهامها؟");
    if (!confirmed) return;

    setDeletingVisitId(visitId);
    setError(null);
    try {
      const tasks = await container.adminRepository.listVisitTasks(visitId);
      await Promise.all(tasks.map((task) => container.adminRepository.deleteContractTask(task.id)));
      await container.adminRepository.deleteVisit(visitId);
      await refreshAfterMutation();
    } catch (deleteError: any) {
      console.error("Error deleting visit:", deleteError);
      setError(deleteError?.message || "تعذر حذف الزيارة");
    } finally {
      setDeletingVisitId(null);
    }
  };

  const handleAddTaskToVisit = async (visitId: string) => {
    const draft = taskDrafts[visitId];
    if (!draft || !draft.title.trim()) return;

    setError(null);
    try {
      await container.adminRepository.createContractTask({
        visitId,
        contractId: contract.id,
        title: draft.title.trim(),
        month: Number(draft.month) || 1,
      });
      setTaskDrafts((prev) => ({ ...prev, [visitId]: { title: "", month: "1" } }));
      await refreshAfterMutation();
    } catch (taskError: any) {
      console.error("Error creating task:", taskError);
      setError(taskError?.message || "تعذر إضافة المهمة");
    }
  };

  const handleDeleteTask = async (taskId: string) => {
    setError(null);
    try {
      await container.adminRepository.deleteContractTask(taskId);
      await refreshAfterMutation();
    } catch (taskError: any) {
      console.error("Error deleting task:", taskError);
      setError(taskError?.message || "تعذر حذف المهمة");
    }
  };

  const handleUpdateTaskStatus = async (taskId: string, status: TaskStatus) => {
    setUpdatingTaskId(taskId);
    setError(null);
    try {
      await container.adminRepository.updateContractTaskStatus(taskId, status);
      await refreshAfterMutation();
    } catch (err: any) {
      console.error("Error updating task status:", err);
      setError(err?.message || "تعذر تحديث حالة المهمة");
    } finally {
      setUpdatingTaskId(null);
    }
  };

  const statusOptions = useMemo(() => STATUS_OPTIONS, []);

  const visitsByTerm = useMemo(() => {
    const grouped: Record<string, VisitRow[]> = {};
    allTermOptions.forEach((item) => {
      grouped[item.key] = [];
    });

    visits.forEach((visit) => {
      const visitTerm = (visit.title || "").trim();
      const key = visitTerm && grouped[visitTerm] ? visitTerm : UNCATEGORIZED_TERM;
      if (!grouped[key]) grouped[key] = [];
      grouped[key].push(visit);
    });

    Object.values(grouped).forEach((termVisits) => {
      termVisits.sort((a, b) => a.visitDate.localeCompare(b.visitDate));
    });

    return grouped;
  }, [allTermOptions, visits]);

  const activeTermLabel = useMemo(
    () => allTermOptions.find((item) => item.key === activeTermKey)?.label || "البند",
    [activeTermKey, allTermOptions]
  );

  const activeVisits = visitsByTerm[activeTermKey] || [];

  return (
    <div style={{ position: "fixed", inset: 0, zIndex: 120, background: "rgba(0,0,0,0.55)", backdropFilter: "blur(6px)", display: "flex", alignItems: "center", justifyContent: "center", padding: 16 }}>
      <div style={{ width: "100%", maxWidth: 1160, maxHeight: "92vh", background: "#fff", borderRadius: 18, overflow: "hidden", boxShadow: "0 25px 70px rgba(15, 23, 42, 0.28)", display: "flex", flexDirection: "column" }}>
        <div style={{ padding: "18px 24px", borderBottom: "1px solid var(--neutral-200)", display: "flex", alignItems: "center", justifyContent: "space-between", gap: 16 }}>
          <div>
            <div style={{ display: "flex", alignItems: "center", gap: 10, color: "var(--text-primary)", fontWeight: 800, fontSize: "1.05rem" }}>
              <Calendar size={18} /> إدارة الزيارات والمهام
            </div>
            <div style={{ marginTop: 4, color: "var(--text-secondary)", fontSize: "0.85rem" }}>
              العقد {contract.code} - {clientName || contract.contractUserName || "بدون اسم"}
            </div>
          </div>
          <button onClick={onClose} style={{ border: "none", background: "var(--neutral-100)", color: "var(--text-secondary)", width: 36, height: 36, borderRadius: 10, cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center" }}>
            <X size={18} />
          </button>
        </div>

        <div style={{ padding: 24, overflow: "auto", display: "grid", gap: 20 }}>
          {error && (
            <div style={{ padding: 12, borderRadius: 12, background: "var(--color-error-bg)", color: "var(--color-error)", border: "1px solid var(--red-200)" }}>
              {error}
            </div>
          )}

          <div style={{ display: "grid", gridTemplateColumns: "minmax(260px, 320px) minmax(0, 1fr)", gap: 16, alignItems: "start" }}>
            <div style={{ border: "1px solid var(--neutral-200)", borderRadius: 16, background: "#fff", padding: 14, display: "grid", gap: 10, maxHeight: "72vh", overflow: "auto" }}>
              <div style={{ display: "flex", alignItems: "center", gap: 8, fontWeight: 800, color: "var(--text-primary)" }}>
                <ClipboardList size={16} /> البنود ({allTermOptions.length})
              </div>

              {allTermOptions.map((term) => {
                const termCount = visitsByTerm[term.key]?.length || 0;
                const isActive = activeTermKey === term.key;
                return (
                  <button
                    key={term.key}
                    type="button"
                    onClick={() => {
                      setActiveTermKey(term.key);
                      setNewVisitTermKey(term.key);
                    }}
                    style={{
                      width: "100%",
                      textAlign: "right",
                      borderRadius: 12,
                      border: `1px solid ${isActive ? "var(--color-primary)" : "var(--neutral-200)"}`,
                      background: isActive ? "var(--primary-light)" : "#fff",
                      padding: "10px 12px",
                      cursor: "pointer",
                      display: "grid",
                      gap: 4,
                    }}
                  >
                    <div style={{ fontWeight: 700, color: "var(--text-primary)" }}>{term.label}</div>
                    <div style={{ fontSize: "0.78rem", color: "var(--text-tertiary)" }}>{termCount} زيارة</div>
                  </button>
                );
              })}
            </div>

            <div style={{ display: "grid", gap: 14 }}>
              <div style={{ display: "flex", alignItems: "center", gap: 8, fontWeight: 800, color: "var(--text-primary)" }}>
                <CheckSquare size={18} /> {activeTermLabel} - الزيارات ({activeVisits.length})
              </div>

              <form onSubmit={handleCreateVisit} style={{ border: "1px solid var(--neutral-200)", borderRadius: 16, padding: 16, background: "var(--neutral-50)", display: "grid", gap: 14 }}>
                <div style={{ display: "flex", alignItems: "center", gap: 8, fontWeight: 800, color: "var(--text-primary)" }}>
                  <Plus size={18} /> إضافة زيارة جديدة
                </div>

                <div style={{ display: "grid", gridTemplateColumns: "repeat(4, minmax(0, 1fr))", gap: 10 }}>
                  <label style={{ display: "grid", gap: 6 }}>
                    <span style={{ fontSize: "0.82rem", fontWeight: 600, color: "var(--text-secondary)" }}>البند</span>
                    <select className="input" value={newVisitTermKey} onChange={(e) => setNewVisitTermKey(e.target.value)}>
                      {allTermOptions.map((term) => (
                        <option key={term.key} value={term.key}>{term.label}</option>
                      ))}
                    </select>
                  </label>
                  <label style={{ display: "grid", gap: 6 }}>
                    <span style={{ fontSize: "0.82rem", fontWeight: 600, color: "var(--text-secondary)" }}>تاريخ الزيارة</span>
                    <input type="date" className="input" value={newVisit.visitDate} onChange={(e) => setNewVisit((prev) => ({ ...prev, visitDate: e.target.value }))} />
                  </label>
                  <label style={{ display: "grid", gap: 6 }}>
                    <span style={{ fontSize: "0.82rem", fontWeight: 600, color: "var(--text-secondary)" }}>حالة الزيارة</span>
                    <select className="input" value={newVisit.status} onChange={(e) => setNewVisit((prev) => ({ ...prev, status: e.target.value as VisitStatus }))}>
                      {statusOptions.map((option) => (
                        <option key={option.value} value={option.value}>{option.label}</option>
                      ))}
                    </select>
                  </label>
                  <label style={{ display: "grid", gap: 6 }}>
                    <span style={{ fontSize: "0.82rem", fontWeight: 600, color: "var(--text-secondary)" }}>ملاحظات الزيارة</span>
                    <input className="input" value={newVisit.notes} onChange={(e) => setNewVisit((prev) => ({ ...prev, notes: e.target.value }))} placeholder="وصف مختصر" />
                  </label>
                </div>

                <div style={{ display: "grid", gap: 10 }}>
                  <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 12 }}>
                    <div style={{ display: "flex", alignItems: "center", gap: 8, fontWeight: 700, color: "var(--text-primary)" }}>
                      <ClipboardList size={16} /> مهام الزيارة
                    </div>
                    <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                      <button type="button" onClick={addNewVisitTask} className="button secondary" style={{ padding: "8px 12px", borderRadius: 10, display: "inline-flex", alignItems: "center", gap: 8 }}>
                        <Plus size={14} /> إضافة مهمة
                      </button>
                      <button
                        type="button"
                        className="button secondary"
                        onClick={() => {
                          const selectedLabel = allTermOptions.find((term) => term.key === newVisitTermKey)?.label;
                          if (!selectedLabel || newVisitTermKey === UNCATEGORIZED_TERM) return;
                          const defaults = getTermDefaultTasks(selectedLabel);
                          if (defaults.length > 0) setNewVisitTasks(defaults);
                        }}
                        disabled={newVisitTermKey === UNCATEGORIZED_TERM}
                        style={{ padding: "8px 12px", borderRadius: 10 }}
                      >
                        تحميل مهام البند
                      </button>
                    </div>
                  </div>

                  {newVisitTasks.length === 0 ? (
                    <div style={{ padding: 14, borderRadius: 12, border: "1px dashed var(--neutral-300)", color: "var(--text-tertiary)", background: "#fff" }}>
                      أضف المهام يدويًا أو استخدم زر تحميل مهام البند.
                    </div>
                  ) : (
                    <div style={{ display: "grid", gap: 10 }}>
                      {newVisitTasks.map((task, index) => (
                        <div key={`${index}-${task.month}`} style={{ display: "grid", gridTemplateColumns: "1fr 120px auto", gap: 10, alignItems: "center" }}>
                          <input className="input" value={task.title} onChange={(e) => updateNewVisitTask(index, "title", e.target.value)} placeholder="عنوان المهمة" />
                          <input className="input" type="number" min="1" value={task.month} onChange={(e) => updateNewVisitTask(index, "month", e.target.value)} placeholder="الشهر" />
                          <button type="button" onClick={() => removeNewVisitTask(index)} style={{ border: "none", background: "var(--color-error-bg)", color: "var(--color-error)", width: 36, height: 36, borderRadius: 10, cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center" }}>
                            <X size={16} />
                          </button>
                        </div>
                      ))}
                    </div>
                  )}
                </div>

                <div style={{ display: "flex", justifyContent: "flex-end" }}>
                  <button type="submit" className="button" disabled={saving} style={{ display: "inline-flex", alignItems: "center", gap: 8, padding: "10px 16px", borderRadius: 10 }}>
                    {saving ? <Loader2 size={16} className="spin" /> : <Save size={16} />}
                    {saving ? "جار الحفظ..." : "حفظ الزيارة"}
                  </button>
                </div>
              </form>

              {loading ? (
                <div style={{ padding: 40, borderRadius: 16, background: "var(--neutral-50)", textAlign: "center", color: "var(--text-secondary)" }}>
                  <Loader2 size={18} className="spin" style={{ marginInlineEnd: 8, verticalAlign: "middle" }} />
                  جاري تحميل الزيارات...
                </div>
              ) : activeVisits.length === 0 ? (
                <div style={{ padding: 28, borderRadius: 16, border: "1px dashed var(--neutral-300)", color: "var(--text-tertiary)", textAlign: "center" }}>
                  لا توجد زيارات داخل هذا البند.
                </div>
              ) : (
                activeVisits.map((visit) => {
                const draft = visitDrafts[visit.id] ?? {
                  title: (visit.title || "").trim(),
                  visitDate: visit.visitDate,
                  notes: visit.notes || "",
                  status: visit.status,
                };
                const taskDraft = taskDrafts[visit.id] ?? { title: "", month: "1" };
                const isVisitEditable = visit.status === "planned";
                const areTasksEditable = visit.status !== "cancelled";
                const statusTone = STATUS_COLORS[visit.status] || STATUS_COLORS.planned;
                const draftTermKey = draft.title && allTermOptions.some((item) => item.key === draft.title) ? draft.title : UNCATEGORIZED_TERM;

                return (
                  <div key={visit.id} style={{ border: "1px solid var(--neutral-200)", borderRadius: 16, background: "#fff", padding: 18, display: "grid", gap: 14 }}>
                    <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", gap: 16 }}>
                      <div style={{ display: "grid", gap: 4 }}>
                        <div style={{ fontWeight: 800, color: "var(--text-primary)" }}>
                          {visit.notes || "زيارة بدون ملاحظات"}
                        </div>
                        <div style={{ fontSize: "0.82rem", color: "var(--text-tertiary)", display: "flex", alignItems: "center", gap: 8, flexWrap: "wrap" }}>
                          <span style={{ display: "inline-flex", alignItems: "center", gap: 4 }}>
                            <Calendar size={12} /> {formatDate(visit.visitDate)}
                          </span>
                          <span>• {visit.tasks.length} مهمة</span>
                          {visit.completedAt ? (
                            <span style={{ display: "inline-flex", alignItems: "center", gap: 4, color: "#15803d", fontWeight: 600 }}>
                              <Clock size={12} /> تم الإنهاء: {formatDate(visit.completedAt)}
                            </span>
                          ) : null}
                          <span style={{ background: statusTone.bg, color: statusTone.color, borderRadius: 999, padding: "2px 8px", fontWeight: 700 }}>
                            {STATUS_LABELS[visit.status]}
                          </span>
                        </div>
                        {!isVisitEditable ? (
                          <div style={{ fontSize: "0.78rem", color: areTasksEditable ? "#b45309" : "#b91c1c" }}>
                            {areTasksEditable
                              ? "بيانات الزيارة مقفلة — يمكن تعديل حالة المهام فقط."
                              : "الزيارة ملغاة — لا يمكن إجراء أي تعديل."}
                          </div>
                        ) : null}
                      </div>
                      <button
                        type="button"
                        onClick={() => handleDeleteVisit(visit.id)}
                        disabled={deletingVisitId === visit.id || !isVisitEditable}
                        style={{
                          border: "none",
                          background: "var(--color-error-bg)",
                          color: "var(--color-error)",
                          padding: "8px 12px",
                          borderRadius: 10,
                          cursor: deletingVisitId === visit.id || !isVisitEditable ? "not-allowed" : "pointer",
                          opacity: deletingVisitId === visit.id || !isVisitEditable ? 0.6 : 1,
                          display: "inline-flex",
                          alignItems: "center",
                          gap: 8,
                        }}
                      >
                        {deletingVisitId === visit.id ? <Loader2 size={14} className="spin" /> : <Trash2 size={14} />}
                        حذف الزيارة
                      </button>
                    </div>

                    <div style={{ display: "grid", gridTemplateColumns: "repeat(4, minmax(0, 1fr))", gap: 12 }}>
                      <label style={{ display: "grid", gap: 6 }}>
                        <span style={{ fontSize: "0.85rem", fontWeight: 600, color: "var(--text-secondary)" }}>البند</span>
                        <select
                          className="input"
                          value={draftTermKey}
                          disabled={!isVisitEditable}
                          onChange={(e) => {
                            const selected = allTermOptions.find((item) => item.key === e.target.value);
                            const nextTitle = selected && selected.key !== UNCATEGORIZED_TERM ? selected.label : "";
                            setVisitDrafts((prev) => ({
                              ...prev,
                              [visit.id]: { ...draft, title: nextTitle },
                            }));
                          }}
                        >
                          {allTermOptions.map((term) => (
                            <option key={term.key} value={term.key}>{term.label}</option>
                          ))}
                        </select>
                      </label>
                      <label style={{ display: "grid", gap: 6 }}>
                        <span style={{ fontSize: "0.85rem", fontWeight: 600, color: "var(--text-secondary)" }}>تاريخ الزيارة</span>
                        <input
                          type="date"
                          className="input"
                          value={draft.visitDate}
                          disabled={!isVisitEditable}
                          onChange={(e) => setVisitDrafts((prev) => ({
                            ...prev,
                            [visit.id]: { ...draft, visitDate: e.target.value },
                          }))}
                        />
                      </label>
                      <label style={{ display: "grid", gap: 6 }}>
                        <span style={{ fontSize: "0.85rem", fontWeight: 600, color: "var(--text-secondary)" }}>حالة الزيارة</span>
                        <select
                          className="input"
                          value={draft.status}
                          disabled={!isVisitEditable}
                          onChange={(e) => setVisitDrafts((prev) => ({
                            ...prev,
                            [visit.id]: { ...draft, status: e.target.value as VisitStatus },
                          }))}
                        >
                          {statusOptions.map((option) => (
                            <option key={option.value} value={option.value}>{option.label}</option>
                          ))}
                        </select>
                      </label>
                      <label style={{ display: "grid", gap: 6 }}>
                        <span style={{ fontSize: "0.85rem", fontWeight: 600, color: "var(--text-secondary)" }}>ملاحظات الزيارة</span>
                        <input
                          className="input"
                          value={draft.notes}
                          disabled={!isVisitEditable}
                          onChange={(e) => setVisitDrafts((prev) => ({
                            ...prev,
                            [visit.id]: { ...draft, notes: e.target.value },
                          }))}
                          placeholder="وصف الزيارة"
                        />
                      </label>
                    </div>

                    <div style={{ display: "grid", gap: 10 }}>
                      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 12 }}>
                        <div style={{ display: "flex", alignItems: "center", gap: 8, fontWeight: 700, color: "var(--text-primary)" }}>
                          <ClipboardList size={16} /> مهام الزيارة
                        </div>
                        <button
                          type="button"
                          onClick={() => handleSaveVisit(visit.id)}
                          disabled={savingVisitId === visit.id || !isVisitEditable}
                          className="button"
                          style={{ padding: "8px 12px", borderRadius: 10, display: "inline-flex", alignItems: "center", gap: 8, opacity: savingVisitId === visit.id || !isVisitEditable ? 0.6 : 1 }}
                        >
                          {savingVisitId === visit.id ? <Loader2 size={14} className="spin" /> : <Save size={14} />}
                          حفظ التعديل
                        </button>
                      </div>

                      {visit.tasks.length === 0 ? (
                        <div style={{ padding: 14, borderRadius: 12, border: "1px dashed var(--neutral-300)", color: "var(--text-tertiary)", background: "var(--neutral-50)" }}>
                          لا توجد مهام مرتبطة بهذه الزيارة.
                        </div>
                      ) : (
                        <div style={{ display: "grid", gap: 10 }}>
                          {visit.tasks.map((task) => (
                            <div key={task.id} style={{ display: "grid", gridTemplateColumns: "1fr 60px 140px auto", gap: 10, alignItems: "center", border: "1px solid var(--neutral-200)", borderRadius: 12, padding: "10px 12px" }}>
                              <div style={{ fontSize: "0.9rem", color: "var(--text-primary)", fontWeight: 600 }}>
                                {task.title}
                              </div>
                              <div style={{ fontSize: "0.8rem", color: "var(--text-tertiary)", whiteSpace: "nowrap" }}>
                                ش {task.month}
                              </div>
                              <select
                                className="input"
                                value={task.status}
                                disabled={!areTasksEditable || updatingTaskId === task.id}
                                onChange={(e) => handleUpdateTaskStatus(task.id, e.target.value as TaskStatus)}
                                style={{ fontSize: "0.82rem", padding: "4px 8px", borderRadius: 8, opacity: !areTasksEditable || updatingTaskId === task.id ? 0.6 : 1, cursor: !areTasksEditable ? "not-allowed" : "pointer" }}
                              >
                                {TASK_STATUS_OPTIONS.map((opt) => (
                                  <option key={opt.value} value={opt.value}>{opt.label}</option>
                                ))}
                              </select>
                              <button
                                type="button"
                                onClick={() => handleDeleteTask(task.id)}
                                disabled={!isVisitEditable}
                                style={{ border: "none", background: "var(--color-error-bg)", color: "var(--color-error)", width: 36, height: 36, borderRadius: 10, cursor: !isVisitEditable ? "not-allowed" : "pointer", opacity: !isVisitEditable ? 0.6 : 1, display: "flex", alignItems: "center", justifyContent: "center" }}
                              >
                                <Trash2 size={16} />
                              </button>
                            </div>
                          ))}
                        </div>
                      )}

                      <div style={{ display: "grid", gridTemplateColumns: "1fr 120px auto", gap: 10, alignItems: "center" }}>
                        <input
                          className="input"
                          value={taskDraft.title}
                          disabled={!isVisitEditable}
                          onChange={(e) => setTaskDrafts((prev) => ({ ...prev, [visit.id]: { ...taskDraft, title: e.target.value } }))}
                          placeholder="مهمة جديدة"
                        />
                        <input
                          className="input"
                          type="number"
                          min="1"
                          value={taskDraft.month}
                          disabled={!isVisitEditable}
                          onChange={(e) => setTaskDrafts((prev) => ({ ...prev, [visit.id]: { ...taskDraft, month: e.target.value } }))}
                          placeholder="الشهر"
                        />
                        <button
                          type="button"
                          onClick={() => handleAddTaskToVisit(visit.id)}
                          disabled={!isVisitEditable}
                          className="button secondary"
                          style={{ padding: "8px 12px", borderRadius: 10, display: "inline-flex", alignItems: "center", gap: 8, opacity: !isVisitEditable ? 0.6 : 1 }}
                        >
                          <Plus size={14} /> إضافة
                        </button>
                      </div>
                    </div>
                  </div>
                );
                })
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};