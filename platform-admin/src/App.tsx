import { useEffect, useState } from "react";
import { supabase, EDGE_FUNCTIONS_URL } from "./lib/supabase";

type Tenant = {
  id: string;
  name: string;
  slug: string;
  status: "active" | "suspended" | "trial";
  created_at: string;
};

type TenantUser = {
  id: string;
  full_name: string;
  email: string;
  phone: string | null;
  created_at: string;
};

export default function App() {
  const [sessionUserId, setSessionUserId] = useState<string | null>(null);
  const [accessToken, setAccessToken] = useState<string | null>(null);
  const [checkingAuth, setCheckingAuth] = useState(true);
  const [isPlatformOwner, setIsPlatformOwner] = useState(false);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSessionUserId(data.session?.user.id ?? null);
      setAccessToken(data.session?.access_token ?? null);
      setCheckingAuth(false);
    });

    const { data: sub } = supabase.auth.onAuthStateChange((_event, session) => {
      setSessionUserId(session?.user.id ?? null);
      setAccessToken(session?.access_token ?? null);
    });

    return () => sub.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    if (!sessionUserId) {
      setIsPlatformOwner(false);
      return;
    }
    supabase
      .from("users")
      .select("is_platform_owner")
      .eq("id", sessionUserId)
      .maybeSingle()
      .then(({ data }) => setIsPlatformOwner(Boolean(data?.is_platform_owner)));
  }, [sessionUserId]);

  if (checkingAuth) {
    return <div className="center">جارِ التحميل...</div>;
  }

  if (!sessionUserId) {
    return <LoginScreen />;
  }

  if (!isPlatformOwner) {
    return (
      <div className="center">
        <p>حسابك مش مسجّل كمالك منصة (Platform Owner).</p>
        <button onClick={() => supabase.auth.signOut()}>تسجيل خروج</button>
      </div>
    );
  }

  return <CompaniesDashboard accessToken={accessToken!} />;
}

function LoginScreen() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    setLoading(false);
    if (error) setError(error.message);
  }

  return (
    <div className="center">
      <form className="card" onSubmit={handleSubmit}>
        <h1>لوحة إدارة المنصة</h1>
        <input
          type="email"
          placeholder="البريد الإلكتروني"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
        />
        <input
          type="password"
          placeholder="كلمة المرور"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
        />
        {error && <p className="error">{error}</p>}
        <button type="submit" disabled={loading}>
          {loading ? "جارِ الدخول..." : "دخول"}
        </button>
      </form>
    </div>
  );
}

