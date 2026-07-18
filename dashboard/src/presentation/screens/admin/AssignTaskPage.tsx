import React, { useEffect, useState } from "react";
import { container } from "@infrastructure/di/container";
import { useToast } from "@presentation/components/ToastProvider";
import { CustomSelect } from "@presentation/components/CustomSelect";
import { User } from "@domain/entities/User";
import { GeographicLine } from "@domain/entities/GeographicLine";
import { Zone } from "@domain/entities/Zone";
import { PaymentMethod } from "@domain/entities/ContractPayment";
import { ChevronRight, X } from "lucide-react";

const PAYMENT_METHOD_OPTIONS: { id: PaymentMethod; label: string }[] = [
  { id: "cash", label: "نقدي" },
  { id: "transfer", label: "رابط" },
  { id: "cheque", label: "شيك" },
  { id: "card", label: "ومض" },
];

interface CreateStandaloneTaskModalProps {
  onClose: () => void;
  onSuccess: () => void;
  initialContractId?: string | null;
  initialLineId?: string | null;
  initialZoneId?: string | null;
}

export const CreateStandaloneTaskModal: React.FC<CreateStandaloneTaskModalProps> = ({
  onClose,
  onSuccess,
  initialContractId = null,
  initialLineId = null,
  initialZoneId = null,
}) => {
  const { notify } = useToast();

  const [clients, setClients] = useState<User[]>([]);
  const [supervisors, setSupervisors] = useState<User[]>([]);
  const [contracts, setContracts] = useState<any[]>([]);
  const [lines, setLines] = useState<GeographicLine[]>([]);
  const [zones, setZones] = useState<Zone[]>([]);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [step, setStep] = useState<1 | 2>(1);
  const [supervisorTouched, setSupervisorTouched] = useState(false);

  const [clientType, setClientType] = useState<"existing" | "new">("existing");
  const [selectedClientId, setSelectedClientId] = useState("");
  const [newClientName, setNewClientName] = useState("");
  const [newClientPhone, setNewClientPhone] = useState("");
  const [selectedContractId, setSelectedContractId] = useState(initialContractId ?? "");
  const [selectedLineId, setSelectedLineId] = useState(initialLineId ?? "");
  const [selectedZoneId, setSelectedZoneId] = useState(initialZoneId ?? "");
  const [address, setAddress] = useState("");
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [taskDate, setTaskDate] = useState("");
  const [cost, setCost] = useState("");
  const [paymentStatus, setPaymentStatus] = useState<"unpaid" | "paid">("unpaid");
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethod | "">("");
  const [supervisorId, setSupervisorId] = useState("");
  const [status, setStatus] = useState("pending");
  const [notes, setNotes] = useState("");

  const normalizeAddressValue = (value?: string | null) => {
    const trimmed = value?.trim();
    return trimmed ? trimmed : null;
  };

  const stripAddressPrefix = (value: string, prefixes: string[]) => {
    const escaped = prefixes.map((prefix) => prefix.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join("|");
    const cleaned = value.replace(new RegExp(`^(?:${escaped})\\s*[:\\-]?\\s*`, "i"), "").trim();
    return cleaned || value;
  };

  const formatContractAddress = (contract: any) => {
    const parts = [
      { shortLabel: "ق", value: normalizeAddressValue(contract.blockNumber) ? stripAddressPrefix(contract.blockNumber, ["ق", "قطعة", "block"]) : null },
      { shortLabel: "ش", value: normalizeAddressValue(contract.street) ? stripAddressPrefix(contract.street, ["ش", "شارع", "street", "st"]) : null },
      { shortLabel: "ج", value: normalizeAddressValue(contract.avenue) ? stripAddressPrefix(contract.avenue, ["ج", "جادة", "avenue", "ave"]) : null },
      { shortLabel: "م", value: normalizeAddressValue(contract.house) ? stripAddressPrefix(contract.house, ["م", "منزل", "بيت", "house", "home"]) : null },
    ]
      .filter((part) => part.value)
      .map((part) => `${part.shortLabel} ${part.value}`)
      .join(" - ");

    return parts || normalizeAddressValue(contract.addressDetails) || "";
  };

  useEffect(() => {
    let mounted = true;

    const load = async () => {
      try {
        setLoading(true);
        const [loadedClients, loadedSupervisors, loadedContracts, loadedLines] = await Promise.all([
          container.adminRepository.listClientUsers(),
          container.adminRepository.listSupervisors(),
          container.adminRepository.listContracts(),
          container.lineRepository.listLines().catch(() => [] as GeographicLine[]),
        ]);

        if (!mounted) return;

        setClients(loadedClients);
        setSupervisors(loadedSupervisors);
        setContracts(loadedContracts);
        setLines(loadedLines);

        if (initialContractId) {
          const contract = loadedContracts.find((item: any) => item.id === initialContractId);
          if (contract) {
            setSelectedContractId(initialContractId);
            if (contract.clientId) {
              setClientType("existing");
              setSelectedClientId(contract.clientId);
            }

            const compactAddress = formatContractAddress(contract);
            if (compactAddress) setAddress(compactAddress);

            if (contract.lineId) {
              setSelectedLineId(contract.lineId);
              try {
                const loadedZones = await container.lineRepository.listZones(contract.lineId);
                setZones(loadedZones);
                if (contract.zoneId) setSelectedZoneId(contract.zoneId);
              } catch (error) {
                console.error("Failed to load zones for contract line:", error);
              }
            }
          }
        }
      } catch (error) {
        console.error(error);
        if (mounted) notify("تعذر تحميل البيانات");
      } finally {
        if (mounted) setLoading(false);
      }
    };

    load();

    return () => {
      mounted = false;
    };
  }, []);

  useEffect(() => {
    if (!selectedLineId) return;
    if (supervisorTouched) return;
    const assignedSupervisor = supervisors.find((item) => item.assignedLineId === selectedLineId);
    if (assignedSupervisor) setSupervisorId(assignedSupervisor.id);
  }, [selectedLineId, supervisors, supervisorTouched]);

  useEffect(() => {
    let mounted = true;

    const loadZones = async () => {
      if (!selectedLineId) {
        setZones([]);
        return;
      }

      try {
        const loadedZones = await container.lineRepository.listZones(selectedLineId);
        if (!mounted) return;
        setZones(loadedZones);
      } catch (error) {
        console.error("Failed to load zones for selected line:", error);
        if (mounted) setZones([]);
      }
    };

    loadZones();

    return () => {
      mounted = false;
    };
  }, [selectedLineId]);

  useEffect(() => {
    if (!selectedContractId) return;
    const contract = contracts.find((item) => item.id === selectedContractId);
    if (!contract) return;
    const compactAddress = formatContractAddress(contract);
    if (compactAddress) setAddress(compactAddress);

    if (contract.clientId) {
      setClientType("existing");
      setSelectedClientId(contract.clientId);
    }

    if (contract.lineId) setSelectedLineId(contract.lineId);
    if (contract.zoneId) setSelectedZoneId(contract.zoneId);
  }, [selectedContractId, contracts]);

  const handleStep1Validation = () => {
    if (!title.trim()) {
      notify("من فضلك أدخل اسم المهمة");
      return;
    }
    setStep(2);
  };

  const handleSubmit = async (event?: React.FormEvent) => {
    event?.preventDefault();

    if (!title.trim()) {
      notify("من فضلك أدخل اسم المهمة");
      setStep(1);
      return;
    }

    if (paymentStatus === "paid" && !paymentMethod) {
      notify("من فضلك اختر طريقة الدفع");
      setStep(1);
      return;
    }

    setSubmitting(true);
    try {
      const payload: any = {
        title: title.trim(),
        description: description.trim() || null,
        address: address.trim() || null,
        taskDate: taskDate || null,
        notes: notes.trim() || null,
        supervisorId: supervisorId || null,
        status: status || "pending",
        contractId: selectedContractId || null,
        lineId: selectedLineId || null,
        zoneId: selectedZoneId || null,
        cost: cost ? Number.parseFloat(cost) : null,
        paymentStatus,
        paymentMethod: paymentStatus === "paid" ? paymentMethod : null,
      };

      if (initialContractId) {
        const contract = contracts.find((item) => item.id === initialContractId);
        if (contract) {
          payload.contractId = initialContractId;
          payload.clientId = contract.clientId || null;
          const client = clients.find((item) => item.id === contract.clientId);
          payload.clientName = client?.fullName || contract.contractUserName || null;
          payload.clientPhone = client?.phone || contract.contractUserPhone || null;
          if (contract.lineId && !payload.lineId) payload.lineId = contract.lineId;
          if (contract.zoneId && !payload.zoneId) payload.zoneId = contract.zoneId;
        }
      } else if (clientType === "existing") {
        const selectedClient = clients.find((item) => item.id === selectedClientId);
        payload.clientId = selectedClientId || null;
        payload.clientName = selectedClient?.fullName || null;
        payload.clientPhone = selectedClient?.phone || null;
      } else {
        payload.clientName = newClientName.trim() || null;
        payload.clientPhone = newClientPhone.trim() || null;
      }

      await container.adminRepository.createStandaloneTask(payload);

      notify("تم إنشاء المهمة بنجاح وإسنادها للمشرف");
      onSuccess();
    } catch (error: any) {
      console.error(error);
      notify(error?.message || "فشل إنشاء المهمة");
    } finally {
      setSubmitting(false);
    }
  };

  if (loading) return null;

  return (
    <div
      className="create-task-modal-overlay"
      style={{
        position: "fixed",
        inset: 0,
        height: "100dvh",
        background: "rgba(17, 24, 39, 0.56)",
        backdropFilter: "blur(4px)",
        display: "grid",
        justifyItems: "center",
        alignItems: "start",
        overflowY: "auto",
        zIndex: 120,
        padding: "12px",
        boxSizing: "border-box",
      }}
    >
      <div
        className="card create-task-modal-card"
        style={{
          width: "100%",
          maxWidth: "640px",
          margin: 0,
          padding: "16px",
          display: "flex",
          flexDirection: "column",
          gap: "14px",
          boxSizing: "border-box",
        }}
      >
        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            borderBottom: "1px solid var(--color-border)",
            paddingBottom: "12px",
            marginBottom: "4px",
          }}
        >
          <div>
            <h3 style={{ margin: 0, fontSize: "1.25rem", fontWeight: 700, color: "var(--text-primary)" }}>إنشاء مهمة جديدة</h3>
            <p style={{ margin: "4px 0 0", fontSize: "0.85rem", color: "var(--text-secondary)" }}>
              {step === 1 ? "المرحلة الأولى: بيانات العميل والمهمة" : "المرحلة الثانية: التفاصيل والمشرف"}
            </p>
          </div>
          <button
            onClick={onClose}
            className="icon-button"
            style={{ width: 32, height: 32, background: "var(--bg-subtle)", border: "1px solid var(--color-border)" }}
          >
            <X size={18} />
          </button>
        </div>

        <div style={{ display: "flex", gap: 8, marginBottom: 10 }}>
          {[1, 2].map((item) => (
            <div
              key={item}
              style={{
                flex: 1,
                height: 8,
                borderRadius: 4,
                background: step >= item ? "var(--color-primary)" : "var(--color-border)",
                transition: "background 0.3s",
              }}
            />
          ))}
        </div>

        <form
          onSubmit={
            step === 1
              ? (event) => {
                  event.preventDefault();
                  handleStep1Validation();
                }
              : handleSubmit
          }
          style={{ display: "flex", flexDirection: "column", gap: 12 }}
        >
          {step === 1 ? (
            <>
              {!initialContractId && (
                <div style={{ borderBottom: "1px solid var(--color-border)", paddingBottom: 16 }}>
                  <strong style={{ display: "block", marginBottom: 12, fontSize: "0.95rem", color: "var(--text-primary)" }}>العميل</strong>

                  <div style={{ display: "flex", gap: 16, marginBottom: 12 }}>
                    <label style={{ display: "flex", alignItems: "center", gap: 8, cursor: "pointer", fontSize: "0.9rem" }}>
                      <input
                        type="radio"
                        name="clientType"
                        value="existing"
                        checked={clientType === "existing"}
                        onChange={() => setClientType("existing")}
                      />
                      <span>اختر من العملاء المسجلين</span>
                    </label>
                    <label style={{ display: "flex", alignItems: "center", gap: 8, cursor: "pointer", fontSize: "0.9rem" }}>
                      <input
                        type="radio"
                        name="clientType"
                        value="new"
                        checked={clientType === "new"}
                        onChange={() => setClientType("new")}
                      />
                      <span>عميل جديد</span>
                    </label>
                  </div>

                  {clientType === "existing" ? (
                    <CustomSelect
                      value={selectedClientId}
                      onChange={(value) => setSelectedClientId(value as string)}
                      options={[
                        { id: "", label: "-- اختر عميل --" },
                        ...clients.map((client) => ({ id: client.id, label: `${client.fullName} (${client.phone || "بدون هاتف"})` })),
                      ]}
                      placeholder="اختر عميل"
                      width="100%"
                      searchable
                    />
                  ) : (
                    <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
                      <input className="input" placeholder="اسم العميل" value={newClientName} onChange={(event) => setNewClientName(event.target.value)} />
                      <input className="input" placeholder="هاتف العميل" value={newClientPhone} onChange={(event) => setNewClientPhone(event.target.value)} />
                    </div>
                  )}

                  <div style={{ marginTop: 12 }}>
                    <strong style={{ display: "block", marginBottom: 8, fontSize: "0.9rem", color: "var(--text-primary)" }}>ربط بعقد (اختياري)</strong>
                    <CustomSelect
                      value={selectedContractId}
                      onChange={(value) => setSelectedContractId(value as string)}
                      options={[
                        { id: "", label: "-- لا يوجد عقد --" },
                        ...(clientType === "existing" && selectedClientId
                          ? contracts
                              .filter((contract) => contract.clientId === selectedClientId)
                              .map((contract) => ({
                                id: contract.id,
                                label: `${contract.code || contract.id} (${clients.find(c => c.id === contract.clientId)?.fullName || contract.contractUserName || "—"})`,
                              }))
                          : contracts.map((contract) => ({
                              id: contract.id,
                              label: `${contract.code || contract.id} (${clients.find(c => c.id === contract.clientId)?.fullName || contract.contractUserName || "—"})`,
                            }))),
                      ]}
                      placeholder="اختر عقد"
                      width="100%"
                      searchable
                    />
                  </div>
                </div>
              )}

              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}>
                <label style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                  <strong style={{ fontSize: "0.9rem", color: "var(--text-primary)" }}>الخط (Line)</strong>
                  <CustomSelect
                    value={selectedLineId}
                    onChange={(value) => setSelectedLineId(value as string)}
                    options={[{ id: "", label: "-- اختر خط --" }, ...lines.map((line) => ({ id: line.id, label: line.name }))]}
                    placeholder="اختر خط"
                    width="100%"
                    searchable
                  />
                </label>

                <label style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                  <strong style={{ fontSize: "0.9rem", color: "var(--text-primary)" }}>المنطقة (Zone)</strong>
                  <CustomSelect
                    value={selectedZoneId}
                    onChange={(value) => setSelectedZoneId(value as string)}
                    options={[{ id: "", label: "-- اختر منطقة --" }, ...zones.map((zone) => ({ id: zone.id, label: zone.name }))]}
                    placeholder="اختر منطقة"
                    width="100%"
                    searchable
                  />
                </label>
              </div>

              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16, marginTop: 8 }}>
                <label style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                  <strong style={{ fontSize: "0.9rem", color: "var(--text-primary)" }}>العنوان</strong>
                  <input className="input" value={address} onChange={(event) => setAddress(event.target.value)} placeholder="مثال: شارع 10، حي ..." />
                </label>

                <label style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                  <strong style={{ fontSize: "0.9rem", color: "var(--text-primary)" }}>التكلفة (اختياري)</strong>
                  <input className="input" type="number" step="0.01" value={cost} onChange={(event) => setCost(event.target.value)} placeholder="مثال: 12.50" />
                </label>
              </div>

              <div style={{ display: "grid", gridTemplateColumns: paymentStatus === "unpaid" ? "1fr" : "1fr 1fr", gap: 16, marginTop: 8 }}>
                <label style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                  <strong style={{ fontSize: "0.9rem", color: "var(--text-primary)" }}>حالة الدفع</strong>
                  <CustomSelect
                    value={paymentStatus}
                    onChange={(value) => setPaymentStatus(value as "unpaid" | "paid")}
                    options={[
                      { id: "unpaid", label: "غير مدفوع" },
                      { id: "paid", label: "مدفوع" },
                    ]}
                    placeholder="اختر حالة الدفع"
                    width="100%"
                  />
                </label>

                {paymentStatus === "paid" && (
                  <label style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                    <strong style={{ fontSize: "0.9rem", color: "var(--text-primary)" }}>طريقة الدفع</strong>
                    <CustomSelect
                      value={paymentMethod}
                      onChange={(value) => setPaymentMethod(value as PaymentMethod)}
                      options={PAYMENT_METHOD_OPTIONS}
                      placeholder="اختر طريقة الدفع"
                      width="100%"
                    />
                  </label>
                )}
              </div>

              <label style={{ display: "flex", flexDirection: "column", gap: 8, marginTop: 8 }}>
                <strong style={{ fontSize: "0.9rem", color: "var(--text-primary)" }}>اسم المهمة</strong>
                <input className="input" value={title} onChange={(event) => setTitle(event.target.value)} placeholder="مثال: صيانة، فحص، تنظيف..." />
              </label>
            </>
          ) : (
            <>
              <div style={{ display: "grid", gridTemplateColumns: "1fr", gap: 16 }}>
                <label style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                  <strong style={{ fontSize: "0.9rem", color: "var(--text-primary)" }}>تاريخ ووقت المهمة</strong>
                  <input className="input" type="datetime-local" value={taskDate} onChange={(event) => setTaskDate(event.target.value)} />
                </label>
              </div>

              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}>
                <label style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                  <strong style={{ fontSize: "0.9rem", color: "var(--text-primary)" }}>المشرف المسؤول</strong>
                  <CustomSelect
                    value={supervisorId}
                    onChange={(value) => {
                      setSupervisorId(value as string);
                      setSupervisorTouched(true);
                    }}
                    options={[{ id: "", label: "-- اختر مشرف --" }, ...supervisors.map((supervisor) => ({ id: supervisor.id, label: supervisor.fullName }))]}
                    placeholder="اختر مشرف"
                    width="100%"
                  />
                </label>

                <label style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                  <strong style={{ fontSize: "0.9rem", color: "var(--text-primary)" }}>حالة المهمة</strong>
                  <CustomSelect
                    value={status}
                    onChange={(value) => setStatus(value as string)}
                    options={[
                      { id: "pending", label: "قيد الانتظار" },
                      { id: "in_progress", label: "جاري التنفيذ" },
                      { id: "completed", label: "مكتملة" },
                      { id: "cancelled", label: "ملغاة" },
                    ]}
                    placeholder="اختر الحالة"
                    width="100%"
                  />
                </label>
              </div>

              <label style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                <strong style={{ fontSize: "0.9rem", color: "var(--text-primary)" }}>وصف المهمة</strong>
                <textarea
                  className="input"
                  rows={3}
                  value={description}
                  onChange={(event) => setDescription(event.target.value)}
                  placeholder="اشرح المهمة بالتفصيل..."
                  style={{ resize: "none" }}
                />
              </label>

              <label style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                <strong style={{ fontSize: "0.9rem", color: "var(--text-primary)" }}>ملاحظات إضافية</strong>
                <textarea
                  className="input"
                  rows={2}
                  value={notes}
                  onChange={(event) => setNotes(event.target.value)}
                  placeholder="ملاحظات أو معلومات إضافية..."
                  style={{ resize: "none" }}
                />
              </label>
            </>
          )}

          <div
            style={{
              display: "flex",
              gap: 12,
              marginTop: 8,
              paddingTop: 16,
              borderTop: "1px solid var(--color-border)",
            }}
          >
            {step === 2 && (
              <button className="button secondary" type="button" onClick={() => setStep(1)}>
                الرجوع
              </button>
            )}
            <button className="button primary" type="submit" disabled={submitting || title.trim() === ""}>
              {step === 1 ? (
                <>
                  التالي <ChevronRight size={16} style={{ marginLeft: 4 }} />
                </>
              ) : submitting ? (
                "جاري الحفظ..."
              ) : (
                "حفظ المهمة"
              )}
            </button>
            <button className="button secondary" type="button" onClick={onClose}>
              إلغاء
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
