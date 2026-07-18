import type { VisitStatus } from "@domain/entities/Visit";

export const VISIT_STATUS_VALUES = ["planned", "in_progress", "completed", "cancelled"] as const;

export const VISIT_STATUS_OPTIONS = [
  { value: "planned", label: "لم تكتمل" },
  { value: "in_progress", label: "لم تكتمل" },
  { value: "completed", label: "مكتملة" },
  { value: "cancelled", label: "لم تكتمل" },
] as const;

export const VISIT_STATUS_LABELS: Record<VisitStatus, string> = {
  planned: "لم تكتمل",
  in_progress: "لم تكتمل",
  completed: "مكتملة",
  cancelled: "لم تكتمل",
};

export type VisitStatusVariant = "success" | "warning" | "error" | "info" | "default";

export type VisitStatusStyle = {
  label: string;
  color: string;
  bg: string;
  variant: VisitStatusVariant;
};

export const VISIT_STATUS_STYLES: Record<VisitStatus, VisitStatusStyle> = {
  planned: {
    label: VISIT_STATUS_LABELS.planned,
    color: "var(--color-info)",
    bg: "var(--color-info-bg)",
    variant: "info",
  },
  in_progress: {
    label: VISIT_STATUS_LABELS.in_progress,
    color: "var(--color-warning)",
    bg: "var(--color-warning-bg)",
    variant: "warning",
  },
  completed: {
    label: VISIT_STATUS_LABELS.completed,
    color: "var(--color-success)",
    bg: "var(--color-success-bg)",
    variant: "success",
  },
  cancelled: {
    label: VISIT_STATUS_LABELS.cancelled,
    color: "var(--color-error)",
    bg: "var(--color-error-bg)",
    variant: "error",
  },
};

export const normalizeVisitStatus = (status?: string | null) => {
  if (status === "planned" || status === "in_progress" || status === "completed" || status === "cancelled") {
    return status;
  }
  return "planned";
};

export const getVisitStatusLabel = (status?: string | null) => {
  const normalized = normalizeVisitStatus(status);
  return VISIT_STATUS_LABELS[normalized] || normalized;
};

export const getVisitStatusStyle = (status?: string | null): VisitStatusStyle => {
  const normalized = normalizeVisitStatus(status);
  return VISIT_STATUS_STYLES[normalized];
};