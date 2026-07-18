import React, { useEffect, useMemo, useState } from "react";
import {
  Calendar,
  CheckSquare,
  ChevronDown,
  ChevronLeft,
  ClipboardList,
  FileText,
  Pencil,
  Plus,
  Save,
  Search,
  Trash2,
  X,
} from "lucide-react";

import { container } from "@infrastructure/di/container";
import { ContractType } from "@domain/entities/ContractType";
import { ContractTerm, TaskTemplate, VisitTemplate } from "@domain/entities/ContractTerm";
import { createContractType } from "@application/use-cases/admin/createContractType";
import { updateContractType } from "@application/use-cases/admin/updateContractType";
import { deleteContractType } from "@application/use-cases/admin/deleteContractType";
import { getContractTypes } from "@application/use-cases/admin/getContractTypes";
import { useToast } from "@presentation/components/ToastProvider";
import { ErrorState, LoadingState } from "@presentation/components/States";

export const ContractTypesPage: React.FC = () => {
  const [types, setTypes] = useState<ContractType[]>([]);
  const [isLoading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [searchQuery, setSearchQuery] = useState("");
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [editingType, setEditingType] = useState<ContractType | null>(null);
  const [deletingType, setDeletingType] = useState<ContractType | null>(null);

  const { notify } = useToast();

  useEffect(() => {
    void loadTypes();
  }, []);

  const loadTypes = async () => {
    setLoading(true);
    setError(null);
    const result = await getContractTypes(container.adminRepository);
    if (result.ok) {
      setTypes(result.data);
    } else {
      setError(result.error?.message || "فشل تحميل البيانات");
    }
    setLoading(false);
  };

  const confirmDelete = async () => {
    if (!deletingType) return;

    const result = await deleteContractType(container.adminRepository, deletingType.id);
    if (result.ok) {
      notify("تم حذف نوع العقد بنجاح");
      setDeletingType(null);
      await loadTypes();
      return;
    }

    notify(result.error?.message || "فشل الحذف");
  };

  const filteredTypes = useMemo(
    () =>
      types.filter(
        (type) =>
          type.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
          (type.description || "").toLowerCase().includes(searchQuery.toLowerCase()),
      ),
    [types, searchQuery],
  );

  if (isLoading) return <LoadingState />;
  if (error) return <ErrorState text={error} />;

  return (
    <div
      className="contract-types-page"
      style={{
        height: "calc(100vh - 112px)",
        display: "flex",
        flexDirection: "column",
        gap: "18px",
      }}
    >
      <section
        className="card contract-types-hero"
        style={{
          padding: "18px 20px",
          display: "grid",
          gridTemplateColumns: "1fr",
          alignItems: "center",
          gap: "16px",
          borderColor: "var(--color-border)",
        }}
      >
        <div className="contract-types-hero-content" style={{ display: "flex", alignItems: "center", gap: "14px" }}>
          <div
            style={{
              width: "44px",
              height: "44px",
              borderRadius: "12px",
              background: "linear-gradient(135deg, var(--green-50), var(--green-100))",
              color: "var(--color-primary)",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              border: "1px solid var(--color-border)",
            }}
          >
            <ClipboardList size={22} />
          </div>

          <div>
            <h2 style={{ margin: 0, fontSize: "1.2rem", color: "var(--text-primary)", fontWeight: 800 }}>
              أنواع العقود
            </h2>
            <p style={{ margin: "4px 0 0", color: "var(--text-secondary)", fontSize: "0.86rem" }}>
              إدارة تصنيفات العقود، والبنود، وقوالب الزيارات والمهام
            </p>
          </div>
        </div>
      </section>

      <section
        className="card contract-types-toolbar"
        style={{
          padding: "12px 14px",
          display: "flex",
          gap: "10px",
          alignItems: "center",
          justifyContent: "space-between",
          borderColor: "var(--color-border)",
        }}
      >
        <div
          className="contract-types-search-wrap"
          style={{ position: "relative", minWidth: "290px", maxWidth: "420px", width: "100%" }}
        >
          <Search
            size={17}
            style={{
              position: "absolute",
              right: "12px",
              top: "50%",
              transform: "translateY(-50%)",
              color: "var(--text-tertiary)",
            }}
          />
          <input
            type="text"
            className="input"
            value={searchQuery}
            onChange={(event) => setSearchQuery(event.target.value)}
            placeholder="ابحث باسم النوع أو الوصف..."
            style={{ paddingRight: "36px" }}
          />
        </div>

        <button className="button contract-types-create-button" onClick={() => setShowCreateModal(true)}>
          <Plus size={17} />
          إضافة نوع جديد
        </button>
      </section>

      <section
        style={{
          flex: 1,
          overflowY: "auto",
          paddingRight: "4px",
        }}
      >
        {filteredTypes.length === 0 ? (
          <div
            className="card contract-types-empty-state"
            style={{
              minHeight: "280px",
              display: "flex",
              flexDirection: "column",
              justifyContent: "center",
              alignItems: "center",
              gap: "12px",
              borderStyle: "dashed",
              color: "var(--text-tertiary)",
            }}
          >
            <Search size={34} />
            <h3 style={{ margin: 0, color: "var(--text-secondary)", fontSize: "1rem" }}>لا توجد نتائج</h3>
            <p style={{ margin: 0, fontSize: "0.86rem" }}>جرّب كلمات بحث مختلفة أو أضف نوعًا جديدًا</p>
          </div>
        ) : (
          <div
            className="contract-types-types-grid"
            style={{
              display: "grid",
              gridTemplateColumns: "repeat(auto-fill, minmax(310px, 1fr))",
              gap: "14px",
              alignItems: "stretch",
            }}
          >
            {filteredTypes.map((type) => (
              <ContractTypeCard
                key={type.id}
                type={type}
                onEdit={() => setEditingType(type)}
                onDelete={() => setDeletingType(type)}
              />
            ))}

            <button
              className="contract-types-add-card"
              onClick={() => setShowCreateModal(true)}
              style={{
                border: "2px dashed var(--color-border)",
                borderRadius: "var(--radius-lg)",
                background: "var(--bg-card)",
                minHeight: "220px",
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                justifyContent: "center",
                gap: "10px",
                color: "var(--text-secondary)",
                cursor: "pointer",
                transition: "all 0.15s",
              }}
              onMouseEnter={(event) => {
                event.currentTarget.style.borderColor = "var(--color-primary)";
                event.currentTarget.style.color = "var(--color-primary)";
              }}
              onMouseLeave={(event) => {
                event.currentTarget.style.borderColor = "var(--color-border)";
                event.currentTarget.style.color = "var(--text-secondary)";
              }}
            >
              <div
                style={{
                  width: "48px",
                  height: "48px",
                  borderRadius: "12px",
                  background: "var(--bg-subtle)",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                }}
              >
                <Plus size={24} />
              </div>
              <span style={{ fontWeight: 700 }}>إضافة نوع جديد</span>
            </button>
          </div>
        )}
      </section>

      {showCreateModal && (
        <CreateTypeModal
          onClose={() => setShowCreateModal(false)}
          onSuccess={async () => {
            setShowCreateModal(false);
            await loadTypes();
          }}
        />
      )}

      {editingType && (
        <EditTypeModal
          type={editingType}
          onClose={() => setEditingType(null)}
          onSuccess={async () => {
            setEditingType(null);
            await loadTypes();
          }}
        />
      )}

      {deletingType && (
        <Modal title="تأكيد الحذف" onClose={() => setDeletingType(null)} size="sm">
          <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
            <p style={{ margin: 0, color: "var(--text-secondary)", lineHeight: 1.7 }}>
              هل تريد حذف نوع العقد <strong style={{ color: "var(--text-primary)" }}>{deletingType.name}</strong>؟
            </p>

            {(deletingType.contractCount || 0) > 0 && (
              <div
                style={{
                  padding: "10px 12px",
                  borderRadius: "var(--radius-md)",
                  background: "var(--color-error-bg)",
                  color: "var(--color-error)",
                  fontSize: "0.86rem",
                  border: "1px solid rgba(211, 47, 47, 0.2)",
                }}
              >
                هذا النوع مرتبط بـ {deletingType.contractCount} عقد. بعد الحذف ستصبح العقود بدون نوع.
              </div>
            )}

            <div style={{ display: "flex", gap: "8px", justifyContent: "flex-end" }}>
              <button className="button secondary" onClick={() => setDeletingType(null)}>
                إلغاء
              </button>
              <button className="button danger" onClick={confirmDelete}>
                تأكيد الحذف
              </button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
};

const ContractTypeCard = ({
  type,
  onEdit,
  onDelete,
}: {
  type: ContractType;
  onEdit: () => void;
  onDelete: () => void;
}) => {
  const termsCount = type.terms?.length || 0;

  return (
    <article
      className="card"
      style={{
        padding: "16px",
        display: "flex",
        flexDirection: "column",
        gap: "12px",
        borderColor: "var(--color-border)",
      }}
    >
      <div style={{ display: "flex", justifyContent: "space-between", gap: "8px", alignItems: "flex-start" }}>
        <div
          style={{
            width: "40px",
            height: "40px",
            borderRadius: "11px",
            background: "var(--bg-subtle)",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            color: "var(--color-primary)",
            border: "1px solid var(--color-border)",
            flexShrink: 0,
          }}
        >
          <FileText size={20} />
        </div>

        <div style={{ display: "flex", gap: "6px" }}>
          <button className="icon-button" onClick={onEdit} title="تعديل">
            <Pencil size={15} />
          </button>
          <button className="icon-button danger" onClick={onDelete} title="حذف">
            <Trash2 size={15} />
          </button>
        </div>
      </div>

      <div>
        <h3
          style={{
            margin: "0 0 6px",
            fontSize: "1rem",
            color: "var(--text-primary)",
            fontWeight: 700,
          }}
        >
          {type.name}
        </h3>

        <p
          style={{
            margin: 0,
            color: "var(--text-secondary)",
            fontSize: "0.86rem",
            lineHeight: 1.7,
            minHeight: "48px",
          }}
        >
          {type.description || "لا يوجد وصف"}
        </p>
      </div>

      <div style={{ marginTop: "auto", display: "flex", gap: "6px", flexWrap: "wrap" }}>
        <MetaBadge label={`${type.contractCount || 0} عقود`} />
        <MetaBadge label={`${termsCount} بنود`} />
      </div>
    </article>
  );
};

const MetaBadge = ({ label }: { label: string }) => (
  <span
    style={{
      padding: "4px 9px",
      borderRadius: "var(--radius-full)",
      fontSize: "0.74rem",
      fontWeight: 600,
      color: "var(--text-secondary)",
      background: "var(--bg-subtle)",
      border: "1px solid var(--color-border)",
    }}
  >
    {label}
  </span>
);

const CreateTypeModal: React.FC<{ onClose: () => void; onSuccess: () => void }> = ({ onClose, onSuccess }) => {
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [terms, setTerms] = useState<ContractTerm[]>([]);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const { notify } = useToast();

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!name.trim()) return;

    setIsSubmitting(true);
    const result = await createContractType(container.adminRepository, {
      name,
      description,
      terms,
    });

    if (result.ok) {
      notify("تم إنشاء نوع العقد بنجاح");
      onSuccess();
    } else {
      notify(result.error?.message || "حدث خطأ أثناء الإنشاء");
    }

    setIsSubmitting(false);
  };

  return (
    <Modal title="إضافة نوع عقد جديد" onClose={onClose}>
      <form className="contract-types-modal-form" onSubmit={handleSubmit} style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
        <Field label="اسم النوع" required>
          <input
            type="text"
            className="input"
            value={name}
            onChange={(event) => setName(event.target.value)}
            placeholder="مثال: تعاقد سنوي"
            required
          />
        </Field>

        <Field label="الوصف">
          <textarea
            className="textarea"
            rows={3}
            style={{ resize: "none" }}
            value={description}
            onChange={(event) => setDescription(event.target.value)}
            placeholder="وصف مختصر لنوع العقد"
          />
        </Field>

        <TermsEditor terms={terms} onChange={setTerms} />

        <ModalActions
          isSubmitting={isSubmitting}
          submitText="حفظ"
          loadingText="جاري الحفظ..."
          onClose={onClose}
        />
      </form>
    </Modal>
  );
};

const EditTypeModal: React.FC<{ type: ContractType; onClose: () => void; onSuccess: () => void }> = ({
  type,
  onClose,
  onSuccess,
}) => {
  const [name, setName] = useState(type.name);
  const [description, setDescription] = useState(type.description || "");
  const [terms, setTerms] = useState<ContractTerm[]>(type.terms || []);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const { notify } = useToast();

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!name.trim()) return;

    setIsSubmitting(true);
    const result = await updateContractType(container.adminRepository, {
      id: type.id,
      name,
      description,
      terms,
    });

    if (result.ok) {
      notify("تم تحديث نوع العقد بنجاح");
      onSuccess();
    } else {
      notify(result.error?.message || "حدث خطأ أثناء التعديل");
    }

    setIsSubmitting(false);
  };

  return (
    <Modal title="تعديل نوع العقد" onClose={onClose}>
      <form className="contract-types-modal-form" onSubmit={handleSubmit} style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
        <Field label="اسم النوع" required>
          <input
            type="text"
            className="input"
            value={name}
            onChange={(event) => setName(event.target.value)}
            required
          />
        </Field>

        <Field label="الوصف">
          <textarea
            className="textarea"
            rows={3}
            style={{ resize: "none" }}
            value={description}
            onChange={(event) => setDescription(event.target.value)}
          />
        </Field>

        <TermsEditor terms={terms} onChange={setTerms} />

        <ModalActions
          isSubmitting={isSubmitting}
          submitText="حفظ التعديلات"
          loadingText="جاري الحفظ..."
          onClose={onClose}
        />
      </form>
    </Modal>
  );
};

