export type NotificationRecord = {
  id: string;
  title?: string | null;
  body?: string | null;
  meta?: unknown;
};

type MetaMap = Record<string, any>;

const parseMeta = (value: unknown): MetaMap => {
  if (!value) return {};
  if (typeof value === "object") return value as MetaMap;
  if (typeof value === "string") {
    try {
      const parsed = JSON.parse(value);
      return parsed && typeof parsed === "object" ? (parsed as MetaMap) : {};
    } catch {
      return {};
    }
  }
  return {};
};

const toStringOrEmpty = (value: unknown): string =>
  typeof value === "string" && value.trim() ? value.trim() : "";

const buildVisitNotificationRoute = (
  type: string,
  contractId: string,
  visitId: string,
  commentId?: string,
) => {
  const params = new URLSearchParams();
  params.set("from", "notification");
  params.set("type", type || "visit");
  params.set("contractId", contractId);
  params.set("visitId", visitId);
  if (commentId) params.set("commentId", commentId);
  return `/admin/visit-notification?${params.toString()}`;
};

const buildWorkerNotificationRoute = (workerId: string) => {
  const params = new URLSearchParams();
  params.set("from", "notification");
  params.set("type", "worker_visa_expiry");
  if (workerId) params.set("workerId", workerId);
  return `/admin/workers?${params.toString()}`;
};

const buildVehicleNotificationRoute = (type: string, vehicleId: string) => {
  const params = new URLSearchParams();
  params.set("from", "notification");
  params.set("type", type || "vehicle_license_expiry");
  if (vehicleId) params.set("vehicleId", vehicleId);
  return `/admin/fleet?${params.toString()}`;
};

export const resolveNotificationTarget = (notification: NotificationRecord): string => {
  const meta = parseMeta(notification.meta);
  const type = toStringOrEmpty(meta.type);

  const contractId = toStringOrEmpty(meta.contract_id || meta.contractId);
  const visitId = toStringOrEmpty(meta.visit_id || meta.visitId);
  const commentId = toStringOrEmpty(meta.comment_id || meta.commentId);
  const noteId = toStringOrEmpty(meta.note_id || meta.noteId);
  const workerId = toStringOrEmpty(meta.worker_id || meta.workerId);
  const vehicleId = toStringOrEmpty(meta.vehicle_id || meta.vehicleId);
  const taskId = toStringOrEmpty(meta.task_id || meta.taskId);
  const requestId = toStringOrEmpty(meta.request_id || meta.requestId);

  if (type === "contact_request" && requestId) {
    const params = new URLSearchParams();
    params.set("from", "notification");
    params.set("requestId", requestId);
    return `/admin/contact-requests?${params.toString()}`;
  }

  if (
    (type === "standalone_task_assigned" || type === "standalone_task_completed" || type === "standalone_task_cancelled") &&
    taskId
  ) {
    return `/admin/tasks/${taskId}`;
  }

  // Standalone task status notifications (older records may have no type but have task_id + status)
  if (!type && taskId) {
    return `/admin/tasks/${taskId}`;
  }

  if (type === "client_comment" && contractId && visitId) {
    return buildVisitNotificationRoute(type, contractId, visitId, commentId || undefined);
  }

  if (type === "supervisor_note" && contractId && visitId) {
    const params = new URLSearchParams();
    params.set("from", "notification");
    params.set("type", type || "visit");
    params.set("contractId", contractId);
    params.set("visitId", visitId);
    if (noteId) params.set("noteId", noteId);
    return `/admin/visit-notification?${params.toString()}`;
  }

  if (type === "visit_completed" && contractId && visitId) {
    const params = new URLSearchParams();
    params.set("from", "notification");
    params.set("contractId", contractId);
    params.set("visitId", visitId);
    return `/admin/contracts?${params.toString()}`;
  }

  if ((commentId || visitId) && contractId && visitId) {
    return buildVisitNotificationRoute(type || "visit", contractId, visitId, commentId || undefined);
  }

  if (type === "worker_visa_expiring" || type === "worker_visa_expired") {
    return buildWorkerNotificationRoute(workerId);
  }

  if (
    type === "vehicle_license_expiring_30" ||
    type === "vehicle_license_expiring_15" ||
    type === "vehicle_license_expired"
  ) {
    return buildVehicleNotificationRoute(type, vehicleId);
  }

  // Contract expiry notifications should open contract details
  if (
    type === "contract_expiring_30" ||
    type === "contract_expiring_15" ||
    type === "contract_expired"
  ) {
    if (contractId) {
      const params = new URLSearchParams();
      params.set("from", "notification");
      params.set("type", type);
      params.set("contractId", contractId);
      return `/admin/contracts?${params.toString()}`;
    }
    return "/admin/contracts";
  }

  // Payment notifications (admin-facing): open the relevant contract
  if ((type === "payment_received_admin" || type === "payment_late_admin") && contractId) {
    const params = new URLSearchParams();
    params.set("from", "notification");
    params.set("type", type);
    params.set("contractId", contractId);
    return `/admin/contracts?${params.toString()}`;
  }

  return "/admin/contract-status-requests";
};
