import { useCallback, useEffect, useMemo, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { Calendar, ClipboardList, MessageSquare, ArrowRight, User as UserIcon } from "lucide-react";
import { container } from "@infrastructure/di/container";
import { supabase } from "@infrastructure/supabase/client";
import { resolveNotificationTarget, type NotificationRecord } from "@presentation/notifications/notificationRouting";
import { syncWorkerVisaNotifications } from "@presentation/notifications/syncWorkerVisaNotifications";
import { syncContractExpiryNotifications } from "@presentation/notifications/syncContractExpiryNotifications";
import { getVisitStatusStyle } from "@shared/visitStatus";
import { formatDate, formatDateTime } from "@shared/utils/date";
import type { Contract } from "@domain/entities/Contract";
import type { Visit } from "@domain/entities/Visit";
import type { ContractTask } from "@domain/entities/ContractTask";
import { useTour } from "@presentation/components/tour/useTour";

const getNotificationTypeLabel = (type: string) => {
  switch (type) {
    case "client_comment":
      return "تعليق عميل";
    case "visit_completed":
      return "إنهاء زيارة";
    case "supervisor_note":
      return "ملاحظة مشرف";
    case "contract_expiring_30":
      return "انتهاء عقد - 30 يوم";
    case "contract_expiring_15":
      return "انتهاء عقد - 15 يوم";
    case "contract_expired":
      return "عقد منتهي";
    case "worker_visa_expiring":
      return "تأشيرة عامل قريبة من الانتهاء";
    case "worker_visa_expired":
      return "تأشيرة عامل منتهية";
    default:
      return type || "إشعار";
  }
};

const formatNotificationTime = (value?: string) => {
  if (!value) return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  return formatDateTime(date);
};

const getNotificationMetaType = (notification: NotificationRecord) => {
  const meta = notification.meta;
  if (!meta || typeof meta !== "object") return "";
  const record = meta as Record<string, any>;
  const type = record.type;
  return typeof type === "string" ? type : "";
};

type DashboardNotification = NotificationRecord & {
  created_at: string;
  read?: boolean | null;
};

export const VisitNotificationPage = () => {
  const navigate = useNavigate();
  const [params] = useSearchParams();

  const contractId = params.get("contractId") || "";
  const visitId = params.get("visitId") || "";
  const commentId = params.get("commentId") || "";
  const noteId = params.get("noteId") || "";
  const notificationType = params.get("type") || "";

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [contract, setContract] = useState<Contract | null>(null);
  const [visit, setVisit] = useState<Visit | null>(null);
  const [tasks, setTasks] = useState<ContractTask[]>([]);
  const [comments, setComments] = useState<any[]>([]);
  const [supervisorNotes, setSupervisorNotes] = useState<any[]>([]);
  const [notifications, setNotifications] = useState<DashboardNotification[]>([]);
  const [notificationsLoading, setNotificationsLoading] = useState(true);
  const [notificationsError, setNotificationsError] = useState<string | null>(null);
  const hasDetailContext = Boolean(contractId && visitId);

  const loadNotifications = useCallback(async () => {
    setNotificationsLoading(true);
    setNotificationsError(null);

    try {
      await Promise.all([syncWorkerVisaNotifications(), syncContractExpiryNotifications()]);

      const { data, error: fetchError } = await supabase
        .from("notifications")
        .select("id, title, body, created_at, read, meta")
        .order("created_at", { ascending: false })
        .limit(100);

      if (fetchError) throw fetchError;

      setNotifications((data as DashboardNotification[]) || []);
    } catch (loadError) {
      console.error("Error loading notifications:", loadError);
      setNotificationsError("تعذر تحميل الإشعارات");
    } finally {
      setNotificationsLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadNotifications();
  }, [loadNotifications]);

  useEffect(() => {
    let cancelled = false;

    const load = async () => {
      if (!contractId || !visitId) {
        setLoading(false);
        setError(null);
        setContract(null);
        setVisit(null);
        setTasks([]);
        setComments([]);
        setSupervisorNotes([]);
        return;
      }

      setLoading(true);
      setError(null);

      try {
        const contracts = await container.adminRepository.listContracts();
        if (cancelled) return;

        const targetContract = contracts.find((item) => item.id === contractId) || null;
        if (!targetContract) {
          setError("العقد غير موجود");
          setLoading(false);
          return;
        }

        const visits = await container.adminRepository.listVisits(contractId);
        if (cancelled) return;

        const targetVisit = visits.find((item) => item.id === visitId) || null;
        if (!targetVisit) {
          setError("الزيارة غير موجودة");
          setLoading(false);
          return;
        }

        const [visitTasks, visitComments, visitSupervisorNotes] = await Promise.all([
          container.adminRepository.listVisitTasks(visitId),
          container.adminRepository.listContractComments(contractId, visitId),
          container.supervisorRepository.listSupervisorNotes(visitId),
        ]);
        if (cancelled) return;

        setContract(targetContract);
        setVisit(targetVisit);
        setTasks(visitTasks || []);
        setComments(visitComments || []);
        setSupervisorNotes(visitSupervisorNotes || []);
      } catch {
        if (!cancelled) setError("تعذر تحميل تفاصيل الإشعار");
      } finally {
        if (!cancelled) setLoading(false);
      }
    };

    void load();

    return () => {
      cancelled = true;
    };
  }, [contractId, visitId]);

  useEffect(() => {
    if (!contractId || !visitId) return;

    const timers: number[] = [];

    if (commentId) {
      const t = window.setTimeout(() => {
        const node = document.getElementById(`notification-comment-${commentId}`);
        if (node) node.scrollIntoView({ behavior: "smooth", block: "center" });
      }, 120);
      timers.push(t);
    }

    if (noteId) {
      const t2 = window.setTimeout(() => {
        const node = document.getElementById(`notification-note-${noteId}`);
        if (node) node.scrollIntoView({ behavior: "smooth", block: "center" });
      }, 120);
      timers.push(t2);
    }

    return () => timers.forEach((id) => window.clearTimeout(id as unknown as number));
  }, [commentId, comments.length, contractId, noteId, supervisorNotes.length, visitId]);

  const visitStatus = useMemo(() => getVisitStatusStyle(visit?.status), [visit?.status]);
  const pageTitle = useMemo(() => {
    if (notificationType === "client_comment") return "تعليق عميل";
    if (notificationType === "visit_completed") return "إنهاء زيارة";
    if (notificationType === "supervisor_note") return "ملاحظة مشرف";
    return "مركز الإشعارات";
  }, [notificationType]);

  useTour(
    "admin-visit-notifications",
    notificationsLoading
      ? []
      : [
          {
            target: '[data-tour="notifications-list"]',
            title: "مركز الإشعارات",
            content: "كل إشعارات النظام في مكان واحد — تعليقات العملاء، إنهاء الزيارات، ملاحظات المشرفين، وتنبيهات انتهاء العقود والتأشيرات. اضغط على أي إشعار عشان تشوف تفاصيله.",
          },
        ]
  );

  return (
    <div style={{ padding: 24, display: "flex", flexDirection: "column", gap: 16 }}>
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <button
          type="button"
          className="button secondary"
          onClick={() => navigate("/admin/contracts")}
          style={{ display: "inline-flex", alignItems: "center", gap: 8 }}
        >
          <ArrowRight size={16} />
          العودة للعقود
        </button>

        <div style={{ fontWeight: 700, color: "var(--text-primary)" }}>{pageTitle}</div>
      </div>

      <div className="dashboard-panel" data-tour="notifications-list" style={{ padding: 16 }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: 12, marginBottom: 12 }}>
          <div>
            <div style={{ fontSize: "1rem", fontWeight: 700, color: "var(--text-primary)" }}>
              كل الإشعارات ({notifications.length})
            </div>
            <div style={{ fontSize: "0.85rem", color: "var(--text-secondary)", marginTop: 4 }}>
              {notifications.length > 0 ? `${notifications.filter((item) => !item.read).length} إشعارات غير مقروءة` : "لا توجد إشعارات حتى الآن"}
            </div>
          </div>

          <button
            type="button"
            className="button secondary"
            onClick={() => void loadNotifications()}
            style={{ whiteSpace: "nowrap" }}
          >
            تحديث
          </button>
        </div>

        {notificationsError ? (
          <div style={{ padding: 12, borderRadius: 10, background: "#fef2f2", color: "#b91c1c", marginBottom: 12 }}>
            {notificationsError}
          </div>
        ) : null}

        {notificationsLoading ? (
          <div style={{ padding: 24, textAlign: "center", color: "var(--text-tertiary)" }}>
            جارٍ تحميل الإشعارات...
          </div>
        ) : notifications.length === 0 ? (
          <div style={{ padding: 24, textAlign: "center", color: "var(--text-tertiary)" }}>
            لا توجد إشعارات حالياً.
          </div>
        ) : (
          <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
            {notifications.map((notification) => {
              const metaType = getNotificationMetaType(notification);
              const isUnread = !notification.read;

              return (
                <button
                  key={notification.id}
                  type="button"
                  onClick={() => navigate(resolveNotificationTarget(notification))}
                  style={{
                    width: "100%",
                    textAlign: "right",
                    padding: 14,
                    borderRadius: 12,
                    border: `1px solid ${isUnread ? "#f59e0b" : "var(--color-border)"}`,
                    background: isUnread ? "#fffaf0" : "var(--bg-card)",
                    cursor: "pointer",
                    display: "flex",
                    flexDirection: "column",
                    gap: 8,
                  }}
                >
                  <div style={{ display: "flex", alignItems: "center", gap: 8, justifyContent: "space-between" }}>
                    <div style={{ display: "flex", alignItems: "center", gap: 8, minWidth: 0 }}>
                      <div style={{ fontWeight: 700, color: "var(--text-primary)", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                        {notification.title || getNotificationTypeLabel(metaType)}
                      </div>
                      {isUnread ? (
                        <span style={{ width: 8, height: 8, borderRadius: 999, background: "#f59e0b", flexShrink: 0 }} />
                      ) : null}
                    </div>
                    <span
                      style={{
                        fontSize: "0.72rem",
                        padding: "3px 8px",
                        borderRadius: 999,
                        background: "var(--neutral-100)",
                        color: "var(--text-secondary)",
                        flexShrink: 0,
                      }}
                    >
                      {getNotificationTypeLabel(metaType)}
                    </span>
                  </div>

                  {notification.body ? (
                    <div style={{ color: "var(--text-secondary)", lineHeight: 1.6, whiteSpace: "pre-wrap" }}>
                      {notification.body}
                    </div>
                  ) : null}

                  <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 12, fontSize: "0.78rem", color: "var(--text-tertiary)" }}>
                    <span>{formatNotificationTime((notification as any).created_at)}</span>
                    <span style={{ color: "var(--color-primary)", fontWeight: 600 }}>عرض التفاصيل</span>
                  </div>
                </button>
              );
            })}
          </div>
        )}
      </div>

      {hasDetailContext ? (
        loading ? (
          <div className="dashboard-panel" style={{ padding: 16, color: "var(--text-secondary)" }}>
            جارٍ تحميل تفاصيل الإشعار...
          </div>
        ) : error ? (
          <div className="dashboard-panel" style={{ padding: 16 }}>
            <div style={{ fontWeight: 700, marginBottom: 6, color: "#b91c1c" }}>تعذر تحميل التفاصيل</div>
            <div style={{ color: "#b91c1c", lineHeight: 1.6 }}>{error}</div>
          </div>
        ) : contract && visit ? (
          <>
            <div className="dashboard-panel" style={{ padding: 16 }}>
              <div style={{ display: "flex", flexWrap: "wrap", gap: 12, alignItems: "center" }}>
                <span style={{ fontWeight: 700 }}>العقد: {contract.code}</span>
                <span
                  style={{
                    padding: "4px 10px",
                    borderRadius: 12,
                    background: visitStatus.bg,
                    color: visitStatus.color,
                    fontSize: "0.78rem",
                    fontWeight: 700,
                  }}
                >
                  {visitStatus.label}
                </span>
                <span style={{ display: "inline-flex", alignItems: "center", gap: 6, color: "var(--text-secondary)" }}>
                  <Calendar size={14} />
                  {formatDate(visit.visitDate)}
                </span>
              </div>

              {visit.notes ? (
                <div style={{ marginTop: 10, color: "var(--text-secondary)" }}>عنوان الزيارة: {visit.notes}</div>
              ) : null}

              {visit.completedAt ? (
                <div style={{ marginTop: 8, color: "var(--text-secondary)", fontSize: "0.88rem" }}>
                  تم الإنهاء: {formatDateTime(visit.completedAt)}
                </div>
              ) : null}

              {visit.summary ? (
                <div
                  style={{
                    marginTop: 12,
                    padding: 12,
                    borderRadius: 10,
                    border: "1px solid #bbf7d0",
                    background: "#f0fdf4",
                    color: "#14532d",
                    whiteSpace: "pre-wrap",
                  }}
                >
                  <strong>ملخص الزيارة:</strong>
                  <div style={{ marginTop: 6 }}>{visit.summary}</div>
                </div>
              ) : null}
            </div>

            <div className="dashboard-panel" style={{ padding: 16 }}>
              <h3 style={{ margin: "0 0 12px", fontSize: "1rem", display: "flex", alignItems: "center", gap: 8 }}>
                <ClipboardList size={16} />
                مهام الزيارة ({tasks.length})
              </h3>

              {tasks.length === 0 ? (
                <div style={{ color: "var(--text-tertiary)" }}>لا توجد مهام مرتبطة بهذه الزيارة.</div>
              ) : (
                <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                  {tasks.map((task) => (
                    <div key={task.id} style={{ border: "1px solid var(--color-border)", borderRadius: 10, padding: 10 }}>
                      <div style={{ fontWeight: 600 }}>{task.title}</div>
                      <div style={{ fontSize: "0.8rem", color: "var(--text-secondary)" }}>الحالة: {task.status}</div>
                    </div>
                  ))}
                </div>
              )}
            </div>

            <div className="dashboard-panel" style={{ padding: 16 }}>
              <h3 style={{ margin: "0 0 12px", fontSize: "1rem", display: "flex", alignItems: "center", gap: 8 }}>
                <MessageSquare size={16} />
                تعليقات العميل ({comments.length})
              </h3>

              {comments.length === 0 ? (
                <div style={{ color: "var(--text-tertiary)" }}>لا توجد تعليقات على هذه الزيارة.</div>
              ) : (
                <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
                  {comments.map((comment) => {
                    const highlighted = commentId && comment.id === commentId;
                    return (
                      <div
                        key={comment.id}
                        id={`notification-comment-${comment.id}`}
                        style={{
                          border: highlighted ? "1px solid #fb923c" : "1px solid var(--color-border)",
                          boxShadow: highlighted ? "0 0 0 2px rgba(251, 146, 60, 0.2)" : "none",
                          background: highlighted ? "#fff7ed" : "var(--bg-card)",
                          borderRadius: 10,
                          padding: 12,
                          scrollMarginTop: 120,
                        }}
                      >
                        <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 6 }}>
                          <UserIcon size={14} />
                          <span style={{ fontSize: "0.82rem", fontWeight: 700 }}>{comment.authorName || "العميل"}</span>
                          <span style={{ fontSize: "0.75rem", color: "var(--text-tertiary)" }}>
                            {formatDateTime(comment.createdAt)}
                          </span>
                        </div>
                        <div style={{ whiteSpace: "pre-wrap", color: "var(--text-primary)" }}>{comment.comment}</div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>

            <div className="dashboard-panel" style={{ padding: 16 }}>
              <h3 style={{ margin: "0 0 12px", fontSize: "1rem", display: "flex", alignItems: "center", gap: 8 }}>
                <MessageSquare size={16} />
                ملاحظات المشرف ({supervisorNotes.length})
              </h3>

              {supervisorNotes.length === 0 ? (
                <div style={{ color: "var(--text-tertiary)" }}>لا توجد ملاحظات من المشرف لهذه الزيارة.</div>
              ) : (
                <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
                  {supervisorNotes.map((note) => {
                    const highlighted = noteId && note.id === noteId;
                    return (
                      <div
                        key={note.id}
                        id={`notification-note-${note.id}`}
                        style={{
                          border: highlighted ? "1px solid #fb923c" : "1px solid var(--color-border)",
                          boxShadow: highlighted ? "0 0 0 2px rgba(251, 146, 60, 0.2)" : "none",
                          background: highlighted ? "#fff7ed" : "var(--bg-card)",
                          borderRadius: 10,
                          padding: 12,
                          scrollMarginTop: 120,
                        }}
                      >
                        <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 6 }}>
                          <UserIcon size={14} />
                          <span style={{ fontSize: "0.82rem", fontWeight: 700 }}>{note.createdBy || "المشرف"}</span>
                          <span style={{ fontSize: "0.75rem", color: "var(--text-tertiary)" }}>
                            {formatDateTime(note.createdAt)}
                          </span>
                          <span style={{ marginLeft: "auto", fontSize: "0.75rem" }}>
                            {note.visibility === "all" ? "👥 العملاء" : "🔒 المشرفين"}
                          </span>
                        </div>
                        <div style={{ whiteSpace: "pre-wrap", color: "var(--text-primary)" }}>{note.content}</div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          </>
        ) : (
          <div className="dashboard-panel" style={{ padding: 16 }}>
            <div style={{ fontWeight: 700, marginBottom: 6, color: "var(--text-primary)" }}>البيانات غير متاحة</div>
            <div style={{ color: "var(--text-secondary)", lineHeight: 1.6 }}>
              لم نتمكن من تحميل تفاصيل العقد أو الزيارة المرتبطة بهذا الإشعار.
            </div>
          </div>
        )
      ) : (
        <div className="dashboard-panel" style={{ padding: 16 }}>
          <div style={{ fontWeight: 700, marginBottom: 6, color: "var(--text-primary)" }}>تفاصيل الإشعار</div>
          <div style={{ color: "var(--text-secondary)", lineHeight: 1.6 }}>
            اختر إشعارًا من القائمة بالأعلى لعرض تفاصيل العقد أو الزيارة المرتبطة به هنا.
          </div>
        </div>
      )}
    </div>
  );
};