const ModalActions = ({
  isSubmitting,
  submitText,
  loadingText,
  onClose,
}: {
  isSubmitting: boolean;
  submitText: string;
  loadingText: string;
  onClose: () => void;
}) => (
  <div
    className="contract-types-modal-actions"
    style={{
      display: "flex",
      justifyContent: "flex-end",
      gap: "8px",
      borderTop: "1px solid var(--color-border)",
      paddingTop: "12px",
      marginTop: "4px",
    }}
  >
    <button type="button" className="button secondary" onClick={onClose}>
      إلغاء
    </button>
    <button type="submit" className="button" disabled={isSubmitting}>
      <Save size={16} />
      {isSubmitting ? loadingText : submitText}
    </button>
  </div>
);

const Field = ({
  label,
  required,
  children,
}: {
  label: string;
  required?: boolean;
  children: React.ReactNode;
}) => (
  <label style={{ display: "flex", flexDirection: "column", gap: "6px" }}>
    <span style={{ fontSize: "0.84rem", fontWeight: 700, color: "var(--text-secondary)" }}>
      {label}
      {required ? <span style={{ color: "var(--color-error)", marginRight: "4px" }}>*</span> : null}
    </span>
    {children}
  </label>
);

const Modal = ({
  title,
  onClose,
  children,
  size = "lg",
}: {
  title: string;
  onClose: () => void;
  children: React.ReactNode;
  size?: "lg" | "sm";
}) => (
  <div
    className="contract-types-modal-overlay"
    style={{
      position: "fixed",
      inset: 0,
      background: "rgba(17, 24, 39, 0.56)",
      backdropFilter: "blur(4px)",
      display: "flex",
      justifyContent: "center",
      alignItems: "center",
      zIndex: 120,
      padding: "20px",
    }}
  >
    <div
      className="card contract-types-modal-card"
      style={{
        width: "100%",
        maxWidth: size === "sm" ? "480px" : "760px",
        maxHeight: "92vh",
        overflowY: "auto",
        padding: "16px",
      }}
    >
      <div
        className="contract-types-modal-head"
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          borderBottom: "1px solid var(--color-border)",
          paddingBottom: "10px",
          marginBottom: "12px",
        }}
      >
        <h3 className="contract-types-modal-title" style={{ margin: 0, fontSize: "1.04rem", color: "var(--text-primary)", fontWeight: 800 }}>
          {title}
        </h3>

        <button
          className="icon-button"
          onClick={onClose}
          style={{ background: "var(--bg-subtle)", border: "1px solid var(--color-border)" }}
        >
          <X size={18} />
        </button>
      </div>

      {children}
    </div>
  </div>
);

