export const CONTRACT_STATUS_VALUES = ["active", "pending", "expired", "cancelled"] as const;

export const CONTRACT_STATUS_OPTIONS = [
  { value: "active", label: "نشط" },
  { value: "pending", label: "انتظار" },
  { value: "expired", label: "منتهي" },
  { value: "cancelled", label: "ملغي" },
] as const;

export const CONTRACT_STATUS_FILTERS = [
  { value: "active", label: "نشط" },
  { value: "pending", label: "قيد الانتظار" },
  { value: "expired", label: "منتهي" },
  { value: "cancelled", label: "ملغي" },
] as const;

export const CONTRACT_STATUS_LABELS: Record<string, string> = {
  active: "نشط",
  pending: "انتظار",
  expired: "منتهي",
  cancelled: "ملغي",
  terminated: "ملغي",
};

export const normalizeContractStatus = (status?: string | null) => {
  if (status === "terminated") return "cancelled";
  return status ?? "";
};

export const getContractStatusLabel = (status?: string | null) => {
  const normalized = normalizeContractStatus(status);
  return CONTRACT_STATUS_LABELS[normalized] || normalized || "—";
};