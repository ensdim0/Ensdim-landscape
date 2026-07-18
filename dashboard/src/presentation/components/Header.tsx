import { FormEvent, ReactNode, useEffect, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  ChevronDown,
  Key,
  Loader2,
  LogOut,
  Mail,
  Menu,
  Phone,
  Save,
  Settings,
  User,
  X,
} from "lucide-react";
import { useAuth } from "@presentation/state/useAuth";
import { container } from "@infrastructure/di/container";
import { updateUser } from "@application/use-cases/admin/updateUser";
import { useToast } from "@presentation/components/ToastProvider";
import Notifications from "@presentation/components/Notifications";

export const Header = ({ onMenuClick }: { onMenuClick?: () => void }) => {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const { notify } = useToast();

  const [isProfileOpen, setIsProfileOpen] = useState(false);
  const [showEditProfile, setShowEditProfile] = useState(false);
  const [showChangePassword, setShowChangePassword] = useState(false);
  const profileRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const handleOutside = (event: MouseEvent) => {
      if (profileRef.current && !profileRef.current.contains(event.target as Node)) {
        setIsProfileOpen(false);
      }
    };

    document.addEventListener("mousedown", handleOutside);
    return () => document.removeEventListener("mousedown", handleOutside);
  }, []);

  const handleLogout = async () => {
    await logout();
    navigate("/login", { replace: true });
  };

  const roleLabel =
    user?.role === "admin" ? "مدير النظام" : user?.role === "supervisor" ? "مشرف ميداني" : "مستخدم";

  return (
    <>
      <header className="main-header">
        <div className="header-start">
          <button
            className="mobile-menu-toggle header-menu-button"
            type="button"
            onClick={onMenuClick}
            aria-label="فتح القائمة"
          >
            <Menu size={20} />
          </button>

          <div className="header-title-block">
            <p className="header-eyebrow">لوحة التحكم</p>
            <h2 className="header-title">متابعة التشغيل اليومي</h2>
          </div>
        </div>

        <div className="header-actions">
          <Notifications />

          <div className="profile-dropdown" ref={profileRef}>
            <button
              type="button"
              className={`profile-trigger ${isProfileOpen ? "is-open" : ""}`}
              onClick={() => setIsProfileOpen((prev) => !prev)}
            >
              <span className="profile-avatar">
                <User size={16} />
              </span>

              <span className="profile-text">
                <span className="profile-name">{user?.fullName || user?.email?.split("@")[0] || "مستخدم"}</span>
                <span className="profile-role">{roleLabel}</span>
              </span>

              <ChevronDown size={14} className="profile-chevron" />
            </button>

            {isProfileOpen && (
              <div className="profile-menu">
                <div className="profile-menu-info">
                  <div className="profile-menu-name">{user?.fullName || "مستخدم"}</div>
                  <div className="profile-menu-meta">{user?.email}</div>
                  {user?.phone && <div className="profile-menu-meta ltr">{user.phone}</div>}
                </div>

                <MenuButton
                  icon={<Settings size={15} />}
                  label="تعديل الملف الشخصي"
                  onClick={() => {
                    setIsProfileOpen(false);
                    setShowEditProfile(true);
                  }}
                />
                <MenuButton
                  icon={<Key size={15} />}
                  label="تغيير كلمة المرور"
                  onClick={() => {
                    setIsProfileOpen(false);
                    setShowChangePassword(true);
                  }}
                />

                <div className="profile-menu-divider" />

                <MenuButton icon={<LogOut size={15} />} label="تسجيل الخروج" onClick={handleLogout} danger />
              </div>
            )}
          </div>
        </div>
      </header>

      {showEditProfile && user && (
        <EditProfileModal
          user={user}
          onClose={() => setShowEditProfile(false)}
          onSaved={() => {
            setShowEditProfile(false);
            notify("تم تحديث البيانات بنجاح");
            window.location.reload();
          }}
        />
      )}

      {showChangePassword && user && (
        <ChangePasswordModal
          userId={user.id}
          onClose={() => setShowChangePassword(false)}
          onSaved={() => {
            setShowChangePassword(false);
            notify("تم تغيير كلمة المرور بنجاح");
          }}
        />
      )}
    </>
  );
};

const MenuButton = ({
  icon,
  label,
  onClick,
  danger,
}: {
  icon: ReactNode;
  label: string;
  onClick: () => void;
  danger?: boolean;
}) => (
  <button type="button" onClick={onClick} className={`profile-menu-item ${danger ? "danger" : ""}`}>
    {icon}
    <span>{label}</span>
  </button>
);

