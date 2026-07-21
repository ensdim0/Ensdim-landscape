import { Clock } from "lucide-react";
import { useAuth } from "@presentation/state/useAuth";

export const PendingApprovalPage = () => {
  const { user, logout } = useAuth();

  return (
    <div className="auth-page fade-in">
      <div className="center-card">
        <Clock size={40} color="#856404" />
        <h1>حساب الشركة بانتظار الموافقة</h1>
        <p>
          {user?.tenantName ? `شركة "${user.tenantName}"` : "شركتك"} لسه بانتظار موافقة فريق المنصة
          قبل ما تقدر تستخدم النظام. هنبلغك بمجرد ما يتم تفعيل الحساب.
        </p>
        <button className="button" onClick={() => logout()}>
          تسجيل خروج
        </button>
      </div>
    </div>
  );
};

export default PendingApprovalPage;
