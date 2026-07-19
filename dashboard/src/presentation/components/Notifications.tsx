import { useCallback, useEffect, useLayoutEffect, useRef, useState } from "react";
import { Bell, BellRing, Clock3 } from "lucide-react";
import { useNavigate } from "react-router-dom";
import { supabase } from "@infrastructure/supabase/client";
import { resolveNotificationTarget } from "@presentation/notifications/notificationRouting";
import { syncWorkerVisaNotifications } from "@presentation/notifications/syncWorkerVisaNotifications";
import { syncContractExpiryNotifications } from "@presentation/notifications/syncContractExpiryNotifications";

const formatRelativeTime = (value: string) => {
  const date = new Date(value);
  const diff = Date.now() - date.getTime();
  const minutes = Math.floor(diff / 60000);
  const hours = Math.floor(diff / 3600000);
  const days = Math.floor(diff / 86400000);

  if (Number.isNaN(date.getTime())) return "";
  if (minutes < 1) return "الآن";
  if (minutes < 60) return `منذ ${minutes} د`;
  if (hours < 24) return `منذ ${hours} س`;
  if (days < 7) return `منذ ${days} ي`;
  return date.toLocaleDateString("ar-EG");
};

const NOTIFICATIONS_PAGE_SIZE = 8;

export const Notifications = () => {
  const [open, setOpen] = useState(false);
  const [notifications, setNotifications] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(true);
  const [dropdownAlign, setDropdownAlign] = useState<"start" | "end">("end");
  const ref = useRef<HTMLDivElement | null>(null);
  const limitRef = useRef(NOTIFICATIONS_PAGE_SIZE);
  const currentUserIdRef = useRef<string | null>(null);
  const navigate = useNavigate();

  useEffect(() => {
    const handleOutside = (event: MouseEvent) => {
      if (ref.current && !ref.current.contains(event.target as Node)) {
        setOpen(false);
      }
    };

    document.addEventListener("mousedown", handleOutside);
    return () => document.removeEventListener("mousedown", handleOutside);
  }, []);

  useLayoutEffect(() => {
    if (!open || !ref.current) return;

    const rect = ref.current.getBoundingClientRect();
    const dropdownWidth = 380;
    const viewportPadding = 12;
    const expectedLeft = rect.right - dropdownWidth;
    const expectedRight = rect.left + dropdownWidth;
    const shouldOpenToStart = expectedLeft < viewportPadding && expectedRight <= window.innerWidth - viewportPadding;

    setDropdownAlign(shouldOpenToStart ? "start" : "end");
  }, [open, notifications.length]);

  const loadNotifications = useCallback(async (limit?: number) => {
    try {
      await syncWorkerVisaNotifications();

      const effectiveLimit = limit ?? limitRef.current;
      const currentUserId = currentUserIdRef.current;

      let query = supabase
        .from("notifications")
        .select("id, title, body, created_at, read, meta")
        .order("created_at", { ascending: false })
        .limit(effectiveLimit);

      // Scope to the current admin's own notifications (plus any "global"
      // rows with no user_id) — without this, the feed shows every user's
      // notifications mixed together, and a busy table can push this admin's
      // own notification out of the page-size window entirely.
      query = currentUserId
        ? query.or(`user_id.eq.${currentUserId},user_id.is.null`)
        : query;

      const { data, error } = await query;

      if (error) {
        console.warn("Notifications fetch error:", error.message || error);
        return false;
      }

      const rows = (data as any[]) || [];
      setNotifications(rows);
      setHasMore(rows.length >= effectiveLimit);
      return true;
    } catch (error) {
      console.warn("Notifications fetch exception:", error);
      return false;
    }
  }, []);

  const handleLoadMore = useCallback(async () => {
    setLoadingMore(true);
    try {
      const newLimit = limitRef.current + NOTIFICATIONS_PAGE_SIZE;
      limitRef.current = newLimit;
      await loadNotifications(newLimit);
    } finally {
      setLoadingMore(false);
    }
  }, [loadNotifications]);

  useEffect(() => {
    let mounted = true;

    const load = async () => {
      setLoading(true);
      try {
        const success = await loadNotifications();

        if (!success && mounted) {
          setNotifications([]);
        }
      } finally {
        if (mounted) setLoading(false);
      }
    };

    let channel: any = null;

    void (async () => {
      // Resolve the current user + tenant first — both the initial REST
      // fetch and the realtime subscription need to filter by them.
      const { data: userData } = await supabase.auth.getUser();
      const currentUserId = userData?.user?.id ?? null;
      if (!mounted) return;
      currentUserIdRef.current = currentUserId;

      const { data: myTenantId } = await supabase.rpc("current_tenant_id");
      if (!mounted) return;

      const handleInsert = (payload: any) => {
        if (!mounted) return;
        const newRow = payload.new;
        setNotifications((current) => {
          if (!newRow) return current;
          if (current.some((item) => item.id === newRow.id)) return current;
          return [newRow, ...current].slice(0, 8);
        });
      };

      const handleUpdate = (payload: any) => {
        if (!mounted) return;
        const updated = payload.new;
        if (!updated) return;
        setNotifications((current) => current.map((item) => (item.id === updated.id ? updated : item)));
      };

      // Two separate server-side filters instead of one unfiltered
      // subscription + client-side check — Postgres only broadcasts rows
      // matching each filter over the wire, so another tenant's (or another
      // user's) notification content never reaches this browser at all.
      channel = supabase
        .channel("admin-header-notifications")
        .on(
          "postgres_changes",
          { event: "INSERT", schema: "public", table: "notifications", filter: `user_id=eq.${currentUserId}` },
          handleInsert
        )
        .on(
          "postgres_changes",
          { event: "UPDATE", schema: "public", table: "notifications", filter: `user_id=eq.${currentUserId}` },
          handleUpdate
        );

      if (myTenantId) {
        channel = channel
          .on(
            "postgres_changes",
            { event: "INSERT", schema: "public", table: "notifications", filter: `tenant_id=eq.${myTenantId}` },
            (payload: any) => {
              if (payload.new?.user_id === null) handleInsert(payload);
            }
          )
          .on(
            "postgres_changes",
            { event: "UPDATE", schema: "public", table: "notifications", filter: `tenant_id=eq.${myTenantId}` },
            (payload: any) => {
              if (payload.new?.user_id === null) handleUpdate(payload);
            }
          );
      }

      channel.subscribe();

      // Trigger server-side syncs (visa & contract expiries) then load, now
      // that currentUserIdRef is set so the fetch is correctly scoped.
      await Promise.all([syncWorkerVisaNotifications(), syncContractExpiryNotifications()]);
      await load();
    })();

    const syncOnVisible = () => {
      if (document.visibilityState === "visible") {
        void loadNotifications();
      }
    };

    const syncOnFocus = () => {
      void loadNotifications();
    };

    const syncInterval = window.setInterval(() => {
      void loadNotifications();
    }, 20000);

    document.addEventListener("visibilitychange", syncOnVisible);
    window.addEventListener("focus", syncOnFocus);

    return () => {
      mounted = false;
      window.clearInterval(syncInterval);
      document.removeEventListener("visibilitychange", syncOnVisible);
      window.removeEventListener("focus", syncOnFocus);

      try {
        channel?.unsubscribe();
      } catch {
        // ignore
      }
    };
  }, []);

  const unreadCount = notifications.filter((item) => !item.read).length;
  const unreadLabel = unreadCount > 99 ? "99+" : String(unreadCount);
  const visibleNotifications = notifications;

  const markAsRead = async (notificationId: string) => {
    const target = notifications.find((item) => item.id === notificationId);
    if (!target || target.read) return;

    setNotifications((current) => current.map((item) => (item.id === notificationId ? { ...item, read: true } : item)));

    const { error } = await supabase.from("notifications").update({ read: true }).eq("id", notificationId);
    if (error) {
      console.warn("Failed to mark notification as read:", error.message || error);
      setNotifications((current) => current.map((item) => (item.id === notificationId ? { ...item, read: false } : item)));
      return;
    }
  };

  return (
    <div className="notifications" ref={ref} style={{ position: "relative", marginRight: 8 }}>
      <button
        type="button"
        className={`icon-button notifications-trigger ${open ? "is-open" : ""}`}
        onClick={() => setOpen((prev) => !prev)}
        aria-label="الإشعارات"
        aria-expanded={open}
      >
        <Bell size={18} />
        {unreadCount > 0 && <span className="notifications-badge">{unreadLabel}</span>}
      </button>

      {open && (
        <div className={`notifications-dropdown ${dropdownAlign === "start" ? "align-start" : "align-end"}`} role="menu" aria-label="قائمة الإشعارات">
          <div className="notifications-dropdown-head">
            <div>
              <div className="notifications-dropdown-title">
                <BellRing size={16} />
                <span>الإشعارات</span>
              </div>
              <div className="notifications-dropdown-subtitle">
                {unreadCount > 0 ? `${unreadCount} غير مقروءة` : "كل الإشعارات مقروءة"}
              </div>
            </div>
          </div>

          <div className="notifications-dropdown-body">
            {loading ? (
              <div className="notifications-empty notifications-loading">
                <div className="spinner" />
                <span>جارٍ تحميل الإشعارات...</span>
              </div>
            ) : notifications.length === 0 ? (
              <div className="notifications-empty">
                <BellRing size={18} />
                <span>لا توجد إشعارات حالياً</span>
              </div>
            ) : (
              <ul className="notifications-list">
                {visibleNotifications.map((notification) => (
                  <li key={notification.id}>
                    <button
                      type="button"
                      className={`notification-item ${!notification.read ? "is-unread" : ""}`}
                      onClick={() => {
                        setOpen(false);
                        void markAsRead(notification.id);
                        navigate(resolveNotificationTarget(notification));
                      }}
                    >
                      <div className="notification-item-top">
                        <div className="notification-title">{notification.title}</div>
                        {!notification.read && <span className="notification-dot" aria-hidden="true" />}
                      </div>

                      {notification.body && <div className="notification-body">{notification.body}</div>}

                      <div className="notification-meta">
                        <Clock3 size={13} />
                        <span>{formatRelativeTime(notification.created_at)}</span>
                      </div>
                    </button>
                  </li>
                ))}
              </ul>
            )}

            {!loading && hasMore && notifications.length > 0 && (
              <button
                type="button"
                className="link-button"
                onClick={() => void handleLoadMore()}
                disabled={loadingMore}
                style={{ width: "100%", textAlign: "center", padding: "8px 0" }}
              >
                {loadingMore ? "جارٍ التحميل..." : "تحميل المزيد"}
              </button>
            )}
          </div>

          <div className="notifications-dropdown-footer">
            <button
              type="button"
              className="link-button"
              onClick={() => {
                setOpen(false);
                navigate("/admin/visit-notification");
              }}
            >
              فتح صفحة الإشعارات
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

export default Notifications;
