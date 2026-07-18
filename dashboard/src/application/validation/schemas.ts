import { z } from "zod";
import { CONTRACT_STATUS_VALUES } from "@shared/contractStatus";

export const loginSchema = z.object({
  email: z.string().min(3),
  password: z.string().min(6)
});

export const createUserSchema = z.object({
  email: z.preprocess((value) => {
    if (typeof value !== "string") return value;
    const cleaned = value.trim();
    return cleaned === "" ? undefined : cleaned;
  }, z.string().email().optional()),
  fullName: z.string().min(3),
  role: z.string().min(3),
  password: z.string().min(6).optional(),
  phone: z.string().min(7),
  assignedLineId: z.string().optional().nullable(),
  assignmentStartDate: z.string().optional().nullable(),
  assignmentEndDate: z.string().optional().nullable()
});

export const createContractSchema = z.object({
  userId: z.string().uuid(),
  zoneId: z.string().uuid(),
  code: z.string().min(3),
  contractTypeId: z.string().uuid().optional(),
  durationMonths: z.number().int().min(1).optional(),
  addressDetails: z.string().optional(),
  notes: z.string().optional(),
  palmInfo: z.any().optional().nullable(),
  blockNumber: z.string().optional(),
  street: z.string().optional(),
  avenue: z.string().optional(),
  house: z.string().optional(),
  kuwaitFinderUrl: z.string().optional(),
  startDate: z.string().min(10),
  endDate: z.string().min(10),
  totalValue: z.number().nonnegative(),
  status: z.enum(CONTRACT_STATUS_VALUES).optional(),
  terms: z.array(z.object({
    id: z.string(),
    content: z.string(),
    isRequired: z.boolean().optional()
  })).optional()
});

export const createVisitSchema = z.object({
  contractId: z.string().uuid(),
  visitDate: z.preprocess((value) => {
    if (typeof value !== "string") return value;
    const cleaned = value.trim();
    return cleaned === "" ? undefined : cleaned;
  }, z.string().min(10).optional()),
  notes: z.string().nullable().optional(),
  title: z.string().nullable().optional()
});

export const updateVisitStatusSchema = z.object({
  visitId: z.string().uuid(),
  status: z.enum(["planned", "in_progress", "completed", "cancelled"])
});

export const createLineSchema = z.object({
  name: z.string().min(3),
  lineType: z.string().min(2),
  contractTypeId: z.string().uuid().optional().nullable().or(z.literal("")),
  phoneNumber: z.string().optional().nullable(),
  carNumber: z.string().optional().nullable(),
  vehicleId: z.string().uuid().optional().nullable().or(z.literal("")),
  phoneId: z.string().uuid().optional().nullable().or(z.literal(""))
});

export const createZoneSchema = z.object({
  lineId: z.string().uuid(),
  name: z.string().min(2),
  sortOrder: z.number().int().min(0)
});

export const createBlockSchema = z.object({
  zoneId: z.string().uuid(),
  code: z.string().min(1)
});

export const updateLineSchema = z.object({
  id: z.string().uuid(),
  name: z.string().min(3),
  lineType: z.string().min(2),
  contractTypeId: z.string().uuid().optional().nullable().or(z.literal("")),
  phoneNumber: z.string().optional().nullable(),
  carNumber: z.string().optional().nullable(),
  vehicleId: z.string().uuid().optional().nullable().or(z.literal("")),
  phoneId: z.string().uuid().optional().nullable().or(z.literal("")),
  isActive: z.boolean()
});

export const updateZoneSchema = z.object({
  id: z.string().uuid(),
  name: z.string().min(2),
  sortOrder: z.number().int().min(0),
  isActive: z.boolean()
});

export const assignLineSchema = z.object({
  supervisorId: z.string().uuid(),
  lineId: z.string().uuid(),
  startDate: z.preprocess((value) => {
    if (typeof value !== "string") return value;
    const cleaned = value.trim();
    return cleaned === "" ? null : cleaned;
  }, z.string().min(10).optional().nullable()),
  endDate: z.preprocess((value) => {
    if (typeof value !== "string") return value;
    const cleaned = value.trim();
    return cleaned === "" ? null : cleaned;
  }, z.string().min(10).optional().nullable())
});

export const createContractTaskSchema = z.object({
  visitId: z.string().uuid(),
  contractId: z.string().uuid(),
  title: z.string().min(3),
  month: z.number().int().min(1).max(12)
});

export const updateTaskStatusSchema = z.object({
  taskId: z.string().uuid(),
  status: z.enum(["pending", "completed", "verified", "rejected"])
});
