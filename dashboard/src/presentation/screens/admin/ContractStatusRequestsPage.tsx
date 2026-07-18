import { useEffect, useMemo, useState } from "react";
import { Activity, AlertCircle, CheckCircle2, Clock3, Filter, RefreshCw, Search, ShieldCheck, XCircle } from "lucide-react";
import { supabase } from "@infrastructure/supabase/client";
import { LoadingState, ErrorState } from "@presentation/components/States";
import { useToast } from "@presentation/components/ToastProvider";

type RequestStatus = "pending" | "approved" | "rejected";

type ContractRecord = {
  code: string;
  status: string;
  block_number: string | null;
  street: string | null;
  avenue: string | null;
  house: string | null;
  address_details: string | null;
  zones?: { name: string; geographic_lines?: { name: string } | null } | null;
};

type ContractStatusRequest = {
  id: string;
  contract_id: string;
  supervisor_id: string;
  current_status: string;
  requested_status: string;
  status: RequestStatus;
  admin_notes: string | null;
  reviewed_at: string | null;
  created_at: string;
  updated_at: string;
  contracts?: ContractRecord | null;
  users?: { full_name: string | null; phone: string | null } | null;
};

const STATUS_META: Record<RequestStatus, { label: string; color: string; bg: string }> = {
  pending: { label: "بانتظار المراجعة", color: "#92400e", bg: "#fef3c7" },
  approved: { label: "معتمد", color: "#166534", bg: "#dcfce7" },
  rejected: { label: "مرفوض", color: "#991b1b", bg: "#fee2e2" },
};

const CONTRACT_STATUS_LABELS: Record<string, string> = {
  active: "نشط",
  pending: "قيد الانتظار",
  expired: "منتهي",
  cancelled: "ملغي",
  terminated: "ملغي",
};

const REQUEST_STATUS_OPTIONS: Array<{ value: "all" | RequestStatus; label: string }> = [
  { value: "all", label: "كل الطلبات" },
  { value: "pending", label: STATUS_META.pending.label },
  { value: "approved", label: STATUS_META.approved.label },
  { value: "rejected", label: STATUS_META.rejected.label },
];

const STATUS_OPTIONS: Array<{ value: "all" | string; label: string }> = [
  { value: "all", label: "كل الحالات" },
  { value: "active", label: "نشط" },
  { value: "pending", label: "قيد الانتظار" },
  { value: "expired", label: "منتهي" },
  { value: "cancelled", label: "ملغي" },
  { value: "terminated", label: "ملغي" },
];

