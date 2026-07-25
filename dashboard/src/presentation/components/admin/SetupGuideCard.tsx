import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  Check,
  ArrowLeft,
  X,
  FileText,
  MapPin,
  UserCircle,
  Truck,
  HardHat,
  ClipboardList,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";

interface SetupGuideCardProps {
  contractTypesCount: number;
  linesCount: number;
  supervisorsCount: number;
  vehiclesCount: number;
  phonesCount: number;
  workersCount: number;
  contractsCount: number;
  tenantId?: string;
}

type StepPriority = "required" | "recommended" | "goal";

interface SetupStep {
  title: string;
  desc: string;
  icon: LucideIcon;
  route: string;
  priority: StepPriority;
  done: boolean;
}

const priorityLabel: Record<StepPriority, string> = {
  required: "مطلوب",
  recommended: "موصى به",
  goal: "الهدف",
};

const dismissedKey = (tenantId?: string) => `setup_guide_dismissed_${tenantId || "default"}`;

export const SetupGuideCard = ({
  contractTypesCount,
  linesCount,
  supervisorsCount,
  vehiclesCount,
  phonesCount,
  workersCount,
  contractsCount,
  tenantId,
}: SetupGuideCardProps) => {
  const navigate = useNavigate();
  const [dismissed, setDismissed] = useState(() => localStorage.getItem(dismissedKey(tenantId)) === "1");

  const steps: SetupStep[] = useMemo(
    () => [
      {
        title: "أنواع العقود",
        desc: "عرّف نوع عقد واحد على الأقل قبل إنشاء أي عقد جديد",
        icon: FileText,
        route: "/admin/contract-types",
        priority: "required",
        done: contractTypesCount > 0,
      },
      {
        title: "الخطوط والمناطق",
        desc: "أضف خطًا ومنطقة لتحديد موقع العقود جغرافيًا",
        icon: MapPin,
        route: "/admin/lines-only",
        priority: "required",
        done: linesCount > 0,
      },
      {
        title: "المشرفون",
        desc: "أضف مشرفًا ليتابع تنفيذ العقود ميدانيًا",
        icon: UserCircle,
        route: "/admin/supervisors",
        priority: "recommended",
        done: supervisorsCount > 0,
      },
      {
        title: "أسطول السيارات والهواتف",
        desc: "سجّل السيارات وهواتف الشركة المستخدمة في التشغيل",
        icon: Truck,
        route: "/admin/fleet",
        priority: "recommended",
        done: vehiclesCount > 0 || phonesCount > 0,
      },
      {
        title: "العمالة",
        desc: "أضف عمال التنفيذ المرتبطين بالمشرفين",
        icon: HardHat,
        route: "/admin/workers",
        priority: "recommended",
        done: workersCount > 0,
      },
      {
        title: "إنشاء أول عقد",
        desc: "أنشئ أول عميل وعقد بعد استكمال الإعدادات السابقة",
        icon: ClipboardList,
        route: "/admin/contracts",
        priority: "goal",
        done: contractsCount > 0,
      },
    ],
    [contractTypesCount, linesCount, supervisorsCount, vehiclesCount, phonesCount, workersCount, contractsCount],
  );

  const completedCount = steps.filter((step) => step.done).length;
  const allComplete = completedCount === steps.length;

  if (dismissed || allComplete) return null;

  const handleDismiss = () => {
    localStorage.setItem(dismissedKey(tenantId), "1");
    setDismissed(true);
  };

  return (
    <section className="dashboard-panel setup-guide-card">
      <div className="dashboard-panel-header">
        <span className="dashboard-panel-title">
          <ClipboardList size={18} />
          دليل البدء
        </span>
        <div className="setup-guide-header-actions">
          <span className="setup-guide-progress-text">
            {completedCount} من {steps.length} خطوات مكتملة
          </span>
          <button
            type="button"
            className="icon-button"
            onClick={handleDismiss}
            aria-label="إخفاء دليل البدء"
          >
            <X size={16} />
          </button>
        </div>
      </div>
      <div className="setup-guide-progress-track status-track">
        <div
          className="status-fill"
          style={{
            width: `${(completedCount / steps.length) * 100}%`,
            background: "var(--color-success)",
          }}
        />
      </div>
      <div className="setup-guide-steps">
        {steps.map((step) => {
          const Icon = step.icon;
          return (
            <div
              key={step.title}
              className={`setup-guide-step${step.done ? " done" : ""}`}
              role="button"
              tabIndex={0}
              onClick={() => navigate(step.route)}
              onKeyDown={(event) => {
                if (event.key === "Enter" || event.key === " ") {
                  event.preventDefault();
                  navigate(step.route);
                }
              }}
            >
              <span className={`resource-icon ${step.done ? "success" : "info"}`}>
                {step.done ? <Check size={18} /> : <Icon size={18} />}
              </span>
              <div className="setup-guide-step-body">
                <div className="setup-guide-step-title-row">
                  <span className="resource-title">{step.title}</span>
                  {!step.done && (
                    <span className={`badge badge-${step.priority === "required" ? "warning" : "info"}`}>
                      {priorityLabel[step.priority]}
                    </span>
                  )}
                </div>
                <span className="resource-subtitle">{step.desc}</span>
              </div>
              <span className="link-button setup-guide-step-link">
                ابدأ <ArrowLeft size={14} />
              </span>
            </div>
          );
        })}
      </div>
    </section>
  );
};
