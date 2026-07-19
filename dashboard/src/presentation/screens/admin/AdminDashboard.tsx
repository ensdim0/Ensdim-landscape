import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  AlertCircle,
  ArrowLeft,
  Clock,
  FileText,
  HardHat,
  MapPin,
  Phone,
  RefreshCw,
  Truck,
  UserCircle,
  Users,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { container } from "@infrastructure/di/container";
import { User } from "@domain/entities/User";
import { Contract } from "@domain/entities/Contract";
import { Worker } from "@domain/entities/Worker";
import { Vehicle } from "@domain/entities/Vehicle";
import { CompanyPhone } from "@domain/entities/CompanyPhone";
import { GeographicLine } from "@domain/entities/GeographicLine";
import { Zone } from "@domain/entities/Zone";
import { ContractType } from "@domain/entities/ContractType";
import { LoadingState, ErrorState } from "@presentation/components/States";
import { useAuth } from "@presentation/state/useAuth";
import { useTour } from "@presentation/components/tour/useTour";
import { formatDate } from "@shared/utils/date";
import { getContractStatusLabel, normalizeContractStatus } from "@shared/contractStatus";
import { supabase } from "@infrastructure/supabase/client";

interface DashboardStats {
  users: User[];
  clientUsers: User[];
  contracts: Contract[];
  contractTypes: ContractType[];
  workers: Worker[];
  vehicles: Vehicle[];
  phones: CompanyPhone[];
  lines: GeographicLine[];
  zones: Zone[];
}

type KpiTone = "primary" | "accent" | "success" | "info";

type KpiCard = {
  title: string;
  value: number;
  sub: string;
  tone: KpiTone;
  icon: LucideIcon;
  link: string;
};

