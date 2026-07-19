import React, { useEffect, useMemo, useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import {
  ArrowRight, Mail, Shield, Calendar, FileText,
  MapPin, DollarSign, Clock, Eye, Phone,
  Activity, CheckCircle2, CreditCard,
} from "lucide-react";

import { container } from "@infrastructure/di/container";
import { User } from "@domain/entities/User";
import { Contract } from "@domain/entities/Contract";
import { Visit } from "@domain/entities/Visit";
import { ContractPayment } from "@domain/entities/ContractPayment";
import { GeographicLine } from "@domain/entities/GeographicLine";
import { ContractType } from "@domain/entities/ContractType";
import { Zone } from "@domain/entities/Zone";
import { LoadingState, ErrorState } from "@presentation/components/States";
import { useTour } from "@presentation/components/tour/useTour";
import { ContractDetailsModal } from "@presentation/components/ContractDetailsModal";
import { formatDate } from "@shared/utils/date";
import { getContractStatusLabel, normalizeContractStatus } from "@shared/contractStatus";

// ─── Constants ───────────────────────────────────────────────────────────────

const ROLE_LABELS: Record<string, string> = { admin: "مدير", supervisor: "مشرف", client: "عميل" };

const CONTRACT_STATUS_CONFIG: Record<string, { label: string; variant: string }> = {
  active:     { label: "نشط",     variant: "success" },
  pending:    { label: "انتظار",  variant: "warning" },
  expired:    { label: "منتهي",   variant: "error" },
  cancelled:  { label: "ملغي",    variant: "default" },
  terminated: { label: "ملغي",    variant: "default" },
};

const VISIT_STATUS_CONFIG: Record<string, { label: string; color: string; bg: string }> = {
  planned:     { label: "مخططة",  color: "#1d4ed8", bg: "#dbeafe" },
  in_progress: { label: "جارية",  color: "#92400e", bg: "#fef3c7" },
  completed:   { label: "منجزة",  color: "#166534", bg: "#dcfce7" },
  cancelled:   { label: "ملغية",  color: "#991b1b", bg: "#fee2e2" },
};

const PAYMENT_METHOD_LABELS: Record<string, string> = {
  cash: "نقداً", transfer: "تحويل بنكي", cheque: "شيك", card: "بطاقة",
};

type Tab = "contracts" | "visits" | "payments";

// ─── Helpers ─────────────────────────────────────────────────────────────────

const buildAddress = (
  contract: Contract,
  getLine: (id?: string | null) => string,
  getZone: (id?: string | null) => string,
): string => {
  const parts: string[] = [];
  const line = getLine(contract.lineId);
  const zone = getZone(contract.zoneId);
  if (line) parts.push(`خط ${line}`);
  if (zone) parts.push(`منطقة ${zone}`);
  if (contract.blockNumber) parts.push(`ق ${contract.blockNumber}`);
  if (contract.street) parts.push(`ش ${contract.street}`);
  if (contract.avenue) parts.push(`ج ${contract.avenue}`);
  if (contract.house) parts.push(`م ${contract.house}`);
  if (contract.addressDetails) parts.push(contract.addressDetails);
  return parts.length ? parts.join(" – ") : "—";
};

// ─── Sub-components ───────────────────────────────────────────────────────────

const StatusBadge = ({ variant, label }: { variant: string; label: string }) => {
  const colors: Record<string, { bg: string; color: string }> = {
    success: { bg: "#dcfce7", color: "#166534" },
    warning: { bg: "#fef3c7", color: "#92400e" },
    error:   { bg: "#fee2e2", color: "#991b1b" },
    default: { bg: "var(--neutral-100)", color: "var(--text-secondary)" },
  };
  const s = colors[variant] ?? colors["default"]!;
  return (
    <span style={{
      background: s.bg, color: s.color,
      padding: "3px 10px", borderRadius: 12,
      fontSize: "0.75rem", fontWeight: 700,
      whiteSpace: "nowrap", display: "inline-flex", alignItems: "center",
    }}>
      {label}
    </span>
  );
};

const KpiCard = ({ icon: Icon, label, value, sub, color }: {
  icon: any; label: string; value: string; sub?: string; color: string;
}) => (
  <article className="dashboard-kpi-card">
    <div className="dashboard-kpi-head">
      <div>
        <div className="dashboard-kpi-title">{label}</div>
        <div className="dashboard-kpi-value">{value}</div>
      </div>
      <span className="kpi-icon" style={{ background: `color-mix(in srgb, ${color} 12%, transparent)`, color }}>
        <Icon size={18} />
      </span>
    </div>
    {sub && <div className="dashboard-kpi-sub">{sub}</div>}
  </article>
);

// ─── Main Page ────────────────────────────────────────────────────────────────

export const ClientDetailsPage: React.FC = () => {
  const { clientId } = useParams<{ clientId: string }>();
  const navigate = useNavigate();

  const [client, setClient]       = useState<User | null>(null);
  const [contracts, setContracts] = useState<Contract[]>([]);
  const [visits, setVisits]       = useState<Visit[]>([]);
  const [payments, setPayments]   = useState<ContractPayment[]>([]);
  const [lines, setLines]         = useState<GeographicLine[]>([]);
  const [types, setTypes]         = useState<ContractType[]>([]);
  const [zones, setZones]         = useState<Zone[]>([]);
  const [viewingContract, setViewingContract] = useState<Contract | null>(null);
  const [activeTab, setActiveTab] = useState<Tab>("contracts");
  const [loading, setLoading]     = useState(true);
  const [error, setError]         = useState<string | null>(null);

  useEffect(() => { if (clientId) loadData(); }, [clientId]);

  const loadData = async () => {
    setLoading(true);
    try {
      const [clientUsers, contractsRes, linesRes, typesRes] = await Promise.all([
        container.adminRepository.listClientUsers(),
        container.adminRepository.listContracts(),
        container.lineRepository.listLines(),
        container.adminRepository.listContractTypes(),
      ]);

      const found = clientUsers.find((u) => u.id === clientId);
      if (!found) { setError("العميل غير موجود"); return; }

      const clientContracts = contractsRes.filter((c) => c.clientId === clientId);
      setClient(found);
      setContracts(clientContracts);
      setLines(linesRes);
      setTypes(typesRes);

      const contractIds = clientContracts.map((c) => c.id);

      const [allZonesArrays, allVisits, ...paymentArrays] = await Promise.all([
        Promise.all(linesRes.map((l) => container.lineRepository.listZones(l.id))),
        container.adminRepository.listAllVisits(contractIds),
        ...contractIds.map((id) => container.adminRepository.listContractPayments(id)),
      ]);

      setZones(allZonesArrays.flat());
      setVisits(allVisits);
      setPayments(paymentArrays.flat());
    } catch {
      setError("فشل تحميل البيانات");
    } finally {
      setLoading(false);
    }
  };

  const getLineName = (id?: string | null) => lines.find((l) => l.id === id)?.name ?? "";
  const getZoneName = (id?: string | null) => zones.find((z) => z.id === id)?.name ?? "";
  const getTypeName = (id?: string | null) => types.find((t) => t.id === id)?.name ?? "غير محدد";

  const stats = useMemo(() => {
    const active   = contracts.filter((c) => normalizeContractStatus(c.status) === "active").length;
    const totalVal = contracts.reduce((s, c) => s + c.totalValue, 0);
    const completed = visits.filter((v) => v.status === "completed").length;
    const totalPaid = payments.reduce((s, p) => s + p.amount, 0);
    const remaining = totalVal - totalPaid;
    return { active, totalVal, completed, totalPaid, remaining };
  }, [contracts, visits, payments]);

  // Visits ordered like everywhere else: by contract, then by term order, then by visit date
  const sortedVisits = useMemo(() => {
    const contractOrder: Record<string, number> = {};
    contracts.forEach((c, idx) => { contractOrder[c.id] = idx; });

    const termOrderByContract: Record<string, Record<string, number>> = {};
    contracts.forEach((c) => {
      const order: Record<string, number> = {};
      (c.terms || []).forEach((term, idx) => {
        const label = (term.content || "").trim();
        if (label && order[label] === undefined) order[label] = idx;
      });
      termOrderByContract[c.id] = order;
    });

    const termRank = (v: Visit) => {
      const order = termOrderByContract[v.contractId] || {};
      const label = (v.title || "").trim();
      return label && order[label] !== undefined ? order[label] : Number.MAX_SAFE_INTEGER;
    };

    return [...visits].sort((a, b) => {
      const contractDiff = (contractOrder[a.contractId] ?? 0) - (contractOrder[b.contractId] ?? 0);
      if (contractDiff !== 0) return contractDiff;
      const termDiff = termRank(a) - termRank(b);
      if (termDiff !== 0) return termDiff;
      return a.visitDate.localeCompare(b.visitDate);
    });
  }, [visits, contracts]);

  // Payments sorted newest first
  const sortedPayments = useMemo(
    () => [...payments].sort((a, b) => b.paymentDate.localeCompare(a.paymentDate)),
    [payments],
  );

  const contractCodeMap = useMemo(() => {
    const m: Record<string, string> = {};
    contracts.forEach((c) => { m[c.id] = c.code; });
    return m;
  }, [contracts]);

  useTour(
    "admin-client-details",
    loading || error || !client
      ? []
      : [
          {
            target: '[data-tour="client-profile"]',
            title: "ملف العميل",
            content: "بيانات العميل الأساسية: الاسم، البريد الإلكتروني، رقم الهاتف، وتاريخ الانضمام.",
          },
          {
            target: ".dashboard-kpi-grid",
            title: "ملخص العميل",
            content: "عدد عقوده، القيمة الإجمالية، الزيارات المنجزة، وإجمالي المدفوع والمتبقي.",
          },
          {
            target: ".admin-tabs",
            title: "العقود، الزيارات، والمدفوعات",
            content: "تنقّل بين تفاصيل عقود العميل، سجل زياراته، وسجل مدفوعاته من هنا.",
          },
        ]
  );

  if (loading) return <LoadingState />;
  if (error || !client) return <ErrorState text={error || "العميل غير موجود"} />;

  return (
    <div className="admin-dashboard">

      {/* ── Hero ── */}
      <section className="dashboard-hero">
        <div style={{ display: "flex", alignItems: "center", gap: 16 }}>
          <button type="button" className="icon-button" onClick={() => navigate(-1)}
            style={{ background: "var(--bg-card)", border: "1px solid var(--color-border)", width: 40, height: 40, borderRadius: 12 }}>
            <ArrowRight size={20} />
          </button>
          <div className="dashboard-hero-content" style={{ padding: 0 }}>
            <div className="dashboard-hero-title">ملف العميل</div>
            <div className="dashboard-hero-subtitle">عرض كامل لبيانات العميل وعقوده وزياراته ومدفوعاته</div>
          </div>
        </div>
      </section>

      {/* ── Profile card ── */}
      <section className="dashboard-panel" data-tour="client-profile" style={{ padding: "28px 32px" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 28, flexWrap: "wrap" }}>

          {/* Avatar */}
          <ClientAvatar size={80} />

          {/* Name & role */}
          <div style={{ flex: "0 0 auto" }}>
            <div style={{ fontSize: "1.5rem", fontWeight: 800, color: "var(--text-primary)", marginBottom: 6 }}>
              {client.fullName}
            </div>
            <span style={{
              background: "var(--green-50)", color: "var(--color-primary)",
              padding: "4px 12px", borderRadius: 12, fontSize: "0.8rem", fontWeight: 700,
              display: "inline-flex", alignItems: "center", gap: 5,
            }}>
              <Shield size={12} />
              {ROLE_LABELS[client.role] ?? client.role}
            </span>
          </div>

          <div style={{ width: 1, height: 56, background: "var(--color-border)", flexShrink: 0 }} />

          {/* Contact info */}
          <div style={{ display: "flex", flexWrap: "wrap", gap: 24, flex: 1 }}>
            <ProfileField icon={Mail}     label="البريد الإلكتروني" value={client.email}        dir="ltr" />
            <ProfileField icon={Phone}    label="رقم الهاتف"         value={client.phone || "—"} dir="ltr" />
            <ProfileField icon={Calendar} label="تاريخ الانضمام"     value={formatDate(client.createdAt)} />
          </div>
        </div>
      </section>

      {/* ── KPI grid ── */}
      <section className="dashboard-kpi-grid" style={{ gridTemplateColumns: "repeat(5, 1fr)" }}>
        <KpiCard icon={FileText}     label="إجمالي العقود"   value={contracts.length.toString()}         color="var(--color-primary)"  sub="كل العقود المسجلة" />
        <KpiCard icon={CheckCircle2} label="عقود نشطة"       value={stats.active.toString()}             color="#10b981"               sub="تعاقدات سارية" />
        <KpiCard icon={DollarSign}   label="حجم التعاملات"   value={`${stats.totalVal.toLocaleString()} د.ك`} color="#6366f1"        sub="قيمة العقود الكلية" />
        <KpiCard icon={Activity}     label="زيارات منجزة"    value={stats.completed.toString()}          color="#f59e0b"               sub={`من ${visits.length} إجمالاً`} />
        <KpiCard icon={CreditCard}   label="إجمالي المدفوع"  value={`${stats.totalPaid.toLocaleString()} د.ك`} color="#0ea5e9"       sub={stats.remaining > 0 ? `متبقي ${stats.remaining.toLocaleString()} د.ك` : "مسدد بالكامل"} />
      </section>

      {/* ── Tabs panel ── */}
      <section className="dashboard-panel" style={{ padding: 0, overflow: "hidden" }}>

        {/* Tab bar */}
        <div style={{ padding: "20px 28px", borderBottom: "1px solid var(--color-border)", display: "flex", alignItems: "center", gap: 12, background: "var(--bg-subtle)" }}>
          <div className="admin-tabs">
            <TabButton tab="contracts" active={activeTab} label="العقود"    icon={FileText}     count={contracts.length} onClick={setActiveTab} />
            <TabButton tab="visits"    active={activeTab} label="الزيارات"  icon={Clock}        count={visits.length}    onClick={setActiveTab} />
            <TabButton tab="payments"  active={activeTab} label="المدفوعات" icon={CreditCard}   count={payments.length}  onClick={setActiveTab} />
          </div>
        </div>

        {/* ── Tab: Contracts ── */}
        {activeTab === "contracts" && (
          <div className="dashboard-table-wrap">
            <table className="dashboard-table">
              <thead>
                <tr>
                  <th>رقم العقد</th>
                  <th>النوع</th>
                  <th>العنوان الكامل</th>
                  <th>المدة</th>
                  <th>القيمة</th>
                  <th>الحالة</th>
                  <th style={{ textAlign: "center" }}>تفاصيل</th>
                </tr>
              </thead>
              <tbody>
                {contracts.length === 0 ? (
                  <tr><td colSpan={7}><EmptyState icon={FileText} text="لا توجد عقود مسجلة" /></td></tr>
                ) : contracts.map((c) => {
                  const norm = normalizeContractStatus(c.status);
                  const sc   = CONTRACT_STATUS_CONFIG[norm] ?? { label: getContractStatusLabel(c.status), variant: "default" };
                  const addr = buildAddress(c, getLineName, getZoneName);
                  return (
                    <tr key={c.id}>
                      <td>
                        <span style={{ fontFamily: "monospace", fontWeight: 700, fontSize: "0.95rem" }}>{c.code}</span>
                      </td>
                      <td>
                        <span style={{ background: "var(--neutral-100)", padding: "3px 10px", borderRadius: 8, fontSize: "0.85rem", fontWeight: 600 }}>
                          {getTypeName(c.contractTypeId)}
                        </span>
                      </td>
                      <td style={{ maxWidth: 280 }}>
                        <div style={{ display: "flex", alignItems: "flex-start", gap: 6 }}>
                          <MapPin size={14} style={{ color: "var(--text-tertiary)", marginTop: 2, flexShrink: 0 }} />
                          <span style={{ fontSize: "0.85rem", color: "var(--text-secondary)", lineHeight: 1.5 }}>{addr}</span>
                        </div>
                      </td>
                      <td>
                        <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
                          <span style={{ fontWeight: 600, fontSize: "0.9rem" }}>{formatDate(c.startDate)}</span>
                          <span style={{ color: "var(--text-tertiary)", fontSize: "0.8rem" }}>حتى {formatDate(c.endDate)}</span>
                        </div>
                      </td>
                      <td>
                        <span style={{ fontWeight: 800, color: "var(--color-primary)", fontSize: "1rem" }}>
                          {c.totalValue.toLocaleString()} <span style={{ fontSize: "0.78rem", fontWeight: 600 }}>د.ك</span>
                        </span>
                      </td>
                      <td><StatusBadge variant={sc.variant} label={sc.label} /></td>
                      <td style={{ textAlign: "center" }}>
                        <button
                          type="button"
                          className="icon-button"
                          onClick={() => setViewingContract(c)}
                          title="عرض تفاصيل العقد"
                          style={{ border: "1px solid var(--color-border)", borderRadius: 10, padding: 7 }}
                        >
                          <Eye size={16} />
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}

        {/* ── Tab: Visits ── */}
        {activeTab === "visits" && (
          <>
            {/* Visit status summary */}
            <div style={{ display: "flex", gap: 16, padding: "20px 28px", flexWrap: "wrap", borderBottom: "1px solid var(--color-border)" }}>
              {Object.entries(VISIT_STATUS_CONFIG).map(([key, cfg]) => {
                const count = visits.filter((v) => v.status === key).length;
                return (
                  <div key={key} style={{ display: "flex", alignItems: "center", gap: 8, background: cfg.bg, borderRadius: 10, padding: "8px 16px" }}>
                    <span style={{ width: 8, height: 8, borderRadius: "50%", background: cfg.color, flexShrink: 0 }} />
                    <span style={{ fontSize: "0.85rem", fontWeight: 700, color: cfg.color }}>{cfg.label}</span>
                    <span style={{ fontSize: "0.85rem", fontWeight: 800, color: cfg.color }}>{count}</span>
                  </div>
                );
              })}
            </div>

            <div className="dashboard-table-wrap">
              <table className="dashboard-table">
                <thead>
                  <tr>
                    <th>العقد</th>
                    <th>تاريخ الزيارة</th>
                    <th>العنوان / الملاحظات</th>
                    <th>الحالة</th>
                    <th>الإنجاز</th>
                  </tr>
                </thead>
                <tbody>
                  {sortedVisits.length === 0 ? (
                    <tr><td colSpan={5}><EmptyState icon={Clock} text="لا توجد زيارات مسجلة" /></td></tr>
                  ) : sortedVisits.map((v) => {
                    const scv = VISIT_STATUS_CONFIG[v.status] ?? VISIT_STATUS_CONFIG["planned"]!;
                    const contract = contracts.find((c) => c.id === v.contractId);
                    return (
                      <tr key={v.id}>
                        <td>
                          <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
                            <span style={{ fontFamily: "monospace", fontWeight: 700, fontSize: "0.9rem" }}>
                              {contractCodeMap[v.contractId] ?? "—"}
                            </span>
                            {contract && (
                              <span style={{ fontSize: "0.78rem", color: "var(--text-tertiary)" }}>
                                {getLineName(contract.lineId) || getZoneName(contract.zoneId) || ""}
                              </span>
                            )}
                          </div>
                        </td>
                        <td>
                          <span style={{ fontWeight: 600, fontSize: "0.9rem" }}>{formatDate(v.visitDate)}</span>
                        </td>
                        <td style={{ maxWidth: 260 }}>
                          <span style={{ fontSize: "0.85rem", color: "var(--text-secondary)" }}>
                            {v.title || v.notes || "—"}
                          </span>
                        </td>
                        <td>
                          <span style={{
                            background: scv.bg, color: scv.color,
                            padding: "3px 10px", borderRadius: 12,
                            fontSize: "0.75rem", fontWeight: 700,
                          }}>
                            {scv.label}
                          </span>
                        </td>
                        <td>
                          <span style={{ fontSize: "0.82rem", color: "var(--text-tertiary)" }}>
                            {v.completedAt ? formatDate(v.completedAt) : "—"}
                          </span>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </>
        )}

        {/* ── Tab: Payments ── */}
        {activeTab === "payments" && (
          <>
            {/* Payment summary */}
            <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 20, padding: "20px 28px", borderBottom: "1px solid var(--color-border)" }}>
              <SummaryItem
                label="إجمالي قيمة العقود"
                value={`${contracts.reduce((s, c) => s + c.totalValue, 0).toLocaleString()} د.ك`}
                color="var(--color-primary)"
              />
              <SummaryItem
                label="إجمالي المدفوع"
                value={`${stats.totalPaid.toLocaleString()} د.ك`}
                color="#10b981"
              />
              <SummaryItem
                label="المتبقي"
                value={`${stats.remaining.toLocaleString()} د.ك`}
                color={stats.remaining > 0 ? "#ef4444" : "#10b981"}
              />
            </div>

            <div className="dashboard-table-wrap">
              <table className="dashboard-table">
                <thead>
                  <tr>
                    <th>العقد</th>
                    <th>تاريخ الدفع</th>
                    <th>المبلغ</th>
                    <th>طريقة الدفع</th>
                    <th>ملاحظات</th>
                  </tr>
                </thead>
                <tbody>
                  {sortedPayments.length === 0 ? (
                    <tr><td colSpan={5}><EmptyState icon={CreditCard} text="لا توجد مدفوعات مسجلة" /></td></tr>
                  ) : sortedPayments.map((p) => (
                    <tr key={p.id}>
                      <td>
                        <span style={{ fontFamily: "monospace", fontWeight: 700, fontSize: "0.9rem" }}>
                          {contractCodeMap[p.contractId] ?? "—"}
                        </span>
                      </td>
                      <td>
                        <span style={{ fontWeight: 600, fontSize: "0.9rem" }}>{formatDate(p.paymentDate)}</span>
                      </td>
                      <td>
                        <span style={{ fontWeight: 800, color: "#10b981", fontSize: "1rem" }}>
                          {p.amount.toLocaleString()} <span style={{ fontSize: "0.78rem", fontWeight: 600 }}>د.ك</span>
                        </span>
                      </td>
                      <td>
                        <span style={{ background: "var(--neutral-100)", padding: "3px 10px", borderRadius: 8, fontSize: "0.82rem", fontWeight: 600 }}>
                          {PAYMENT_METHOD_LABELS[p.paymentMethod] ?? p.paymentMethod}
                        </span>
                      </td>
                      <td>
                        <span style={{ fontSize: "0.85rem", color: "var(--text-secondary)" }}>
                          {p.notes || "—"}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </>
        )}
      </section>

      {/* ── Contract details modal ── */}
      {viewingContract && (
        <ContractDetailsModal
          contract={viewingContract}
          client={client}
          typeName={getTypeName(viewingContract.contractTypeId)}
          lineName={getLineName(viewingContract.lineId)}
          zoneName={zones.find((z) => z.id === viewingContract.zoneId)?.name}
          onClose={() => setViewingContract(null)}
          onStatusChange={async (newStatus: string) => {
            try {
              await container.adminRepository.updateContractStatus(viewingContract.id, newStatus);
              setViewingContract((prev) => prev ? { ...prev, status: newStatus as any } : null);
              setContracts((prev) => prev.map((c) => c.id === viewingContract.id ? { ...c, status: newStatus as any } : c));
            } catch {
              console.error("Failed to change status");
            }
          }}
        />
      )}
    </div>
  );
};

// ─── Small helper components ──────────────────────────────────────────────────

const ProfileField = ({ icon: Icon, label, value, dir }: {
  icon: any; label: string; value: string; dir?: string;
}) => (
  <div style={{ display: "flex", alignItems: "center", gap: 12, minWidth: 160 }}>
    <div style={{
      width: 38, height: 38, borderRadius: 10, flexShrink: 0,
      background: "var(--bg-subtle)", border: "1px solid var(--color-border)",
      display: "flex", alignItems: "center", justifyContent: "center", color: "var(--color-primary)",
    }}>
      <Icon size={17} />
    </div>
    <div>
      <div style={{ fontSize: "0.75rem", color: "var(--text-tertiary)", fontWeight: 600, marginBottom: 2 }}>{label}</div>
      <div style={{ fontSize: "0.95rem", color: "var(--text-primary)", fontWeight: 700 }} dir={dir}>{value}</div>
    </div>
  </div>
);

const TabButton = ({ tab, active, label, icon: Icon, count, onClick }: {
  tab: Tab; active: Tab; label: string; icon: any; count: number; onClick: (t: Tab) => void;
}) => (
  <button type="button" className={`admin-tab-button ${active === tab ? "is-active" : ""}`} onClick={() => onClick(tab)}>
    <Icon size={15} />
    {label}
    <span className="admin-tab-count">{count}</span>
  </button>
);

const SummaryItem = ({ label, value, color }: { label: string; value: string; color: string }) => (
  <div style={{
    background: "var(--bg-subtle)", borderRadius: 14, padding: "16px 20px",
    border: "1px solid var(--color-border)", display: "flex", flexDirection: "column", gap: 6,
  }}>
    <div style={{ fontSize: "0.82rem", color: "var(--text-tertiary)", fontWeight: 600 }}>{label}</div>
    <div style={{ fontSize: "1.4rem", fontWeight: 800, color, letterSpacing: "-0.5px" }}>{value}</div>
  </div>
);

const ClientAvatar = ({ size = 80 }: { size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 80 80" fill="none" xmlns="http://www.w3.org/2000/svg" style={{ flexShrink: 0, display: "block" }}>
    <circle cx="40" cy="40" r="40" fill="#ABC695" />
    <circle cx="40" cy="30" r="14" fill="white" />
    <ellipse cx="40" cy="70" rx="24" ry="16" fill="white" />
  </svg>
);

const EmptyState = ({ icon: Icon, text }: { icon: any; text: string }) => (
  <div style={{ padding: "60px 0", textAlign: "center", color: "var(--text-tertiary)", display: "flex", flexDirection: "column", alignItems: "center", gap: 12 }}>
    <div style={{ width: 64, height: 64, borderRadius: "50%", background: "var(--bg-subtle)", display: "flex", alignItems: "center", justifyContent: "center" }}>
      <Icon size={28} style={{ opacity: 0.4 }} />
    </div>
    <span style={{ fontSize: "1rem", fontWeight: 600 }}>{text}</span>
  </div>
);
