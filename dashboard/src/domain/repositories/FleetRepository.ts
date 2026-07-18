import { Vehicle } from "@domain/entities/Vehicle";
import { VehicleExpense } from "@domain/entities/VehicleExpense";
import type { PaymentMethod } from "@domain/entities/ContractPayment";

export interface FleetRepository {
  listVehicles(): Promise<Vehicle[]>;
  createVehicle(payload: { plateNumber: string; licenseNumber: string; licenseExpiry: string; notes?: string | null }): Promise<Vehicle>;
  updateVehicle(payload: { id: string; plateNumber: string; licenseNumber: string; licenseExpiry: string; notes?: string | null; isActive: boolean }): Promise<Vehicle>;
  deleteVehicle(id: string): Promise<void>;
  listExpenses(vehicleId: string): Promise<VehicleExpense[]>;
  listAllExpenses(): Promise<VehicleExpense[]>;
  createExpense(payload: { vehicleId: string; lineItemId?: string | null; description: string; amount: number; expenseDate: string; paymentMethod?: PaymentMethod | null }): Promise<VehicleExpense>;
  updateExpense(payload: { id: string; vehicleId: string; lineItemId?: string | null; description: string; amount: number; expenseDate: string; paymentMethod?: PaymentMethod | null }): Promise<VehicleExpense>;
  deleteExpense(id: string): Promise<void>;
}
