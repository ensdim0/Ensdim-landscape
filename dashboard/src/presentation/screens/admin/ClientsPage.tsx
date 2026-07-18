import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Users, Mail, Phone, Briefcase, ArrowRight, Eye } from "lucide-react";

import { container } from "@infrastructure/di/container";
import { User } from "@domain/entities/User";
import { Contract } from "@domain/entities/Contract";
import { LoadingState, ErrorState } from "@presentation/components/States";

type ClientRow = User & { contractCount: number; activeContractCount: number };

export const ClientsPage = () => {
  const navigate = useNavigate();
  const [clients, setClients] = useState<ClientRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState("");

  useEffect(() => {
    let mounted = true;

    const load = async () => {
      try {
        setLoading(true);
        const [clientUsers, contracts] = await Promise.all([
          container.adminRepository.listClientUsers(),
          container.adminRepository.listContracts(),
        ]);

        if (!mounted) return;

        const contractStats = new Map<string, { total: number; active: number }>();
        for (const contract of contracts) {
          const current = contractStats.get(contract.clientId) || { total: 0, active: 0 };
          current.total += 1;
          if (contract.status === "active") current.active += 1;
          contractStats.set(contract.clientId, current);
        }

        setClients(
          clientUsers.map((client) => {
            const stats = contractStats.get(client.id) || { total: 0, active: 0 };
            return {
              ...client,
              contractCount: stats.total,
              activeContractCount: stats.active,
            };
          })
        );
      } catch {
        if (mounted) setError("تعذر تحميل العملاء");
      } finally {
        if (mounted) setLoading(false);
      }
    };

    load();

    return () => {
      mounted = false;
    };
  }, []);

  const filteredClients = useMemo(() => {
    const query = searchQuery.trim().toLowerCase();
    if (!query) return clients;
    return clients.filter((client) => {
      return (
        client.fullName.toLowerCase().includes(query) ||
        client.email.toLowerCase().includes(query) ||
        (client.phone || "").toLowerCase().includes(query)
      );
    });
  }, [clients, searchQuery]);

  if (loading) return <LoadingState />;
  if (error) return <ErrorState text={error} />;

  return (
    <div style={{ padding: "32px", display: "flex", flexDirection: "column", gap: "24px" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: "16px", flexWrap: "wrap" }}>
        <div>
          <h1 style={{ margin: 0, fontSize: "1.75rem", fontWeight: 800, color: "var(--text-primary)" }}>
            عملاء المنشأة
          </h1>
          <p style={{ margin: "6px 0 0", color: "var(--text-tertiary)" }}>
            عرض جميع العملاء والانتقال إلى ملف كل عميل
          </p>
        </div>

        <button
          onClick={() => navigate("/admin/contracts")}
          className="button secondary"
          style={{ display: "inline-flex", alignItems: "center", gap: "8px" }}
        >
          <ArrowRight size={16} />
          العودة للعقود
        </button>
      </div>

      <div className="card" style={{ padding: "16px" }}>
        <input
          className="input"
          type="text"
          placeholder="ابحث باسم العميل أو البريد أو الهاتف..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          style={{ width: "100%" }}
        />
      </div>

      <div className="card" style={{ padding: 0, overflow: "hidden" }}>
        <div style={{ padding: "20px 24px", borderBottom: "1px solid var(--color-border)", background: "var(--bg-subtle)" }}>
          <div style={{ display: "flex", alignItems: "center", gap: "10px", color: "var(--text-primary)", fontWeight: 700 }}>
            <Users size={18} />
            <span>إجمالي العملاء: {filteredClients.length}</span>
          </div>
        </div>

        <div style={{ overflowX: "auto" }}>
          <table style={{ width: "100%", borderCollapse: "collapse", minWidth: "900px" }}>
            <thead>
              <tr>
                <th style={thStyle}>العميل</th>
                <th style={thStyle}>البريد الإلكتروني</th>
                <th style={thStyle}>الهاتف</th>
                <th style={thStyle}>العقود</th>
                <th style={thStyle}>النشطة</th>
                <th style={{ ...thStyle, textAlign: "center" }}>الإجراءات</th>
              </tr>
            </thead>
            <tbody>
              {filteredClients.map((client) => (
                <tr key={client.id} style={{ borderBottom: "1px solid var(--color-border)" }}>
                  <td style={tdStyle}>
                    <div style={{ display: "flex", alignItems: "center", gap: "12px" }}>
                      <div style={{ width: "42px", height: "42px", borderRadius: "12px", background: "var(--green-50)", color: "var(--color-primary)", display: "flex", alignItems: "center", justifyContent: "center", fontWeight: 800 }}>
                        {client.fullName?.charAt(0)?.toUpperCase() || <Briefcase size={18} />}
                      </div>
                      <div>
                        <div style={{ fontWeight: 700, color: "var(--text-primary)" }}>{client.fullName}</div>
                        <div style={{ fontSize: "0.85rem", color: "var(--text-tertiary)" }}>{client.role}</div>
                      </div>
                    </div>
                  </td>
                  <td style={tdStyle}>
                    <div style={{ display: "flex", alignItems: "center", gap: "8px", color: "var(--text-secondary)" }}>
                      <Mail size={14} />
                      <span dir="ltr">{client.email}</span>
                    </div>
                  </td>
                  <td style={tdStyle}>
                    <div style={{ display: "flex", alignItems: "center", gap: "8px", color: "var(--text-secondary)" }}>
                      <Phone size={14} />
                      <span dir="ltr">{client.phone || "--"}</span>
                    </div>
                  </td>
                  <td style={tdStyle}>{client.contractCount}</td>
                  <td style={tdStyle}>{client.activeContractCount}</td>
                  <td style={{ ...tdStyle, textAlign: "center" }}>
                    <button
                      onClick={() => navigate(`/admin/clients/${client.id}`)}
                      className="button secondary"
                      style={{ display: "inline-flex", alignItems: "center", gap: "8px" }}
                    >
                      <Eye size={16} />
                      عرض الملف
                    </button>
                  </td>
                </tr>
              ))}
              {filteredClients.length === 0 && (
                <tr>
                  <td colSpan={6} style={{ padding: "56px", textAlign: "center", color: "var(--text-tertiary)" }}>
                    لا توجد نتائج مطابقة
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};

const thStyle: React.CSSProperties = {
  padding: "16px 24px",
  textAlign: "right",
  color: "var(--text-tertiary)",
  fontSize: "0.85rem",
  fontWeight: 700,
  whiteSpace: "nowrap",
  borderBottom: "1px solid var(--color-border)",
};

const tdStyle: React.CSSProperties = {
  padding: "18px 24px",
  color: "var(--text-primary)",
  borderBottom: "1px solid var(--color-border)",
  verticalAlign: "middle",
};