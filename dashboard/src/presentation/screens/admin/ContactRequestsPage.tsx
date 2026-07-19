import { useEffect, useMemo, useState } from "react";
import { useSearchParams } from "react-router-dom";
import {
  CalendarDays,
  CheckCircle2,
  Clock3,
  Eye,
  Filter,
  Inbox,
  Mail,
  MessageSquareMore,
  Phone,
  RefreshCw,
  Search,
  Save,
  ShieldCheck,
  Trash2,
  User,
  Users,
  X,
} from "lucide-react";
import { supabase } from "@infrastructure/supabase/client";
import { LoadingState, ErrorState } from "@presentation/components/States";
import { useToast } from "@presentation/components/ToastProvider";
import { useTour } from "@presentation/components/tour/useTour";
import { CustomSelect } from "@presentation/components/CustomSelect";
import { formatDate } from "@shared/utils/date";

type ContactRequestStatus = "new" | "contacted" | "in_progress" | "converted" | "closed";

type ContactRequest = {
  id: string;
  full_name: string;
  phone: string;
  email: string | null;
  notes: string | null;
  source: string | null;
  status: ContactRequestStatus;
  admin_notes: string | null;
  contacted_at: string | null;
  closed_at: string | null;
  created_at: string;
  updated_at: string;
};

type StatusMeta = {
  label: string;
  background: string;
  color: string;
};

const STATUS_META: Record<ContactRequestStatus, StatusMeta> = {
  new: { label: "جديد", background: "#eef3e8", color: "#30461F" },
  contacted: { label: "تم التواصل", background: "#eef6ff", color: "#1d4ed8" },
  in_progress: { label: "قيد المتابعة", background: "#fef6eb", color: "#c2410c" },
  converted: { label: "تحول لعميل", background: "#ecfdf5", color: "#047857" },
  closed: { label: "مغلق", background: "#f5f3ef", color: "#4a5349" },
};

const STATUS_OPTIONS: Array<{ value: "all" | ContactRequestStatus; label: string }> = [
  { value: "all", label: "كل الطلبات" },
  { value: "new", label: STATUS_META.new.label },
  { value: "contacted", label: STATUS_META.contacted.label },
  { value: "in_progress", label: STATUS_META.in_progress.label },
  { value: "converted", label: STATUS_META.converted.label },
  { value: "closed", label: STATUS_META.closed.label },
];

const REQUEST_STATUSES: ContactRequestStatus[] = [
  "new",
  "contacted",
  "in_progress",
  "converted",
  "closed",
];