const formatTime = (value?: string | null) => {
  if (!value) return "—";
  return new Intl.DateTimeFormat("ar", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
};

const statusLabel = (status?: string | null) => CONTRACT_STATUS_LABELS[status ?? ""] || (status ?? "—");

const buildAddress = (contract: ContractRecord | null | undefined): string => {
  if (!contract) return "—";
  const parts: string[] = [];
  const line = contract.zones?.geographic_lines?.name;
  const zone = contract.zones?.name;
  if (line) parts.push(`خط ${line}`);
  if (zone) parts.push(`منطقة ${zone}`);
  if (contract.block_number) parts.push(`ق ${contract.block_number}`);
  if (contract.street) parts.push(`ش ${contract.street}`);
  if (contract.avenue) parts.push(`ج ${contract.avenue}`);
  if (contract.house) parts.push(`م ${contract.house}`);
  if (contract.address_details) parts.push(contract.address_details);
  return parts.length ? parts.join(" – ") : "—";
};

export const ContractStatusRequestsPage = () => {
  const { notify } = useToast();
  const [requests, setRequests] = useState<ContractStatusRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [requestStatusFilter, setRequestStatusFilter] = useState<"all" | RequestStatus>("all");
  const [contractStatusFilter, setContractStatusFilter] = useState<"all" | string>("all");
  const [refreshing, setRefreshing] = useState(false);
  const [reviewingId, setReviewingId] = useState<string | null>(null);

  const normalizeRequest = (request: any): ContractStatusRequest => ({
    ...request,
    contracts: Array.isArray(request.contracts) ? request.contracts[0] ?? null : request.contracts ?? null,
    users: Array.isArray(request.users) ? request.users[0] ?? null : request.users ?? null,
  });

  const loadRequests = async ({ silent = false }: { silent?: boolean } = {}) => {
    let loadFailed = false;

    try {
      if (!silent) {
        setLoading(true);
      }

      setError(null);

      const { data, error: loadError } = await supabase
        .from("contract_status_requests")
        .select(`
          id,
          contract_id,
          supervisor_id,
          current_status,
          requested_status,
          status,
          admin_notes,
          reviewed_at,
          created_at,
          updated_at,
          contracts:contracts!contract_id(code, status, block_number, street, avenue, house, address_details, zones(name, geographic_lines(name))),
          users:users!supervisor_id(full_name, phone)
        `)
        .order("created_at", { ascending: false });

      if (loadError) throw loadError;

      setRequests((data ?? []).map(normalizeRequest));
    } catch (loadError) {
      console.error(loadError);
      loadFailed = true;

      if (silent) {
        notify("تعذر تحديث الطلبات");
      } else {
        setError("تعذر تحميل طلبات تغيير حالة العقود");
      }
    } finally {
      if (!silent) {
        setLoading(false);
      }
    }

    return !loadFailed;
  };

  useEffect(() => {
    void loadRequests();
  }, []);

  const refreshRequests = async () => {
    setRefreshing(true);
    try {
      const success = await loadRequests({ silent: true });
      if (success) {
        notify("تم تحديث البيانات");
      }
    } finally {
      setRefreshing(false);
    }
  };

  const reviewRequest = async (requestId: string, decision: "approved" | "rejected") => {
    setReviewingId(requestId);
    try {
      const { error: reviewError } = await supabase.rpc("review_contract_status_request", {
        p_request_id: requestId,
        p_decision: decision,
        p_admin_notes: null,
      });

      if (reviewError) throw reviewError;

      notify(decision === "approved" ? "تمت الموافقة على الطلب" : "تم رفض الطلب");
      await loadRequests({ silent: true });
    } catch (reviewError) {
      console.error(reviewError);
      notify("تعذر تحديث حالة الطلب");
    } finally {
      setReviewingId(null);
    }
  };

  const filteredRequests = useMemo(() => {
    const query = search.trim().toLowerCase();

    return requests.filter((request) => {
      const matchesRequestStatus =
        requestStatusFilter === "all" || request.status === requestStatusFilter;
      const requestContractStatus = request.contracts?.status ?? request.current_status;
      const matchesContractStatus =
        contractStatusFilter === "all" || requestContractStatus === contractStatusFilter;

      if (!matchesRequestStatus || !matchesContractStatus) return false;
      if (!query) return true;

      return [
        request.contracts?.code ?? "",
        request.users?.full_name ?? "",
        request.users?.phone ?? "",
        request.requested_status,
        request.current_status,
        request.admin_notes ?? "",
        buildAddress(request.contracts),
        request.contracts?.zones?.name ?? "",
        request.contracts?.zones?.geographic_lines?.name ?? "",
      ]
        .join(" ")
        .toLowerCase()
        .includes(query);
    });
  }, [contractStatusFilter, requestStatusFilter, requests, search]);

  const stats = useMemo(() => {
    const pending = requests.filter((request) => request.status === "pending").length;
    const approved = requests.filter((request) => request.status === "approved").length;
    const rejected = requests.filter((request) => request.status === "rejected").length;

    return { total: requests.length, pending, approved, rejected };
  }, [requests]);

  const pageSummaryCards = [
    {
      label: "إجمالي الطلبات",
      value: stats.total,
      hint: "كل الطلبات المسجلة",
      icon: Activity,
      tone: "primary",
    },
    {
      label: "طلبات معلقة",
      value: stats.pending,
      hint: "تحتاج قراراً الآن",
      icon: Clock3,
      tone: "accent",
    },
    {
      label: "طلبات معتمدة",
      value: stats.approved,
      hint: "تمت معالجتها بنجاح",
      icon: CheckCircle2,
      tone: "success",
    },
    {
      label: "طلبات مرفوضة",
      value: stats.rejected,
      hint: "تم استبعادها بعد المراجعة",
      icon: AlertCircle,
      tone: "primary",
    },
  ];

  if (loading) return <LoadingState />;
  if (error) return <ErrorState text={error} />;

  return (
    <div className="admin-dashboard contract-status-requests-page">
      <section className="dashboard-hero">
        <div className="dashboard-hero-content">
          <div className="dashboard-hero-title">طلبات تغيير حالة العقود</div>
          <div className="dashboard-hero-subtitle">
            صفحة بسيطة وواضحة لمراجعة طلبات المشرفين والموافقة عليها أو رفضها من مكان واحد.
          </div>
        </div>

        <div className="dashboard-hero-actions">
          <button type="button" className="button secondary" onClick={refreshRequests} disabled={refreshing}>
            <RefreshCw size={16} />
            {refreshing ? "جاري التحديث..." : "تحديث البيانات"}
          </button>
        </div>
      </section>

      <section className="dashboard-kpi-grid">
        {pageSummaryCards.map((card) => {
          const Icon = card.icon;

          return (
            <article key={card.label} className="dashboard-kpi-card">
              <div className="dashboard-kpi-head">
                <div>
                  <div className="dashboard-kpi-title">{card.label}</div>
                  <div className="dashboard-kpi-value">{card.value}</div>
                </div>
                <span className={`kpi-icon ${card.tone}`}>
                  <Icon size={18} />
                </span>
              </div>
              <div className="dashboard-kpi-sub">{card.hint}</div>
            </article>
          );
        })}
      </section>

      <section className="dashboard-panel">
        <div className="dashboard-panel-header">
          <h3 className="dashboard-panel-title">
            <Filter size={17} />
            أدوات التصفية
          </h3>
          <span className="muted">{filteredRequests.length} نتيجة من {stats.total}</span>
        </div>

        <div className="dashboard-searchbar requests-filter-bar">
          <div className="search-box">
            <Search size={16} />
            <input
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="ابحث برقم العقد أو اسم المشرف أو الهاتف"
            />
          </div>

          <div className="requests-filter-controls">
            <select
              className="select"
              value={requestStatusFilter}
              onChange={(event) => setRequestStatusFilter(event.target.value as "all" | RequestStatus)}
            >
              {REQUEST_STATUS_OPTIONS.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>

            <select
              className="select"
              value={contractStatusFilter}
              onChange={(event) => setContractStatusFilter(event.target.value as "all" | string)}
            >
              {STATUS_OPTIONS.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>

            <button type="button" className="button secondary requests-filter-refresh" onClick={refreshRequests} disabled={refreshing}>
              <RefreshCw size={16} />
              {refreshing ? "جاري التحديث..." : "تحديث البيانات"}
            </button>
          </div>
        </div>
      </section>

      <section className="dashboard-panel">
        <div className="dashboard-panel-header">
          <h3 className="dashboard-panel-title">قائمة الطلبات</h3>
          <span className="muted">{filteredRequests.length} طلب ظاهر</span>
        </div>

        <div className="dashboard-table-wrap">
          <table className="dashboard-table">
            <thead>
              <tr>
                <th>العقد</th>
                <th>المشرف</th>
                <th>الحالة الحالية</th>
                <th>الحالة المطلوبة</th>
                <th>حالة الطلب</th>
                <th>التاريخ</th>
                <th>الإجراء</th>
              </tr>
            </thead>
            <tbody>
              {filteredRequests.map((request) => {
                const contractCode = request.contracts?.code || request.contract_id;
                const supervisorName = request.users?.full_name || "—";
                const contractStatus = request.contracts?.status ?? request.current_status;
                const isPending = request.status === "pending";

                return (
                  <tr key={request.id}>
                    <td>
                      <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
                        <span style={{ fontFamily: "monospace" }}>{contractCode}</span>
                        <span className="muted" style={{ fontSize: "0.8em" }}>{buildAddress(request.contracts)}</span>
                        {request.contracts?.status && (
                          <span className="muted" style={{ fontSize: "0.75em" }}>حالة العقد: {statusLabel(contractStatus)}</span>
                        )}
                      </div>
                    </td>
                    <td>
                      <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
                        <span>{supervisorName}</span>
                        {request.users?.phone && <span className="muted">{request.users.phone}</span>}
                      </div>
                    </td>
                    <td>{statusLabel(contractStatus)}</td>
                    <td>{statusLabel(request.requested_status)}</td>
                    <td>
                      <span
                        className={`badge ${request.status === "pending" ? "badge-warning" : request.status === "approved" ? "badge-success" : "badge-danger"}`}
                        style={{ background: STATUS_META[request.status].bg, color: STATUS_META[request.status].color }}
                      >
                        {STATUS_META[request.status].label}
                      </span>
                    </td>
                    <td>
                      <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
                        <span>{formatTime(request.created_at)}</span>
                        {request.reviewed_at && <span className="muted">تمت المراجعة: {formatTime(request.reviewed_at)}</span>}
                      </div>
                    </td>
                    <td>
                      <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
                        {isPending ? (
                          <>
                            <button
                              type="button"
                              className="button"
                              onClick={() => reviewRequest(request.id, "approved")}
                              disabled={reviewingId === request.id}
                            >
                              <CheckCircle2 size={16} />
                              موافقة
                            </button>
                            <button
                              type="button"
                              className="button secondary"
                              onClick={() => reviewRequest(request.id, "rejected")}
                              disabled={reviewingId === request.id}
                            >
                              <XCircle size={16} />
                              رفض
                            </button>
                          </>
                        ) : (
                          <span className="muted">تمت المراجعة</span>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })}

              {filteredRequests.length === 0 && (
                <tr>
                  <td colSpan={7} className="dashboard-empty">
                    <div style={{ display: "flex", flexDirection: "column", gap: 6, alignItems: "center" }}>
                      <ShieldCheck size={22} />
                      <span>لا توجد طلبات مطابقة</span>
                    </div>
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
};