function CompaniesDashboard({ accessToken }: { accessToken: string }) {
  const [tenants, setTenants] = useState<Tenant[]>([]);
  const [userCounts, setUserCounts] = useState<Record<string, number>>({});
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState<Tenant | null>(null);
  const [showCreate, setShowCreate] = useState(false);

  async function reload() {
    setLoading(true);
    const { data: tenantRows } = await supabase
      .from("tenants")
      .select("id, name, slug, status, created_at")
      .order("created_at", { ascending: false });

    setTenants(tenantRows ?? []);

    const counts: Record<string, number> = {};
    for (const t of tenantRows ?? []) {
      const { count } = await supabase
        .from("users")
        .select("id", { count: "exact", head: true })
        .eq("tenant_id", t.id);
      counts[t.id] = count ?? 0;
    }
    setUserCounts(counts);
    setLoading(false);
  }

  useEffect(() => {
    reload();
  }, []);

  async function toggleStatus(tenant: Tenant) {
    const nextStatus = tenant.status === "suspended" ? "active" : "suspended";
    await supabase.from("tenants").update({ status: nextStatus }).eq("id", tenant.id);
    reload();
  }

  return (
    <div className="page">
      <header className="topbar">
        <h1>الشركات</h1>
        <div>
          <button onClick={() => setShowCreate(true)}>+ إضافة شركة</button>
          <button onClick={() => supabase.auth.signOut()}>تسجيل خروج</button>
        </div>
      </header>

      {loading ? (
        <p>جارِ التحميل...</p>
      ) : (
        <table className="table">
          <thead>
            <tr>
              <th>الاسم</th>
              <th>Slug</th>
              <th>الحالة</th>
              <th>عدد المستخدمين</th>
              <th>تاريخ الإنشاء</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {tenants.map((t) => (
              <tr key={t.id}>
                <td>
                  <a href="#" onClick={(e) => { e.preventDefault(); setSelected(t); }}>
                    {t.name}
                  </a>
                </td>
                <td>{t.slug}</td>
                <td>
                  <span className={`badge badge-${t.status}`}>{t.status}</span>
                </td>
                <td>{userCounts[t.id] ?? "..."}</td>
                <td>{new Date(t.created_at).toLocaleDateString("ar-EG")}</td>
                <td>
                  <button onClick={() => toggleStatus(t)}>
                    {t.status === "suspended" ? "تفعيل" : "تعليق"}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      {showCreate && (
        <CreateCompanyModal
          accessToken={accessToken}
          onClose={() => setShowCreate(false)}
          onCreated={() => {
            setShowCreate(false);
            reload();
          }}
        />
      )}

      {selected && <CompanyDetailModal tenant={selected} onClose={() => setSelected(null)} />}
    </div>
  );
}

function CreateCompanyModal({
  accessToken,
  onClose,
  onCreated,
}: {
  accessToken: string;
  onClose: () => void;
  onCreated: () => void;
}) {
  const [companyName, setCompanyName] = useState("");
  const [companySlug, setCompanySlug] = useState("");
  const [adminFullName, setAdminFullName] = useState("");
  const [adminEmail, setAdminEmail] = useState("");
  const [adminPhone, setAdminPhone] = useState("");
  const [adminPassword, setAdminPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);

    const res = await fetch(`${EDGE_FUNCTIONS_URL}/platform-create-company`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({ companyName, companySlug, adminFullName, adminEmail, adminPhone, adminPassword }),
    });

    const json = await res.json();
    setLoading(false);

    if (!res.ok || !json.success) {
      setError(json.message || json.error || "حدث خطأ");
      return;
    }

    onCreated();
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <form className="card" onClick={(e) => e.stopPropagation()} onSubmit={handleSubmit}>
        <h2>إضافة شركة جديدة</h2>
        <input placeholder="اسم الشركة" value={companyName} onChange={(e) => setCompanyName(e.target.value)} required />
        <input placeholder="slug (اختياري)" value={companySlug} onChange={(e) => setCompanySlug(e.target.value)} />
        <hr />
        <p className="hint">أول حساب أدمن للشركة:</p>
        <input placeholder="اسم الأدمن" value={adminFullName} onChange={(e) => setAdminFullName(e.target.value)} required />
        <input placeholder="بريد الأدمن" type="email" value={adminEmail} onChange={(e) => setAdminEmail(e.target.value)} required />
        <input placeholder="رقم موبايل الأدمن" value={adminPhone} onChange={(e) => setAdminPhone(e.target.value)} required />
        <input placeholder="كلمة مرور الأدمن" type="password" value={adminPassword} onChange={(e) => setAdminPassword(e.target.value)} required />
        {error && <p className="error">{error}</p>}
        <div className="modal-actions">
          <button type="button" onClick={onClose}>إلغاء</button>
          <button type="submit" disabled={loading}>{loading ? "جارِ الإنشاء..." : "إنشاء"}</button>
        </div>
      </form>
    </div>
  );
}

function CompanyDetailModal({ tenant, onClose }: { tenant: Tenant; onClose: () => void }) {
  const [users, setUsers] = useState<TenantUser[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    supabase
      .from("users")
      .select("id, full_name, email, phone, created_at")
      .eq("tenant_id", tenant.id)
      .order("created_at", { ascending: false })
      .then(({ data }) => {
        setUsers(data ?? []);
        setLoading(false);
      });
  }, [tenant.id]);

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="card" onClick={(e) => e.stopPropagation()}>
        <h2>{tenant.name}</h2>
        <p className="hint">
          {tenant.slug} — <span className={`badge badge-${tenant.status}`}>{tenant.status}</span>
        </p>
        <h3>المستخدمين ({users.length})</h3>
        {loading ? (
          <p>جارِ التحميل...</p>
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>الاسم</th>
                <th>البريد</th>
                <th>الموبايل</th>
              </tr>
            </thead>
            <tbody>
              {users.map((u) => (
                <tr key={u.id}>
                  <td>{u.full_name}</td>
                  <td>{u.email}</td>
                  <td>{u.phone}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
        <div className="modal-actions">
          <button onClick={onClose}>إغلاق</button>
        </div>
      </div>
    </div>
  );
}