const formatTime = (value?: string | null) => {
  if (!value) return "—";
  return new Intl.DateTimeFormat("ar", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
};

export const ContactRequestsPage = () => {
  const { notify } = useToast();
  const [params] = useSearchParams();
  const [requests, setRequests] = useState<ContactRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState<"all" | ContactRequestStatus>("all");
  const [refreshing, setRefreshing] = useState(false);
  const [selectedRequest, setSelectedRequest] = useState<ContactRequest | null>(null);
  const [savingId, setSavingId] = useState<string | null>(null);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [isMobile, setIsMobile] = useState<boolean>(() => {
    if (typeof window === "undefined") return false;
    return window.matchMedia("(max-width: 768px)").matches;
  });

  useEffect(() => {
    if (typeof window === "undefined") return;
    const mq = window.matchMedia("(max-width: 768px)");
    const handler = (e: MediaQueryListEvent) => setIsMobile(e.matches);
    if (mq.addEventListener) mq.addEventListener("change", handler);
    else mq.addListener(handler as any);
    return () => {
      if (mq.removeEventListener) mq.removeEventListener("change", handler as any);
      else mq.removeListener(handler as any);
    };
  }, []);

  const loadRequests = async () => {
    try {
      setLoading(true);
      setError(null);

      const { data, error: loadError } = await supabase
        .from("contact_requests")
        .select("*")
        .order("created_at", { ascending: false });

      if (loadError) throw loadError;

      setRequests((data ?? []) as ContactRequest[]);
    } catch (loadError) {
      console.error(loadError);
      setError("تعذر تحميل طلبات التواصل");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void loadRequests();
  }, []);

  // If opened via a notification link containing ?requestId=..., open the request details modal
  useEffect(() => {
    const requestId = params.get("requestId");
    if (!requestId || requests.length === 0) return;

    const found = requests.find((item) => item.id === requestId);
    if (found) setSelectedRequest(found);
  }, [params, requests]);

  const refreshRequests = async () => {
    setRefreshing(true);
    try {
      await loadRequests();
      notify("تم تحديث الطلبات");
    } finally {
      setRefreshing(false);
    }
  };

  const stats = useMemo(() => {
    const total = requests.length;
    const newCount = requests.filter((item) => item.status === "new").length;
    const contactedCount = requests.filter((item) => item.status === "contacted").length;
    const convertedCount = requests.filter((item) => item.status === "converted").length;

    return { total, newCount, contactedCount, convertedCount };
  }, [requests]);

  const filteredRequests = useMemo(() => {
    const query = search.trim().toLowerCase();

    return requests.filter((item) => {
      const matchesStatus = statusFilter === "all" || item.status === statusFilter;
      if (!matchesStatus) return false;

      if (!query) return true;

      return [item.full_name, item.phone, item.email ?? "", item.notes ?? "", item.source ?? ""]
        .join(" ")
        .toLowerCase()
        .includes(query);
    });
  }, [requests, search, statusFilter]);

  const updateRequest = async (
    requestId: string,
    patch: Partial<Pick<ContactRequest, "status" | "admin_notes">>,
  ) => {
    const current = requests.find((item) => item.id === requestId);
    if (!current) return;

    const nextStatus = patch.status ?? current.status;
    const now = new Date().toISOString();

    const payload: Record<string, unknown> = {
      ...patch,
      status: nextStatus,
    };

    if (patch.status) {
      if (nextStatus === "new") {
        payload.contacted_at = null;
        payload.closed_at = null;
      }

      if (nextStatus === "contacted" || nextStatus === "in_progress" || nextStatus === "converted") {
        payload.contacted_at = current.contacted_at ?? now;
        payload.closed_at = null;
      }

      if (nextStatus === "closed") {
        payload.closed_at = now;
      }
    }

    setSavingId(requestId);

    try {
      const { error: updateError } = await supabase
        .from("contact_requests")
        .update(payload)
        .eq("id", requestId);

      if (updateError) throw updateError;

      notify("تم تحديث الطلب");
      await loadRequests();
      if (selectedRequest?.id === requestId) {
        setSelectedRequest(null);
      }
    } catch (updateError) {
      console.error(updateError);
      notify("تعذر تحديث الطلب");
    } finally {
      setSavingId(null);
    }
  };

  const deleteRequest = async (requestId: string) => {
    const confirmed = window.confirm("هل تريد حذف طلب التواصل؟");
    if (!confirmed) return;

    setDeletingId(requestId);

    try {
      const { error: deleteError } = await supabase.from("contact_requests").delete().eq("id", requestId);
      if (deleteError) throw deleteError;

      notify("تم حذف الطلب");
      await loadRequests();
      setSelectedRequest(null);
    } catch (deleteError) {
      console.error(deleteError);
      notify("تعذر حذف الطلب");
    } finally {
      setDeletingId(null);
    }
  };

  useTour(
    "admin-contact-requests",
    loading || error
      ? []
      : [
          {
            target: ".contact-requests-page-header",
            title: "طلبات التواصل",
            content: "متابعة رسائل العملاء الجدد والطلبات القادمة من التطبيق، مع إمكانية تحديث القائمة.",
          },
          {
            target: ".contact-requests-page-stats",
            title: "نظرة سريعة",
            content: "إجمالي الطلبات، الجديدة منها، اللي تم التواصل معاها، واللي اتحولت لعميل فعلي.",
          },
          {
            target: '[data-tour="contact-requests-list"]',
            title: "قائمة الطلبات",
            content: "اضغط على أي طلب عشان تشوف تفاصيله وتغيّر حالته، أو احذفه لو مش محتاجه.",
          },
        ]
  );

  if (loading) return <LoadingState />;
  if (error) return <ErrorState text={error} />;

  return (
    <div
      className="contact-requests-page"
      style={{
        position: "relative",
        minHeight: isMobile ? "auto" : "calc(100vh - 140px)",
        overflow: isMobile ? "visible" : "hidden",
        display: "flex",
        flexDirection: "column",
        gap: isMobile ? 12 : 0,
      }}
    >
      <div
        className="contact-requests-page-header"
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: isMobile ? "stretch" : "center",
          marginBottom: isMobile ? "8px" : "16px",
          padding: isMobile ? "0" : "0 4px",
          flexShrink: 0,
          gap: "12px",
          flexWrap: "wrap",
          flexDirection: isMobile ? "column" : "row",
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: "12px" }}>
          <div
            style={{
              padding: "10px",
              background: "#eef3e8",
              borderRadius: "10px",
              color: "var(--primary)",
              display: "flex",
            }}
          >
            <MessageSquareMore size={24} />
          </div>
          <div>
            <h2 style={{ margin: 0, fontSize: isMobile ? "1.08rem" : "1.25rem", color: "#1a2a10" }}>إدارة طلبات التواصل</h2>
            <div style={{ marginTop: 4, color: "#7c857a", fontSize: isMobile ? "0.84rem" : "0.9rem", lineHeight: 1.45 }}>
              متابعة رسائل العملاء الجدد والطلبات القادمة من التطبيق
            </div>
          </div>
        </div>

        <div style={{ display: "flex", gap: "10px", alignItems: "center", flexWrap: "wrap", width: isMobile ? "100%" : undefined, flexDirection: isMobile ? "column" : "row" }}>
          <div style={{ position: "relative", flex: isMobile ? 1 : undefined, width: isMobile ? "100%" : undefined }}>
            <Search size={16} style={{ position: "absolute", top: 12, right: 12, color: "#b0b8ae" }} />
            <input
              className="input"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="بحث بالاسم أو الهاتف أو الملاحظات..."
              style={{ paddingRight: "36px", width: isMobile ? "100%" : "280px", borderColor: "#e4e0d8", height: 42 }}
            />
          </div>

          <button className="button" onClick={refreshRequests} type="button" disabled={refreshing} style={{ whiteSpace: "nowrap", width: isMobile ? "100%" : "auto", justifyContent: "center", height: 42 }}>
            <RefreshCw size={16} style={{ animation: refreshing ? "spin 1s linear infinite" : undefined }} />
            تحديث
          </button>
        </div>
      </div>

      <div
        className="contact-requests-page-stats"
        style={{
          display: "grid",
          gridTemplateColumns: isMobile ? "repeat(2, minmax(0, 1fr))" : "repeat(4, minmax(0, 1fr))",
          gap: isMobile ? "10px" : "12px",
          marginBottom: isMobile ? "12px" : "16px",
          flexShrink: 0,
        }}
      >
        <StatCard icon={Inbox} label="إجمالي الطلبات" value={stats.total} color="#30461F" bg="#eef3e8" />
        <StatCard icon={Clock3} label="جديد" value={stats.newCount} color="#c2410c" bg="#fef6eb" />
        <StatCard icon={ShieldCheck} label="تم التواصل" value={stats.contactedCount} color="#1d4ed8" bg="#eef6ff" />
        <StatCard icon={CheckCircle2} label="تحول لعميل" value={stats.convertedCount} color="#047857" bg="#ecfdf5" />
      </div>

      <div
        className="contact-requests-page-toolbar"
        style={{
          display: "flex",
          gap: "12px",
          alignItems: isMobile ? "stretch" : "center",
          marginBottom: isMobile ? "12px" : "16px",
          flexWrap: "wrap",
          flexShrink: 0,
          flexDirection: isMobile ? "column" : "row",
        }}
      >
        <div
          style={{
            display: "inline-flex",
            alignItems: "center",
            gap: "8px",
            padding: "8px 12px",
            borderRadius: "999px",
            background: "#f7f5f0",
            color: "#6b7280",
            fontSize: "0.85rem",
          }}
        >
          <Filter size={14} />
          فلترة بالحالة
        </div>

        <div style={{ display: "flex", gap: "8px", flexWrap: "nowrap", overflowX: isMobile ? "auto" : "visible", paddingBottom: isMobile ? 4 : 0, WebkitOverflowScrolling: "touch" }}>
          {STATUS_OPTIONS.map((option) => (
            <button
              key={option.value}
              type="button"
              onClick={() => setStatusFilter(option.value)}
              style={{
                border: "1px solid",
                borderColor: statusFilter === option.value ? "#30461F" : "#e4e0d8",
                background: statusFilter === option.value ? "#eef3e8" : "white",
                color: statusFilter === option.value ? "#30461F" : "#4a5349",
                borderRadius: "999px",
                padding: "8px 14px",
                fontSize: "0.84rem",
                fontWeight: 600,
                cursor: "pointer",
                whiteSpace: "nowrap",
                flexShrink: 0,
              }}
            >
              {option.label}
            </button>
          ))}
        </div>
      </div>

      <div data-tour="contact-requests-list" className="card" style={{ padding: 0, overflow: "hidden", flex: 1, display: "flex", flexDirection: "column", minHeight: 0, border: "1px solid #e4e0d8" }}>
          <div style={{ overflow: isMobile ? "visible" : "auto", height: "100%" }}>
          {isMobile ? (
              <div style={{ padding: 12 }}>
              {filteredRequests.length === 0 ? (
                  <div style={{ padding: 28, textAlign: "center", color: "#b0b8ae" }}>لا توجد طلبات مطابقة</div>
              ) : (
                filteredRequests.map((request) => {
                  const meta = STATUS_META[request.status];

                  return (
                    <div
                      key={request.id}
                      style={{
                        border: "1px solid #e4e0d8",
                        borderRadius: 18,
                          padding: 14,
                        background: "white",
                        boxShadow: "0 6px 18px rgba(26, 42, 16, 0.04)",
                        display: "flex",
                        flexDirection: "column",
                          gap: 12,
                        marginBottom: 12,
                      }}
                    >
                        <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", gap: 12 }}>
                        <div style={{ minWidth: 0, flex: 1 }}>
                          <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 6 }}>
                            <div style={{ width: 10, height: 10, borderRadius: "50%", background: meta.color, flexShrink: 0 }} />
                            <div style={{ fontSize: "0.78rem", fontWeight: 800, color: meta.color, background: meta.background, padding: "4px 10px", borderRadius: 999 }}>
                              {meta.label}
                            </div>
                          </div>
                          <div style={{ fontSize: "1.02rem", fontWeight: 800, color: "#1a2a10", lineHeight: 1.4 }}>
                            {request.full_name}
                          </div>
                            <div style={{ marginTop: 8, display: "grid", gridTemplateColumns: "1fr", gap: 6, color: "#5f675c", fontSize: "0.9rem" }}>
                              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                                <Phone size={14} color="#7c857a" />
                                <a href={`tel:${request.phone}`} style={{ color: "#2d3a2a", fontWeight: 700, textDecoration: "none" }}>
                                  {request.phone}
                                </a>
                              </div>
                              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                                <Users size={14} color="#7c857a" />
                                <span>{request.source || "mobile_app"}</span>
                              </div>
                              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                                <CalendarDays size={14} color="#7c857a" />
                                <span>{formatDate(request.created_at)} • {formatTime(request.created_at)}</span>
                              </div>
                          </div>
                        </div>

                          <div style={{ display: "flex", gap: 8, flexShrink: 0, alignItems: "center" }}>
                            <IconButton title="عرض التفاصيل" onClick={() => setSelectedRequest(request)}>
                              <Eye size={16} />
                            </IconButton>
                        </div>
                      </div>

                      {request.notes && (
                          <div style={{ background: "#fbf9f5", borderRadius: 14, padding: 12, color: "#2d3a2a", fontSize: "0.95rem", lineHeight: 1.6, border: "1px solid #f0ebe3" }}>
                          {request.notes}
                        </div>
                      )}

                        <div style={{ display: "flex", gap: 8 }}>
                          <button
                            type="button"
                            className="button secondary"
                            onClick={() => setSelectedRequest(request)}
                            style={{ flex: 1, justifyContent: "center" }}
                          >
                            <Eye size={16} />
                            التفاصيل
                          </button>
                          <button
                            type="button"
                            className="button"
                            onClick={() => void deleteRequest(request.id)}
                            disabled={deletingId === request.id}
                            style={{ flex: 1, justifyContent: "center", background: "#fff5f5", color: "#dc2626", border: "1px solid #fecaca" }}
                          >
                            <Trash2 size={16} />
                            حذف
                          </button>
                      </div>
                    </div>
                  );
                })
              )}
            </div>
          ) : (
            <table className="table" style={{ margin: 0, width: "100%", borderCollapse: "separate", borderSpacing: 0 }}>
              <thead style={{ position: "sticky", top: 0, zIndex: 10, background: "#FBF9F5" }}>
                <tr>
                  <Th>الاسم</Th>
                  <Th>رقم الهاتف</Th>
                  <Th>المصدر</Th>
                  <Th>الحالة</Th>
                  <Th>التاريخ</Th>
                  <Th center>الإجراءات</Th>
                </tr>
              </thead>
              <tbody>
                {filteredRequests.length === 0 ? (
                  <tr>
                    <td colSpan={6} style={{ textAlign: "center", padding: "48px", color: "#b0b8ae" }}>
                      لا توجد طلبات مطابقة
                    </td>
                  </tr>
                ) : (
                  filteredRequests.map((request) => {
                    const meta = STATUS_META[request.status];

                    return (
                      <tr key={request.id} style={{ background: "white", borderBottom: "1px solid #f5f3ef" }}>
                        <td style={{ padding: "16px", fontWeight: 700, color: "#1a2a10" }}>
                          <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
                            <div style={{ width: 8, height: 8, borderRadius: "50%", background: meta.color }} />
                            <div>
                              <div>{request.full_name}</div>
                              <div style={{ fontSize: "0.8rem", color: "#7c857a", marginTop: 2 }}>{request.email || "لا يوجد بريد"}</div>
                            </div>
                          </div>
                        </td>
                        <td style={{ padding: "16px" }}>
                          <a href={`tel:${request.phone}`} style={{ color: "#2d3a2a", fontWeight: 600, textDecoration: "none" }}>{request.phone}</a>
                        </td>
                        <td style={{ padding: "16px", color: "#2d3a2a", fontSize: "0.9rem" }}>{request.source || "mobile_app"}</td>
                        <td style={{ padding: "16px" }}>
                          <CustomSelect
                            value={request.status}
                            onChange={(value) => void updateRequest(request.id, { status: value as ContactRequestStatus })}
                            options={REQUEST_STATUSES.map((status) => ({ id: status, label: STATUS_META[status].label }))}
                            width="100%"
                            disabled={savingId === request.id}
                          />
                        </td>
                        <td style={{ padding: "16px", color: "#7c857a", fontSize: "0.85rem" }}>
                          {formatDate(request.created_at)}
                          <div style={{ marginTop: 4, fontSize: "0.78rem", opacity: 0.8 }}>{formatTime(request.created_at)}</div>
                        </td>
                        <td style={{ textAlign: "center", padding: "16px" }}>
                          <div style={{ display: "flex", gap: "8px", justifyContent: "center", flexWrap: "wrap" }}>
                            <IconButton title="عرض التفاصيل" onClick={() => setSelectedRequest(request)}>
                              <Eye size={17} />
                            </IconButton>
                            <IconButton title="حذف" onClick={() => void deleteRequest(request.id)} disabled={deletingId === request.id} danger>
                              <Trash2 size={17} />
                            </IconButton>
                          </div>
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          )}
        </div>
      </div>

      {selectedRequest && (
        <RequestDetailsModal
          request={selectedRequest}
          onClose={() => setSelectedRequest(null)}
          onSave={async (status, adminNotes) => updateRequest(selectedRequest.id, { status, admin_notes: adminNotes })}
          onDelete={async () => deleteRequest(selectedRequest.id)}
        />
      )}
    </div>
  );
};

const StatCard = ({ icon: Icon, label, value, color, bg }: { icon: typeof Inbox; label: string; value: number; color: string; bg: string }) => (
  <div className="card" style={{ padding: "16px 20px", display: "flex", alignItems: "center", gap: "14px" }}>
    <div style={{ width: 42, height: 42, borderRadius: 10, background: bg, display: "flex", alignItems: "center", justifyContent: "center" }}>
      <Icon size={22} color={color} />
    </div>
    <div>
      <div style={{ fontSize: "0.8rem", color: "#7c857a", fontWeight: 500 }}>{label}</div>
      <div style={{ fontSize: "1.15rem", fontWeight: 800, color: "#1a2a10", marginTop: 2 }}>{value}</div>
    </div>
  </div>
);

const Th = ({ children, center }: { children: string; center?: boolean }) => (
  <th
    style={{
      padding: "16px",
      color: "#7c857a",
      fontSize: "0.85rem",
      fontWeight: 600,
      borderBottom: "1px solid #e4e0d8",
      background: "#FBF9F5",
      textAlign: center ? "center" : undefined,
    }}
  >
    {children}
  </th>
);

const IconButton = ({
  children,
  title,
  onClick,
  danger = false,
  disabled = false,
}: {
  children: React.ReactNode;
  title: string;
  onClick: () => void;
  danger?: boolean;
  disabled?: boolean;
}) => (
  <button
    type="button"
    title={title}
    onClick={onClick}
    disabled={disabled}
    style={{
      width: 36,
      height: 36,
      borderRadius: 10,
      border: "1px solid #e4e0d8",
      background: danger ? "#fff5f5" : "white",
      color: danger ? "#dc2626" : "#30461F",
      display: "inline-flex",
      alignItems: "center",
      justifyContent: "center",
      cursor: disabled ? "not-allowed" : "pointer",
      opacity: disabled ? 0.6 : 1,
    }}
  >
    {children}
  </button>
);

const RequestDetailsModal = ({
  request,
  onClose,
  onSave,
  onDelete,
}: {
  request: ContactRequest;
  onClose: () => void;
  onSave: (status: ContactRequestStatus, adminNotes: string) => Promise<void>;
  onDelete: () => Promise<void>;
}) => {
  const [status, setStatus] = useState<ContactRequestStatus>(request.status);
  const [adminNotes, setAdminNotes] = useState(request.admin_notes ?? "");
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(false);

  useEffect(() => {
    setStatus(request.status);
    setAdminNotes(request.admin_notes ?? "");
  }, [request]);

  const meta = STATUS_META[status];

  const handleSave = async () => {
    setSaving(true);
    try {
      await onSave(status, adminNotes.trim());
      onClose();
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async () => {
    setDeleting(true);
    try {
      await onDelete();
      onClose();
    } finally {
      setDeleting(false);
    }
  };

  return (
    <div
      style={{
        position: "fixed",
        inset: 0,
        background: "rgba(20, 30, 20, 0.48)",
        backdropFilter: "blur(4px)",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        padding: 16,
        zIndex: 1000,
      }}
      onClick={onClose}
      role="presentation"
    >
      <div
        className="card"
        style={{ width: "min(720px, 100%)", padding: 0, overflow: "hidden" }}
        onClick={(event) => event.stopPropagation()}
        role="dialog"
        aria-modal="true"
      >
        <div style={{ padding: 20, borderBottom: "1px solid #e4e0d8", display: "flex", justifyContent: "space-between", gap: 12 }}>
          <div>
            <div style={{ fontSize: "1.05rem", fontWeight: 800, color: "#1a2a10" }}>{request.full_name}</div>
            <div style={{ marginTop: 4, color: "#7c857a", fontSize: "0.9rem" }}>{request.phone}</div>
          </div>
          <button type="button" onClick={onClose} style={{ border: 0, background: "transparent", cursor: "pointer", color: "#7c857a" }}>
            <X size={20} />
          </button>
        </div>

        <div style={{ padding: 20, display: "grid", gap: 16 }}>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(2, minmax(0, 1fr))", gap: 12 }}>
            <InfoCard icon={User} label="الاسم" value={request.full_name} />
            <InfoCard icon={Phone} label="الهاتف" value={request.phone} />
            <InfoCard icon={Mail} label="البريد" value={request.email || "لا يوجد"} />
            <InfoCard icon={CalendarDays} label="تاريخ الإضافة" value={formatDate(request.created_at)} />
          </div>

          <div>
            <label style={{ display: "block", marginBottom: 8, color: "#4a5349", fontWeight: 700 }}>الحالة</label>
            <CustomSelect
              value={status}
              onChange={(value) => setStatus(value as ContactRequestStatus)}
              options={REQUEST_STATUSES.map((item) => ({
                id: item,
                label: STATUS_META[item].label,
              }))}
              width="100%"
            />
          </div>

          <div>
            <label style={{ display: "block", marginBottom: 8, color: "#4a5349", fontWeight: 700 }}>ملاحظات العميل</label>
            <div style={{ border: "1px solid #e4e0d8", borderRadius: 12, padding: 14, background: "#fbf9f5", color: "#2d3a2a", minHeight: 88, whiteSpace: "pre-wrap" }}>
              {request.notes || "لا توجد ملاحظات"}
            </div>
          </div>

          <div>
            <label style={{ display: "block", marginBottom: 8, color: "#4a5349", fontWeight: 700 }}>ملاحظات الإدارة</label>
            <textarea
              value={adminNotes}
              onChange={(event) => setAdminNotes(event.target.value)}
              rows={5}
              placeholder="أضف ملاحظات المتابعة هنا..."
              style={{
                width: "100%",
                resize: "vertical",
                borderRadius: 12,
                padding: 14,
                border: "1px solid #e4e0d8",
                background: "white",
                color: "#1f2937",
                fontFamily: "inherit",
              }}
            />
          </div>
        </div>

        <div style={{ padding: 20, borderTop: "1px solid #e4e0d8", display: "flex", justifyContent: "space-between", gap: 12, flexWrap: "wrap" }}>
          <button
            type="button"
            onClick={() => void handleDelete()}
            disabled={deleting}
            style={{
              border: "1px solid #fecaca",
              background: "#fff5f5",
              color: "#dc2626",
              borderRadius: 12,
              padding: "11px 16px",
              fontWeight: 700,
              cursor: deleting ? "not-allowed" : "pointer",
            }}
          >
            {deleting ? "جاري الحذف..." : "حذف الطلب"}
          </button>

          <div style={{ display: "flex", gap: 10 }}>
            <button
              type="button"
              onClick={onClose}
              style={{
                border: "1px solid #e4e0d8",
                background: "white",
                color: "#4a5349",
                borderRadius: 12,
                padding: "11px 16px",
                fontWeight: 700,
                cursor: "pointer",
              }}
            >
              إلغاء
            </button>

            <button
              type="button"
              onClick={() => void handleSave()}
              disabled={saving}
              style={{
                border: "1px solid #30461F",
                background: "#30461F",
                color: "white",
                borderRadius: 12,
                padding: "11px 16px",
                fontWeight: 700,
                cursor: saving ? "not-allowed" : "pointer",
                display: "inline-flex",
                alignItems: "center",
                gap: 8,
              }}
            >
              <Save size={16} />
              {saving ? "جاري الحفظ..." : "حفظ التعديلات"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

const InfoCard = ({ icon: Icon, label, value }: { icon: typeof User; label: string; value: string }) => (
  <div style={{ border: "1px solid #e4e0d8", borderRadius: 12, padding: 14, background: "#fbf9f5", display: "flex", gap: 10, alignItems: "flex-start" }}>
    <div style={{ color: "#30461F", marginTop: 2 }}>
      <Icon size={18} />
    </div>
    <div>
      <div style={{ fontSize: "0.78rem", color: "#7c857a", fontWeight: 600 }}>{label}</div>
      <div style={{ marginTop: 4, color: "#1a2a10", fontWeight: 700 }}>{value}</div>
    </div>
  </div>
);