const Modal = ({
  title,
  onClose,
  children,
}: {
  title: string;
  onClose: () => void;
  children: ReactNode;
}) => (
  <div className="app-modal-overlay">
    <div className="app-modal">
      <div className="app-modal-head">
        <h3 className="app-modal-title">{title}</h3>
        <button type="button" className="app-modal-close" onClick={onClose} aria-label="إغلاق">
          <X size={18} />
        </button>
      </div>
      {children}
    </div>
  </div>
);

const EditProfileModal = ({
  user,
  onClose,
  onSaved,
}: {
  user: { id: string; fullName: string; email: string; phone?: string };
  onClose: () => void;
  onSaved: () => void;
}) => {
  const [fullName, setFullName] = useState(user.fullName || "");
  const [phone, setPhone] = useState(user.phone || "");
  const [loading, setLoading] = useState(false);
  const { notify } = useToast();

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    setLoading(true);

    try {
      const result = await updateUser(container.adminRepository, {
        id: user.id,
        fullName,
        email: user.email,
        ...(phone ? { phone } : {}),
      });

      if (result.ok) {
        onSaved();
      } else {
        notify(result.error?.message || "فشل تحديث البيانات");
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <Modal title="تعديل الملف الشخصي" onClose={onClose}>
      <form onSubmit={handleSubmit} className="profile-form">
        <div className="field">
          <label className="profile-form-label">
            <Mail size={14} /> البريد الإلكتروني
          </label>
          <div className="profile-form-readonly ltr">{user.email}</div>
        </div>

        <div className="field">
          <label className="profile-form-label">
            <User size={14} /> الاسم الكامل <span style={{ color: "var(--color-error)" }}>*</span>
          </label>
          <input
            className="input"
            value={fullName}
            onChange={(e) => setFullName(e.target.value)}
            required
            placeholder="أدخل الاسم الكامل"
          />
        </div>

        <div className="field">
          <label className="profile-form-label">
            <Phone size={14} /> رقم الهاتف
          </label>
          <input
            className="input"
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            placeholder="رقم الهاتف (اختياري)"
            dir="ltr"
            style={{ textAlign: "right" }}
          />
        </div>

        <div className="modal-actions">
          <button className="button" type="submit" disabled={loading} style={{ flex: 1 }}>
            {loading ? <Loader2 size={16} className="spin" /> : <Save size={16} />}
            {loading ? "جار الحفظ..." : "حفظ التغييرات"}
          </button>
          <button className="button secondary" type="button" onClick={onClose} disabled={loading}>
            إلغاء
          </button>
        </div>
      </form>
    </Modal>
  );
};

const ChangePasswordModal = ({
  userId,
  onClose,
  onSaved,
}: {
  userId: string;
  onClose: () => void;
  onSaved: () => void;
}) => {
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const { notify } = useToast();

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();

    if (password !== confirmPassword) {
      notify("كلمة المرور غير متطابقة");
      return;
    }

    if (password.length < 6) {
      notify("كلمة المرور يجب أن تكون 6 أحرف على الأقل");
      return;
    }

    setLoading(true);

    try {
      const result = await updateUser(container.adminRepository, {
        id: userId,
        password,
      });

      if (result.ok) {
        onSaved();
      } else {
        notify(result.error?.message || "فشل تغيير كلمة المرور");
      }
    } finally {
      setLoading(false);
    }
  };

  const mismatch = Boolean(password && confirmPassword && password !== confirmPassword);

  return (
    <Modal title="تغيير كلمة المرور" onClose={onClose}>
      <form onSubmit={handleSubmit} className="profile-form">
        <div className="field">
          <label className="profile-form-label">
            <Key size={14} /> كلمة المرور الجديدة <span style={{ color: "var(--color-error)" }}>*</span>
          </label>
          <input
            className="input"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            minLength={6}
            placeholder="6 أحرف على الأقل"
            dir="ltr"
            style={{ textAlign: "right" }}
          />
        </div>

        <div className="field">
          <label className="profile-form-label">
            <Key size={14} /> تأكيد كلمة المرور <span style={{ color: "var(--color-error)" }}>*</span>
          </label>
          <input
            className="input"
            type="password"
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            required
            minLength={6}
            placeholder="أعد إدخال كلمة المرور"
            dir="ltr"
            style={{ textAlign: "right" }}
          />
        </div>

        {mismatch && <div className="form-note-error">كلمة المرور غير متطابقة</div>}

        <div className="modal-actions">
          <button className="button" type="submit" disabled={loading || mismatch} style={{ flex: 1 }}>
            {loading ? <Loader2 size={16} className="spin" /> : <Key size={16} />}
            {loading ? "جار التغيير..." : "تغيير كلمة المرور"}
          </button>
          <button className="button secondary" type="button" onClick={onClose} disabled={loading}>
            إلغاء
          </button>
        </div>
      </form>
    </Modal>
  );
};