export const AdminDashboard = () => {
  const { user } = useAuth();
  const navigate = useNavigate();

  const [stats, setStats] = useState<DashboardStats>({
    users: [],
    clientUsers: [],
    contracts: [],
    contractTypes: [],
    workers: [],
    vehicles: [],
    phones: [],
    lines: [],
    zones: [],
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [pendingStatusRequestsCount, setPendingStatusRequestsCount] = useState(0);

  const fetchData = async () => {
    try {
      setLoading(true);
      setError(null);

      const [users, contracts, clientUsers, workers, vehicles, phones, lines, contractTypes] = await Promise.all([
        container.adminRepository.listUsers(),
        container.adminRepository.listContracts(),
        container.adminRepository.listClientUsers(),
        container.workerRepository.listWorkers(),
        container.fleetRepository.listVehicles(),
        container.phoneRepository.listPhones(),
        container.lineRepository.listLines(),
        container.adminRepository.listContractTypes(),
      ]);

      const zones = (
        await Promise.all(lines.map((line) => container.lineRepository.listZones(line.id)))
      ).flat();

      const { count: statusRequestsCount } = await supabase
        .from("contract_status_requests")
        .select("id", { count: "exact", head: true })
        .eq("status", "pending");

      setPendingStatusRequestsCount(statusRequestsCount ?? 0);

      setStats({
        users,
        contracts,
        clientUsers,
        contractTypes,
        workers,
        vehicles,
        phones,
        lines,
        zones,
      });
    } catch (err) {
      console.error(err);
      setError("تعذر تحميل بيانات النظام");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  const activeContracts = stats.contracts.filter((contract) => contract.status === "active");
  const pendingContracts = stats.contracts.filter((contract) => contract.status === "pending");
  const expiredContracts = stats.contracts.filter((contract) => {
    const status = normalizeContractStatus(contract.status);
    return status === "expired" || status === "cancelled";
  });
  const activeSupervisors = stats.users.filter((item) => item.role === "supervisor");

  const totalContractValue = stats.contracts.reduce((sum, contract) => sum + (contract.totalValue || 0), 0);

  const expiringSoon = useMemo(() => {
    const today = new Date();
    const thirtyDaysFromNow = new Date();
    thirtyDaysFromNow.setDate(today.getDate() + 30);

    return activeContracts.filter((contract) => {
      if (!contract.endDate) return false;
      const end = new Date(contract.endDate);
      return end > today && end <= thirtyDaysFromNow;
    });
  }, [activeContracts]);

  useTour(
    "admin-dashboard",
    loading || error
      ? []
      : [
          {
            target: '[data-tour="dashboard-hero"]',
            title: "أهلاً بيك في لوحة التحكم",
            content: "من هنا تقدر تتابع حالة التشغيل اليومي وتحدّث البيانات بضغطة زر.",
          },
          {
            target: '[data-tour="dashboard-kpi-grid"]',
            title: "أهم الأرقام بنظرة واحدة",
            content: "العقود النشطة، عدد العملاء، الفريق الميداني، والمركبات والأجهزة. اضغط على أي بطاقة عشان تروح لصفحتها.",
          },
          {
            target: '[data-tour="dashboard-recent-contracts"]',
            title: "أحدث العقود",
            content: "آخر العقود المضافة في النظام، مع تنبيه لو فيه عقود قريبة من الانتهاء.",
          },
          {
            target: '[data-tour="sidebar-nav"]',
            title: "القائمة الجانبية",
            content: "من هنا توصل لكل أقسام النظام: العقود، العملاء، الفريق الميداني، والمزيد.",
          },
          {
            target: '[data-tour="tour-help-button"]',
            title: "محتاج تعيد الشرح؟",
            content: "اضغط هنا في أي وقت عشان تشوف شرح الصفحة اللي انت فيها تاني.",
          },
        ]
  );

  if (loading) return <LoadingState />;
  if (error) return <ErrorState text={error} />;

  const recentContracts = [...stats.contracts]
    .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
    .slice(0, 6);

  const getTypeName = (id?: string | null) =>
    stats.contractTypes.find((type) => type.id === id)?.name || "غير محدد";

  const getClientName = (contract: Contract) =>
    stats.clientUsers.find((client) => client.id === contract.clientId)?.fullName || "عميل";

  const getClientPhone = (contract: Contract) =>
    stats.clientUsers.find((client) => client.id === contract.clientId)?.phone || "";

  const getLineName = (id?: string | null) => stats.lines.find((line) => line.id === id)?.name || null;

  const getZoneName = (id?: string | null) => stats.zones.find((zone) => zone.id === id)?.name || null;

  const normalizeAddressValue = (value?: string | null) => {
    const normalized = value?.trim();
    return normalized ? normalized : null;
  };

  const stripAddressPrefix = (value: string, prefixes: string[]) => {
    const escaped = prefixes.map((prefix) => prefix.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join("|");
    const cleaned = value.replace(new RegExp(`^(?:${escaped})\\s*[:\\-]?\\s*`, "i"), "").trim();
    return cleaned || value;
  };

  const getCompactAddress = (contract: Contract) => {
    const block = normalizeAddressValue(contract.blockNumber);
    const street = normalizeAddressValue(contract.street);
    const avenue = normalizeAddressValue(contract.avenue);
    const house = normalizeAddressValue(contract.house);

    const parts = [
      {
        shortLabel: "ق",
        value: block ? stripAddressPrefix(block, ["ق", "قطعة", "block"]) : null,
      },
      {
        shortLabel: "ش",
        value: street ? stripAddressPrefix(street, ["ش", "شارع", "street", "st"]) : null,
      },
      {
        shortLabel: "ج",
        value: avenue ? stripAddressPrefix(avenue, ["ج", "جادة", "avenue", "ave"]) : null,
      },
      {
        shortLabel: "م",
        value: house ? stripAddressPrefix(house, ["م", "منزل", "بيت", "house", "home"]) : null,
      },
    ]
      .filter((part) => part.value)
      .map((part) => `${part.shortLabel} ${part.value}`)
      .join(" - ");

    return parts || normalizeAddressValue(contract.addressDetails);
  };

  const getLocationDisplay = (contract: Contract) => {
    const lineName = getLineName(contract.lineId);
    const zoneName = getZoneName(contract.zoneId);
    const compactAddress = getCompactAddress(contract);

    const primaryLocation = zoneName || lineName;
    if (primaryLocation && compactAddress) return `${primaryLocation} • ${compactAddress}`;
    return primaryLocation || compactAddress || "—";
  };

  const kpiCards: KpiCard[] = [
    {
      title: "العقود النشطة",
      value: activeContracts.length,
      sub: `${totalContractValue.toLocaleString()} دينار قيمة إجمالية`,
      icon: FileText,
      tone: "primary",
      link: "/admin/contracts",
    },
    {
      title: "عملاء المؤسسة",
      value: stats.clientUsers.length,
      sub: "عميل مسجل داخل النظام",
      icon: Users,
      tone: "accent",
      link: "/admin/clients",
    },
    {
      title: "الفريق الميداني",
      value: stats.workers.length + activeSupervisors.length,
      sub: `${stats.workers.length} عامل + ${activeSupervisors.length} مشرف`,
      icon: HardHat,
      tone: "success",
      link: "/admin/workers",
    },
    {
      title: "المركبات والأجهزة",
      value: stats.vehicles.length + stats.phones.length,
      sub: `${stats.vehicles.length} مركبة + ${stats.phones.length} جهاز`,
      icon: Truck,
      tone: "info",
      link: "/admin/fleet",
    },
  ];

  const contractStatusRows = [
    {
      label: "نشطة",
      value: activeContracts.length,
      color: "var(--color-success)",
    },
    {
      label: "قيد الانتظار",
      value: pendingContracts.length,
      color: "var(--color-warning)",
    },
    {
      label: "منتهية / ملغاة",
      value: expiredContracts.length,
      color: "var(--color-danger)",
    },
  ];

  const totalContracts = stats.contracts.length || 1;

  return (
    <div className="admin-dashboard fade-in">
      <section className="dashboard-hero" data-tour="dashboard-hero">
        <div className="dashboard-hero-content">
          <h1 className="dashboard-hero-title">مرحبًا، {user?.fullName || "مدير النظام"}</h1>
          <p className="dashboard-hero-subtitle">
            ملخص واضح لحالة التشغيل الحالية حتى تاريخ {formatDate(new Date().toISOString())}
          </p>
        </div>

        <div className="dashboard-hero-actions">
          <button type="button" className="button secondary" onClick={fetchData}>
            <RefreshCw size={16} />
            تحديث البيانات
          </button>
        </div>
      </section>

      <section className="dashboard-kpi-grid" data-tour="dashboard-kpi-grid">
        {kpiCards.map((card) => {
          const Icon = card.icon;
          return (
            <article
              key={card.title}
              className="dashboard-kpi-card clickable"
              onClick={() => navigate(card.link)}
              role="button"
              tabIndex={0}
              onKeyDown={(event) => {
                if (event.key === "Enter" || event.key === " ") {
                  event.preventDefault();
                  navigate(card.link);
                }
              }}
            >
              <div className="dashboard-kpi-head">
                <div>
                  <p className="dashboard-kpi-title">{card.title}</p>
                  <p className="dashboard-kpi-value">{card.value}</p>
                </div>
                <span className={`kpi-icon ${card.tone}`}>
                  <Icon size={20} />
                </span>
              </div>
              <p className="dashboard-kpi-sub">{card.sub}</p>
            </article>
          );
        })}
      </section>

      <section
        className="dashboard-panel dashboard-recent-contracts-panel"
        data-tour="dashboard-recent-contracts"
      >
        <div className="dashboard-panel-header">
          <h3 className="dashboard-panel-title">
            <Clock size={17} />
            أحدث العقود
          </h3>
          <button type="button" className="link-button" onClick={() => navigate("/admin/contracts")}>
            عرض الكل
            <ArrowLeft size={14} />
          </button>
        </div>

        {expiringSoon.length > 0 && (
          <div className="dashboard-alert" style={{ margin: "0 16px 14px" }}>
            <AlertCircle size={20} style={{ color: "var(--color-warning)" }} />
            <div style={{ flex: 1 }}>
              <p className="dashboard-alert-title">تنبيه: عقود قريبة من الانتهاء</p>
              <p className="dashboard-alert-text">
                يوجد {expiringSoon.length} عقد سينتهي خلال 30 يوم. يفضل المتابعة مع قسم التجديد.
              </p>
            </div>
            <button type="button" className="button secondary" onClick={() => navigate("/admin/contracts") }>
              عرض العقود
            </button>
          </div>
        )}

        <div className="dashboard-table-wrap">
          <table className="dashboard-table">
            <thead>
              <tr>
                <th>رقم العقد</th>
                <th>نوع العقد</th>
                <th>العميل</th>
                <th>الموقع</th>
                <th>التواريخ</th>
                <th>الحالة</th>
                <th>القيمة</th>
              </tr>
            </thead>
            <tbody>
              {recentContracts.map((contract) => (
                <tr key={contract.id}>
                  <td style={{ fontFamily: "monospace" }}>{contract.code}</td>
                  <td>{getTypeName(contract.contractTypeId)}</td>
                  <td style={{ whiteSpace: "normal" }}>
                    <div style={{ display: "flex", flexDirection: "column", gap: "4px" }}>
                      <span>{getClientName(contract)}</span>
                      {getClientPhone(contract) && <span className="muted">{getClientPhone(contract)}</span>}
                    </div>
                  </td>
                  <td style={{ whiteSpace: "normal" }}>
                    <div style={{ display: "flex", flexDirection: "column", gap: "4px" }}>
                      <span>{getLineName(contract.lineId) || "—"}</span>
                      <span className="muted">{getLocationDisplay(contract)}</span>
                    </div>
                  </td>
                  <td style={{ whiteSpace: "normal" }}>
                    <div style={{ display: "flex", flexDirection: "column", gap: "4px" }}>
                      <span className="muted">بداية: {formatDate(contract.startDate)}</span>
                      <span className="muted">نهاية: {formatDate(contract.endDate)}</span>
                    </div>
                  </td>
                  <td>
                    <span
                      className={`badge ${
                        normalizeContractStatus(contract.status) === "active"
                          ? "badge-success"
                          : normalizeContractStatus(contract.status) === "pending"
                            ? "badge-warning"
                            : "badge-danger"
                      }`}
                    >
                      {getContractStatusLabel(contract.status)}
                    </span>
                  </td>
                  <td>{contract.totalValue ? `${contract.totalValue.toLocaleString()} دينار` : "-"}</td>
                </tr>
              ))}

              {recentContracts.length === 0 && (
                <tr>
                  <td colSpan={7} className="dashboard-empty">
                    لا توجد عقود حديثة
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>

      <section className="dashboard-section-stack">
        {pendingStatusRequestsCount > 0 && (
          <div className="dashboard-alert">
            <AlertCircle size={20} style={{ color: "var(--color-warning)" }} />
            <div style={{ flex: 1 }}>
              <p className="dashboard-alert-title">طلبات تغيير حالة العقود</p>
              <p className="dashboard-alert-text">
                يوجد {pendingStatusRequestsCount} طلب من المشرفين بانتظار الموافقة.
              </p>
            </div>
            <button
              type="button"
              className="button secondary"
              onClick={() => navigate("/admin/contract-status-requests")}
            >
              مراجعة
            </button>
          </div>
        )}

        <div className="dashboard-summary-grid">
          <div className="dashboard-panel dashboard-equal-panel">
            <div className="dashboard-panel-header">
              <h3 className="dashboard-panel-title">حالة العقود</h3>
            </div>

            <div className="dashboard-status dashboard-equal-body">
              {contractStatusRows.map((row) => (
                <div key={row.label}>
                  <div className="status-row-head">
                    <span className="status-label">
                      <span className="status-dot" style={{ background: row.color }} />
                      {row.label}
                    </span>
                    <span className="status-value">{row.value}</span>
                  </div>
                  <div className="status-track">
                    <div
                      className="status-fill"
                      style={{
                        width: `${(row.value / totalContracts) * 100}%`,
                        background: row.color,
                      }}
                    />
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="dashboard-panel dashboard-equal-panel">
            <div className="dashboard-panel-header">
              <h3 className="dashboard-panel-title">الموارد التشغيلية</h3>
            </div>

            <div className="dashboard-resources dashboard-equal-body">
              <div className="resource-item">
                <span className="resource-icon info">
                  <MapPin size={18} />
                </span>
                <div>
                  <p className="resource-title">المناطق والنطاقات</p>
                  <p className="resource-subtitle">{stats.lines.length} خط جغرافي معرف</p>
                </div>
              </div>

              <div className="resource-item">
                <span className="resource-icon accent">
                  <UserCircle size={18} />
                </span>
                <div>
                  <p className="resource-title">المشرفون الميدانيون</p>
                  <p className="resource-subtitle">{activeSupervisors.length} مشرف نشط</p>
                </div>
              </div>

              <div className="resource-item">
                <span className="resource-icon success">
                  <Phone size={18} />
                </span>
                <div>
                  <p className="resource-title">هواتف الشركة</p>
                  <p className="resource-subtitle">{stats.phones.length} جهاز مسجل</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
};
