import { NavLink } from "react-router-dom";
import {
  Car,
  CheckSquare,
  ChevronLeft,
  ChevronRight,
  FileText,
  FileType,
  HardHat,
  LayoutDashboard,
  LogOut,
  Map,
  MessageSquareMore,
  Phone,
  UserCheck,
  Users,
  Wallet,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { useAuth } from "@presentation/state/useAuth";
import logoImage from "../../../assets/logo10.png";

type NavSection = {
  links: Array<{
    to: string;
    label: string;
    icon: LucideIcon;
    end?: boolean;
  }>;
};

const sections: NavSection[] = [
  {
    links: [
      { to: "/admin", label: "لوحة الإدارة", icon: LayoutDashboard, end: true },
      { to: "/admin/lines-only", label: "الخطوط والمناطق", icon: Map },
    ],
  },
  {
    links: [
      { to: "/admin/contracts", label: "العقود", icon: FileText },
      { to: "/admin/contract-types", label: "أنواع العقود", icon: FileType },
      { to: "/admin/tasks", label: "المهام المستقلة", icon: CheckSquare },
    ],
  },
  {
    links: [
      { to: "/admin/contact-requests", label: "طلبات التواصل", icon: MessageSquareMore },
    ],
  },
  {
    links: [
      { to: "/admin/supervisors", label: "المشرفون", icon: UserCheck },
      { to: "/admin/fleet", label: "أسطول السيارات", icon: Car },
      { to: "/admin/phones", label: "هواتف الشركة", icon: Phone },
      { to: "/admin/workers", label: "العمالة", icon: HardHat },
      { to: "/admin/users", label: "المستخدمين", icon: Users },
    ],
  },
  {
    links: [
      { to: "/admin/company-accounts", label: "حسابات الشركة", icon: Wallet },
    ],
  },
];

export const Sidebar = ({
  onClose,
  collapsed,
  onToggleCollapse,
}: {
  onClose?: () => void;
  collapsed?: boolean;
  onToggleCollapse?: () => void;
}) => {
  const { logout } = useAuth();

  const linkClass = ({ isActive }: { isActive: boolean }) =>
    `nav-item ${isActive ? "active" : ""}`;

  return (
    <>
      <div className="sidebar-header">
        <div className="sidebar-brand">
          <img src={logoImage} alt="بستان أماري" />
        </div>
      </div>

      {onToggleCollapse && (
        <button
          className="sidebar-collapse-toggle"
          onClick={onToggleCollapse}
          aria-label={collapsed ? "فتح الشريط" : "إغلاق الشريط"}
          type="button"
        >
          {collapsed ? <ChevronLeft size={13} /> : <ChevronRight size={13} />}
        </button>
      )}

      <nav className="sidebar-content">
        {sections.map((section, i) => (
          <div key={i} className="nav-group">
            {section.links.map((link) => {
              const Icon = link.icon;
              return (
                <NavLink
                  key={link.to}
                  to={link.to}
                  end={link.end}
                  className={linkClass}
                  onClick={onClose}
                  title={collapsed ? link.label : undefined}
                >
                  <span className="nav-icon">
                    <Icon size={17} />
                  </span>
                  <span className="nav-label">{link.label}</span>
                </NavLink>
              );
            })}
          </div>
        ))}
      </nav>

      <div className="sidebar-footer">
        <button
          onClick={logout}
          className="nav-item nav-item-logout"
          type="button"
          title="تسجيل الخروج"
        >
          <span className="nav-icon">
            <LogOut size={17} />
          </span>
          <span className="nav-label">تسجيل الخروج</span>
        </button>
      </div>
    </>
  );
};