const TermsEditor: React.FC<{
  terms: ContractTerm[];
  onChange: (terms: ContractTerm[]) => void;
}> = ({ terms, onChange }) => {
  const [expandedTermId, setExpandedTermId] = useState<string | null>(null);
  const [expandedVisitId, setExpandedVisitId] = useState<string | null>(null);

  const generateId = () => Math.random().toString(36).slice(2, 11);

  const addTerm = () => {
    onChange([...terms, { id: generateId(), content: "", visits: [] }]);
  };

  const updateTerm = (termId: string, content: string) => {
    onChange(terms.map((term) => (term.id === termId ? { ...term, content } : term)));
  };

  const removeTerm = (termId: string) => {
    onChange(terms.filter((term) => term.id !== termId));
    if (expandedTermId === termId) {
      setExpandedTermId(null);
    }
  };

  const addVisit = (termId: string) => {
    onChange(
      terms.map((term) =>
        term.id === termId
          ? {
              ...term,
              visits: [...(term.visits || []), { id: generateId(), description: "", tasks: [] }],
            }
          : term,
      ),
    );
  };

  const updateVisit = (termId: string, visitId: string, fields: Partial<VisitTemplate>) => {
    onChange(
      terms.map((term) =>
        term.id === termId
          ? {
              ...term,
              visits: (term.visits || []).map((visit) =>
                visit.id === visitId ? { ...visit, ...fields } : visit,
              ),
            }
          : term,
      ),
    );
  };

  const removeVisit = (termId: string, visitId: string) => {
    onChange(
      terms.map((term) =>
        term.id === termId
          ? {
              ...term,
              visits: (term.visits || []).filter((visit) => visit.id !== visitId),
            }
          : term,
      ),
    );

    if (expandedVisitId === visitId) {
      setExpandedVisitId(null);
    }
  };

  const addTask = (termId: string, visitId: string) => {
    onChange(
      terms.map((term) =>
        term.id === termId
          ? {
              ...term,
              visits: (term.visits || []).map((visit) =>
                visit.id === visitId
                  ? { ...visit, tasks: [...visit.tasks, { id: generateId(), title: "" }] }
                  : visit,
              ),
            }
          : term,
      ),
    );
  };

  const updateTask = (termId: string, visitId: string, taskId: string, title: string) => {
    onChange(
      terms.map((term) =>
        term.id === termId
          ? {
              ...term,
              visits: (term.visits || []).map((visit) =>
                visit.id === visitId
                  ? {
                      ...visit,
                      tasks: visit.tasks.map((task) => (task.id === taskId ? { ...task, title } : task)),
                    }
                  : visit,
              ),
            }
          : term,
      ),
    );
  };

  const removeTask = (termId: string, visitId: string, taskId: string) => {
    onChange(
      terms.map((term) =>
        term.id === termId
          ? {
              ...term,
              visits: (term.visits || []).map((visit) =>
                visit.id === visitId
                  ? { ...visit, tasks: visit.tasks.filter((task) => task.id !== taskId) }
                  : visit,
              ),
            }
          : term,
      ),
    );
  };

  const selectedTerm = expandedTermId ? terms.find((t) => t.id === expandedTermId) : null;
  const selectedTermVisits = selectedTerm?.visits || [];

  return (
    <div
      className="contract-types-terms-editor"
      style={{
        borderTop: "1px solid var(--color-border)",
        paddingTop: "12px",
        display: "flex",
        flexDirection: "column",
        gap: "10px",
      }}
    >
      <div className="contract-types-editor-header" style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <h4
          style={{
            margin: 0,
            fontSize: "0.9rem",
            color: "var(--text-primary)",
            fontWeight: 700,
            display: "flex",
            alignItems: "center",
            gap: "6px",
          }}
        >
          <ClipboardList size={15} />
          البنود والزيارات والمهام
        </h4>

        <button type="button" className="button secondary contract-types-add-term-button" onClick={addTerm} style={{ padding: "6px 10px" }}>
          <Plus size={14} />
          بند جديد
        </button>
      </div>

      {terms.length === 0 ? (
        <div
          style={{
            padding: "14px",
            borderRadius: "var(--radius-md)",
            border: "1px dashed var(--color-border)",
            textAlign: "center",
            color: "var(--text-tertiary)",
            fontSize: "0.82rem",
          }}
        >
          لا توجد بنود مضافة حتى الآن
        </div>
      ) : (
        <div className="contract-types-terms-grid" style={{ display: "grid", gridTemplateColumns: "280px 1fr", gap: "12px", minHeight: "400px" }}>
          {/* Terms List (Left Column) */}
          <div
            className="contract-types-terms-list"
            style={{
              border: "1px solid var(--color-border)",
              borderRadius: "8px",
              overflow: "hidden",
              display: "flex",
              flexDirection: "column",
              maxHeight: "420px",
            }}
          >
            <div
              style={{
                background: "var(--bg-subtle)",
                padding: "10px",
                borderBottom: "1px solid var(--color-border)",
                fontSize: "0.75rem",
                fontWeight: 600,
                color: "var(--text-tertiary)",
              }}
            >
              البنود ({terms.length})
            </div>

            <div style={{ overflowY: "auto", flex: 1 }}>
              {terms.map((term, index) => (
                <div
                  key={term.id}
                  className="contract-types-term-row"
                  onClick={() => setExpandedTermId(expandedTermId === term.id ? null : term.id)}
                  style={{
                    padding: "10px",
                    borderBottom: "1px solid var(--color-border)",
                    cursor: "pointer",
                    background: expandedTermId === term.id ? "var(--bg-card)" : "transparent",
                    borderRight: expandedTermId === term.id ? "3px solid var(--color-primary)" : "3px solid transparent",
                    transition: "all 0.2s",
                    display: "flex",
                    alignItems: "center",
                    gap: "8px",
                  }}
                >
                  <span
                    style={{
                      width: "20px",
                      flexShrink: 0,
                      color: "var(--text-tertiary)",
                      fontWeight: 600,
                      fontSize: "0.75rem",
                    }}
                  >
                    {index + 1}
                  </span>

                  <input
                    className="input"
                    value={term.content}
                    onChange={(event) => {
                      event.stopPropagation();
                      updateTerm(term.id, event.target.value);
                    }}
                    onClick={(e) => e.stopPropagation()}
                    placeholder="نص البند..."
                    style={{
                      flex: 1,
                      fontSize: "0.82rem",
                    }}
                  />

                  <button
                    type="button"
                    className="icon-button danger"
                    onClick={(e) => {
                      e.stopPropagation();
                      removeTerm(term.id);
                    }}
                    title="حذف البند"
                    style={{ flexShrink: 0 }}
                  >
                    <Trash2 size={14} />
                  </button>
                </div>
              ))}
            </div>
          </div>

          {/* Visits and Tasks (Right Column) */}
          <div
            className="contract-types-term-details"
            style={{
              border: "1px solid var(--color-border)",
              borderRadius: "8px",
              overflow: "hidden",
              display: "flex",
              flexDirection: "column",
            }}
          >
            {selectedTerm ? (
              <>
                <div
                  style={{
                    background: "var(--bg-subtle)",
                    padding: "12px",
                    borderBottom: "1px solid var(--color-border)",
                    display: "flex",
                    justifyContent: "space-between",
                    alignItems: "center",
                  }}
                >
                  <span
                    style={{
                      fontSize: "0.75rem",
                      fontWeight: 600,
                      color: "var(--text-tertiary)",
                    }}
                  >
                    زيارات البند ({selectedTermVisits.length})
                  </span>

                  <button
                    type="button"
                    className="button secondary"
                    onClick={() => addVisit(selectedTerm.id)}
                    style={{ padding: "4px 8px", fontSize: "0.75rem" }}
                  >
                    <Plus size={12} />
                    إضافة زيارة
                  </button>
                </div>

                <div style={{ overflowY: "auto", flex: 1, padding: "10px", display: "flex", flexDirection: "column", gap: "10px" }}>
                  {selectedTermVisits.length === 0 ? (
                    <div
                      style={{
                        padding: "20px",
                        textAlign: "center",
                        color: "var(--text-tertiary)",
                        fontSize: "0.82rem",
                      }}
                    >
                      اختر بندًا لإضافة زيارات
                    </div>
                  ) : (
                    selectedTermVisits.map((visit, visitIndex) => (
                      <div
                        key={visit.id}
                        style={{
                          border: "1px solid var(--color-border)",
                          borderRadius: "8px",
                          overflow: "hidden",
                          background: "var(--bg-card)",
                        }}
                      >
                        {/* Visit Row */}
                        <div
                          className="contract-types-visit-row"
                          style={{
                            padding: "10px",
                            display: "flex",
                            alignItems: "center",
                            gap: "8px",
                            background: "var(--bg-subtle)",
                            borderBottom: "1px solid var(--color-border)",
                          }}
                        >
                          <Calendar size={14} style={{ color: "var(--color-primary)", flexShrink: 0 }} />

                          <input
                            className="input"
                            value={visit.description}
                            onChange={(event) => updateVisit(selectedTerm.id, visit.id, { description: event.target.value })}
                            placeholder={`زيارة ${visitIndex + 1}`}
                            style={{ flex: 1, fontSize: "0.82rem" }}
                          />

                          <button
                            type="button"
                            className="icon-button danger"
                            onClick={() => removeVisit(selectedTerm.id, visit.id)}
                            title="حذف الزيارة"
                          >
                            <Trash2 size={14} />
                          </button>
                        </div>

                        {/* Tasks for this visit */}
                        <div style={{ padding: "10px", display: "flex", flexDirection: "column", gap: "8px" }}>
                          <div
                            style={{
                              display: "flex",
                              justifyContent: "space-between",
                              alignItems: "center",
                            }}
                          >
                            <span
                              style={{
                                fontSize: "0.75rem",
                                fontWeight: 600,
                                color: "var(--text-tertiary)",
                                display: "flex",
                                alignItems: "center",
                                gap: "4px",
                              }}
                            >
                              <CheckSquare size={12} />
                              المهام ({(visit.tasks || []).length})
                            </span>

                            <button
                              type="button"
                              className="button secondary"
                              onClick={() => addTask(selectedTerm.id, visit.id)}
                              style={{ padding: "2px 6px", fontSize: "0.7rem" }}
                            >
                              <Plus size={11} />
                              مهمة
                            </button>
                          </div>

                          {(visit.tasks || []).length === 0 ? (
                            <div
                              style={{
                                padding: "8px",
                                fontSize: "0.75rem",
                                color: "var(--text-tertiary)",
                                fontStyle: "italic",
                              }}
                            >
                              لا توجد مهام
                            </div>
                          ) : (
                            <div style={{ display: "flex", flexDirection: "column", gap: "6px" }}>
                              {(visit.tasks || []).map((task: TaskTemplate, taskIndex: number) => (
                                <div key={task.id} className="contract-types-task-row" style={{ display: "flex", alignItems: "center", gap: "6px" }}>
                                  <span
                                    style={{
                                      width: "24px",
                                      color: "var(--text-tertiary)",
                                      fontSize: "0.7rem",
                                      flexShrink: 0,
                                    }}
                                  >
                                    •
                                  </span>

                                  <input
                                    className="input"
                                    value={task.title}
                                    onChange={(event) =>
                                      updateTask(selectedTerm.id, visit.id, task.id, event.target.value)
                                    }
                                    placeholder={`مهمة ${taskIndex + 1}`}
                                    style={{ flex: 1, fontSize: "0.8rem", padding: "6px 8px" }}
                                  />

                                  <button
                                    type="button"
                                    className="icon-button danger"
                                    onClick={() => removeTask(selectedTerm.id, visit.id, task.id)}
                                    style={{ flexShrink: 0 }}
                                  >
                                    <Trash2 size={12} />
                                  </button>
                                </div>
                              ))}
                            </div>
                          )}
                        </div>
                      </div>
                    ))
                  )}
                </div>
              </>
            ) : (
              <div
                style={{
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  flex: 1,
                  color: "var(--text-tertiary)",
                  fontSize: "0.85rem",
                }}
              >
                اختر بندًا من القائمة
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};

const sectionTitleStyle: React.CSSProperties = {
  fontSize: "0.77rem",
  color: "var(--text-secondary)",
  fontWeight: 700,
  display: "flex",
  alignItems: "center",
  gap: "4px",
};

const editorToggleButtonStyle: React.CSSProperties = {
  display: "flex",
  alignItems: "center",
  gap: "4px",
  border: "1px solid var(--color-border)",
  borderRadius: "7px",
  padding: "4px 8px",
  background: "var(--bg-subtle)",
  fontSize: "0.73rem",
  fontWeight: 600,
  color: "var(--text-secondary)",
  cursor: "pointer",
};

const SmallEmpty = ({ text }: { text: string }) => (
  <div
    style={{
      padding: "9px",
      textAlign: "center",
      borderRadius: "8px",
      border: "1px dashed var(--color-border)",
      color: "var(--text-tertiary)",
      fontSize: "0.75rem",
      background: "var(--bg-card)",
    }}
  >
    {text}
  </div>
);
