import { ShieldAlert } from "lucide-react";
import { useAuth } from "@presentation/state/useAuth";

export const SuspendedPage = () => {
  const { user, logout } = useAuth();

  return (
    <div className="auth-page fade-in">
      <div className="center-card">
        <ShieldAlert size={40} color="#C23030" />
        <h1>حساب الشركة متوقف مؤقتًا</h1>
        <p>
          {user?.tenantName ? `شركة "${user.tenantName}"` : "شركتك"} متوقفة حاليًا عن الوصول إلى النظام.
          للاستفسار أو إعادة التفعيل، تواصل مع فريق الدعم.
        </p>
        <button className="button" onClick={() => logout()}>
          تسجيل خروج
        </button>
      </div>
    </div>
  );
};

export default SuspendedPage;
