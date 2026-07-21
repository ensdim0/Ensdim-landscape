import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useAuth } from "@presentation/state/useAuth";
import { Building2, Loader2, ShieldAlert, Eye, EyeOff, MailCheck } from "lucide-react";
import logoImage from "../../../assets/logo10.png";
import backgroundImage from "../../../assets/background-imag.jpg";

export const RegisterPage = () => {
  const { registerCompany } = useAuth();
  const navigate = useNavigate();
  const [companyName, setCompanyName] = useState("");
  const [fullName, setFullName] = useState("");
  const [phone, setPhone] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [submitted, setSubmitted] = useState(false);

  const onSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);

    if (!companyName || !fullName || !phone || !email || !password) {
      setError("يرجى ملء جميع الحقول");
      return;
    }
    if (password !== confirmPassword) {
      setError("كلمة المرور وتأكيدها غير متطابقين");
      return;
    }

    setLoading(true);
    try {
      const ok = await registerCompany({ companyName, fullName, phone, email, password });
      if (ok) {
        setSubmitted(true);
      }
    } finally {
      setLoading(false);
    }
  };

  if (submitted) {
    return (
      <div className="auth-page fade-in">
        <div className="center-card">
          <MailCheck size={40} color="#453375" />
          <h1>تحقق من بريدك الإلكتروني</h1>
          <p>
            بعتنالك رابط تأكيد على <b dir="ltr">{email}</b>. بعد ما تأكد إيميلك، سجّل دخولك وهتلاقي
            حسابك بانتظار موافقة فريق المنصة قبل ما تقدر تستخدم النظام.
          </p>
          <button className="button" onClick={() => navigate("/login")}>
            الذهاب لتسجيل الدخول
          </button>
        </div>
      </div>
    );
  }

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
            <p className="auth-side-note">سجّل شركتك وابدأ تجربة النظام بعد موافقة فريقنا.</p>
          </div>
        </aside>

        <section className="auth-panel">
          <div className="auth-panel-head">
            <h2 className="auth-title">تسجيل شركة جديدة</h2>
            <p className="auth-subtitle">أنشئ حساب شركتك على المنصة</p>
          </div>

          <form onSubmit={onSubmit} className="auth-form">
            {error && (
              <div className="auth-alert is-error">
                <ShieldAlert size={16} />
                <span>{error}</span>
              </div>
            )}

            <div className="auth-field">
              <label className="auth-label">اسم الشركة</label>
              <div className="auth-input-wrap">
                <span className="auth-input-icon">
                  <Building2 size={18} />
                </span>
                <input
                  className="input auth-input"
                  placeholder="اسم شركتك"
                  type="text"
                  value={companyName}
                  onChange={(event) => setCompanyName(event.target.value)}
                />
              </div>
            </div>

            <div className="auth-field">
              <label className="auth-label">الاسم الكامل</label>
              <div className="auth-input-wrap">
                <input
                  className="input auth-input"
                  placeholder="اسمك بالكامل"
                  type="text"
                  value={fullName}
                  onChange={(event) => setFullName(event.target.value)}
                />
              </div>
            </div>

            <div className="auth-field">
              <label className="auth-label">رقم الموبايل</label>
              <div className="auth-input-wrap">
                <input
                  className="input auth-input ltr-input"
                  placeholder="01xxxxxxxxx"
                  type="text"
                  dir="ltr"
                  value={phone}
                  onChange={(event) => setPhone(event.target.value)}
                />
              </div>
            </div>

            <div className="auth-field">
              <label className="auth-label">البريد الإلكتروني</label>
              <div className="auth-input-wrap">
                <input
                  className="input auth-input ltr-input"
                  placeholder="email@example.com"
                  type="email"
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

            <div className="auth-field">
              <label className="auth-label">تأكيد كلمة المرور</label>
              <div className="auth-input-wrap">
                <input
                  className="input auth-input ltr-input"
                  type={showPassword ? "text" : "password"}
                  placeholder="••••••••"
                  dir="ltr"
                  value={confirmPassword}
                  onChange={(event) => setConfirmPassword(event.target.value)}
                />
              </div>
            </div>

            <button className="button auth-submit" type="submit" disabled={loading}>
              {loading ? <Loader2 size={22} className="spin" /> : "إنشاء الحساب"}
            </button>
          </form>

          <div className="auth-alt-link">
            عندك حساب بالفعل؟ <Link to="/login">سجّل دخولك</Link>
          </div>

          <div className="auth-footer">© 2026 Ensdim - جميع الحقوق محفوظة</div>
        </section>
      </div>
    </div>
  );
};

export default RegisterPage;
