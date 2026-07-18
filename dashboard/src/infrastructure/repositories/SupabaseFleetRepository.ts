import { FleetRepository } from "@domain/repositories/FleetRepository";
import { supabase } from "@infrastructure/supabase/client";
import { Vehicle } from "@domain/entities/Vehicle";
import { VehicleExpense } from "@domain/entities/VehicleExpense";
import type { PaymentMethod } from "@domain/entities/ContractPayment";

export class SupabaseFleetRepository implements FleetRepository {
  private mapVehicle(row: any): Vehicle {
    return {
      id: row.id,
      plateNumber: row.plate_number,
      licenseNumber: row.license_number,
      licenseExpiry: row.license_expiry,
      status: row.status,
      notes: row.notes,
      createdAt: row.created_at,
      expenseCount: row.vehicle_expenses?.[0]?.count ?? 0,
      totalExpenses: row.total_expenses ?? 0,
    };
  }

  private mapExpense(row: any): VehicleExpense {
    return {
      id: row.id,
      vehicleId: row.vehicle_id,
      lineItemId: row.line_item_id ?? null,
      description: row.description,
      amount: Number(row.amount),
      expenseDate: row.expense_date,
      paymentMethod: (row.payment_method ?? null) as PaymentMethod | null,
      createdAt: row.created_at,
    };
  }

  async listVehicles(): Promise<Vehicle[]> {
    const { data, error } = await supabase
      .from("vehicles")
      .select("*, vehicle_expenses(count)")
      .order("created_at", { ascending: false });
    if (error) throw error;

    const { data: totals } = await supabase
      .from("vehicle_expenses")
      .select("vehicle_id, amount, expense_date");

    const now = new Date();
    const curYear = now.getFullYear();
    const curMonth = now.getMonth();

    const totalsMap: Record<string, number> = {};
    const monthMap: Record<string, number> = {};
    (totals ?? []).forEach((e: any) => {
      const amt = Number(e.amount);
      totalsMap[e.vehicle_id] = (totalsMap[e.vehicle_id] || 0) + amt;
      const d = new Date(e.expense_date);
      if (d.getFullYear() === curYear && d.getMonth() === curMonth) {
        monthMap[e.vehicle_id] = (monthMap[e.vehicle_id] || 0) + amt;
      }
    });

    return (data ?? []).map((row) => ({
      ...this.mapVehicle(row),
      totalExpenses: totalsMap[row.id] ?? 0,
      currentMonthExpenses: monthMap[row.id] ?? 0,
    }));
  }

  async createVehicle(payload: {
    plateNumber: string;
    licenseNumber: string;
    licenseExpiry: string;
    notes?: string | null;
  }): Promise<Vehicle> {
    const { data, error } = await supabase
      .from("vehicles")
      .insert({
        plate_number: payload.plateNumber,
        license_number: payload.licenseNumber,
        license_expiry: payload.licenseExpiry,
        notes: payload.notes || null,
        status: "active",
      })
      .select()
      .single();
    if (error) throw error;
    return this.mapVehicle(data);
  }

  async updateVehicle(payload: {
    id: string;
    plateNumber: string;
    licenseNumber: string;
    licenseExpiry: string;
    notes?: string | null;
    isActive: boolean;
  }): Promise<Vehicle> {
    const { data, error } = await supabase
      .from("vehicles")
      .update({
        plate_number: payload.plateNumber,
        license_number: payload.licenseNumber,
        license_expiry: payload.licenseExpiry,
        notes: payload.notes || null,
        status: payload.isActive ? "active" : "inactive",
      })
      .eq("id", payload.id)
      .select()
      .single();
    if (error) throw error;
    return this.mapVehicle(data);
  }

  async deleteVehicle(id: string): Promise<void> {
    const { error } = await supabase.from("vehicles").delete().eq("id", id);
    if (error) throw error;
  }

  async listExpenses(vehicleId: string): Promise<VehicleExpense[]> {
    const { data, error } = await supabase
      .from("vehicle_expenses")
      .select("*")
      .eq("vehicle_id", vehicleId)
      .order("expense_date", { ascending: false });
    if (error) throw error;
    return (data ?? []).map((row) => this.mapExpense(row));
  }

  async listAllExpenses(): Promise<VehicleExpense[]> {
    const { data, error } = await supabase
      .from("vehicle_expenses")
      .select("*")
      .order("expense_date", { ascending: false });
    if (error) throw error;
    return (data ?? []).map((row) => this.mapExpense(row));
  }

  async createExpense(payload: {
    vehicleId: string;
    lineItemId?: string | null;
    description: string;
    amount: number;
    expenseDate: string;
    paymentMethod?: PaymentMethod | null;
  }): Promise<VehicleExpense> {
    const { data, error } = await supabase
      .from("vehicle_expenses")
      .insert({
        vehicle_id: payload.vehicleId,
        line_item_id: payload.lineItemId ?? null,
        description: payload.description,
        amount: payload.amount,
        expense_date: payload.expenseDate,
        payment_method: payload.paymentMethod ?? null,
      })
      .select()
      .single();
    if (error) throw error;
    return this.mapExpense(data);
  }

  async updateExpense(payload: {
    id: string;
    vehicleId: string;
    lineItemId?: string | null;
    description: string;
    amount: number;
    expenseDate: string;
    paymentMethod?: PaymentMethod | null;
  }): Promise<VehicleExpense> {
    const { data, error } = await supabase
      .from("vehicle_expenses")
      .update({
        vehicle_id: payload.vehicleId,
        line_item_id: payload.lineItemId ?? null,
        description: payload.description,
        amount: payload.amount,
        expense_date: payload.expenseDate,
        payment_method: payload.paymentMethod ?? null,
      })
      .eq("id", payload.id)
      .select()
      .single();
    if (error) throw error;
    return this.mapExpense(data);
  }

  async deleteExpense(id: string): Promise<void> {
    const { error } = await supabase.from("vehicle_expenses").delete().eq("id", id);
    if (error) throw error;
  }
}
