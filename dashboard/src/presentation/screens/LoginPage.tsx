import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "@presentation/state/useAuth";
import { Mail, Loader2, ShieldAlert, Eye, EyeOff } from "lucide-react";
import { checkRateLimit, recordFailedAttempt, resetRateLimit, formatLockoutTime } from "@core/security/rateLimiter";
import { sanitizeIdentifier } from "@shared/utils/sanitize";
import logoImage from "../../../assets/logo10.png";
import backgroundImage from "../../../assets/background-imag.jpg";

export const LoginPage = () => {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isLocked, setIsLocked] = useState(false);
  const [showPassword, setShowPassword] = useState(false);

  const onSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!email || !password) {
        setError("يرجى إدخال البريد الإلكتروني وكلمة المرور");
        return;
    }

    const loginIdentifier = sanitizeIdentifier(email);
    if (!loginIdentifier) {
      setError("البريد الإلكتروني أو رقم الهاتف غير صالح");
      return;
    }

    const rateCheck = checkRateLimit(loginIdentifier);
    if (!rateCheck.allowed) {
      setIsLocked(true);
      setError(`تم تجاوز الحد المسموح. حاول مرة أخرى بعد ${formatLockoutTime(rateCheck.retryAfterMs)}`);
      return;
    }

    setIsLocked(false);
    
    setLoading(true);
    setError(null);
    
    try {
        const ok = await login(loginIdentifier, password);
        if (ok) {
          resetRateLimit(loginIdentifier);
          navigate("/admin");
        } else {
            recordFailedAttempt(loginIdentifier);
            const updated = checkRateLimit(loginIdentifier);
            if (updated.remainingAttempts > 0) {
              setError(`بيانات الدخول غير صحيحة. ${updated.remainingAttempts} محاولات متبقية`);
            } else {
              setIsLocked(true);
              setError(`تم تجاوز الحد المسموح. حاول مرة أخرى بعد ${formatLockoutTime(updated.retryAfterMs)}`);
            }
        }
    } catch (e) {
        setError("حدث خطأ أثناء تسجيل الدخول");
    } finally {
        setLoading(false);
    }
  };

  return (
    <div className="auth-page fade-in">
      <div className="auth-shell">
        <aside className="auth-side" style={{ backgroundImage: `url(${backgroundImage})` }}>
          <div className="auth-side-overlay" />
          <div className="auth-side-content">
            <div className="auth-logo-wrap">
              <img src={logoImage} alt="شعار Ensdim" className="auth-logo" />
            </div>
            <h1 className="auth-side-title">Ensdim</h1>
            <p className="auth-side-subtitle">إدارة شاملة للعمليات والعقود والفرق الميدانية</p>
            <p className="auth-side-note">لوحة بسيطة وسريعة لمتابعة الأداء اليومي واتخاذ قرارات أوضح.</p>
          </div>
        </aside>

        <section className="auth-panel">
          <div className="auth-panel-head">
            <h2 className="auth-title">تسجيل الدخول</h2>
            <p className="auth-subtitle">أدخل بياناتك للوصول إلى النظام</p>
          </div>

          <form onSubmit={onSubmit} className="auth-form">
            {error && (
              <div className={`auth-alert ${isLocked ? "is-locked" : "is-error"}`}>
                <ShieldAlert size={16} />
                <span>{error}</span>
              </div>
            )}

            <div className="auth-field">
              <label className="auth-label">البريد الإلكتروني أو رقم الهاتف</label>
              <div className="auth-input-wrap">
                <span className="auth-input-icon">
                  <Mail size={18} />
                </span>
                <input
                  className="input auth-input ltr-input"
                  placeholder="email@example.com أو رقم هاتفك"
                  type="text"
                  dir="ltr"
                  value={email}
                  onChange={(event) => setEmail(event.target.value)}
                />
              </div>
            </div>

            <div className="auth-field">
              <label className="auth-label">كلمة المرور</label>
              <div className="auth-input-wrap">
                <input
                  className="input auth-input auth-password-input ltr-input"
                  type={showPassword ? "text" : "password"}
                  placeholder="••••••••"
                  dir="ltr"
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((current) => !current)}
                  aria-label={showPassword ? "إخفاء كلمة المرور" : "إظهار كلمة المرور"}
                  aria-pressed={showPassword}
                  className="auth-password-toggle"
                >
                  {showPassword ? <EyeOff size={17} /> : <Eye size={17} />}
                </button>
              </div>
            </div>

            <button className={`button auth-submit ${isLocked ? "is-locked" : ""}`} type="submit" disabled={loading || isLocked}>
              {loading ? <Loader2 size={22} className="spin" /> : isLocked ? "تم قفل الحساب مؤقتا" : "دخول النظام"}
            </button>
          </form>

          <div className="auth-footer">© 2026 Ensdim - جميع الحقوق محفوظة</div>
        </section>
      </div>
    </div>
  );
};
