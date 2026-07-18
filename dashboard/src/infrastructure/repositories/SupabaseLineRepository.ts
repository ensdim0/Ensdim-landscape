import { LineRepository } from "@domain/repositories/LineRepository";
import { supabase } from "@infrastructure/supabase/client";
import { GeographicLine } from "@domain/entities/GeographicLine";
import { Zone } from "@domain/entities/Zone";
import { Block } from "@domain/entities/Block";

export class SupabaseLineRepository implements LineRepository {
    private mapZone(row: any): Zone {
      return {
        id: row.id,
        lineId: row.line_id,
        name: row.name,
        isActive: row.is_active,
        sortOrder: row.sort_order ?? 0,
        createdAt: row.created_at
      };
    }
  private mapLine(row: any): GeographicLine {
    const zoneCount = row.zones && Array.isArray(row.zones) && row.zones[0] 
        ? row.zones[0].count 
        : (row.zones?.count ?? 0);

    return {
      id: row.id,
      name: row.name,
      lineType: row.line_type,
      contractTypeId: row.contract_type_id,
      phoneNumber: row.phone_number,
      carNumber: row.car_number,
      vehicleId: row.vehicle_id,
      vehiclePlate: row.vehicles?.plate_number ?? null,
      phoneId: row.phone_id,
      phoneDisplay: row.company_phones?.phone_number ?? null,
      status: row.status === "active" ? "active" : "inactive",
      createdAt: row.created_at,
      zoneCount: zoneCount
    };
  }

  async listLines(): Promise<GeographicLine[]> {
    const { data, error } = await supabase.from("geographic_lines").select("*, zones(count), vehicles(plate_number), company_phones(phone_number)");
    if (error) throw error;
    return (data ?? []).map((row) => this.mapLine(row));
  }

  async createLine(payload: {
    name: string;
    lineType: string;
    contractTypeId?: string | null;
    phoneNumber?: string | null;
    carNumber?: string | null;
    vehicleId?: string | null;
    phoneId?: string | null;
  }): Promise<GeographicLine> {
    const { data, error } = await supabase
      .from("geographic_lines")
      .insert({
        name: payload.name,
        line_type: payload.lineType,
        contract_type_id: payload.contractTypeId || null,
        phone_number: payload.phoneNumber,
        car_number: payload.carNumber,
        vehicle_id: payload.vehicleId || null,
        phone_id: payload.phoneId || null,
        status: "active"
      })
      .select()
      .single();
    if (error) throw error;
    return this.mapLine(data);
  }

  async updateLine(payload: {
    id: string;
    name: string;
    lineType: string;
    contractTypeId?: string | null;
    phoneNumber?: string | null;
    carNumber?: string | null;
    vehicleId?: string | null;
    phoneId?: string | null;
    isActive: boolean;
  }): Promise<GeographicLine> {
    const { data, error } = await supabase
      .from("geographic_lines")
      .update({
        name: payload.name,
        line_type: payload.lineType,
        contract_type_id: payload.contractTypeId || null,
        phone_number: payload.phoneNumber,
        car_number: payload.carNumber,
        vehicle_id: payload.vehicleId || null,
        phone_id: payload.phoneId || null,
        status: payload.isActive ? "active" : "inactive"
      })
      .eq("id", payload.id)
      .select()
      .single();
    if (error) throw error;
    return this.mapLine(data);
  }

  async deleteLine(id: string): Promise<void> {
    const { data: zones } = await supabase
      .from("zones")
      .select("id")
      .eq("line_id", id);

    if (zones && zones.length > 0) {
      const zoneIds = zones.map((z: any) => z.id);
      const { count } = await supabase
        .from("contracts")
        .select("id", { count: "exact", head: true })
        .in("zone_id", zoneIds);

      if (count && count > 0) {
        throw new Error(`لا يمكن حذف الخط لأنه مرتبط بـ ${count} عقد`);
      }

      const { error: zonesErr } = await supabase
        .from("zones")
        .delete()
        .eq("line_id", id);
      if (zonesErr) throw zonesErr;
    }

    const { error } = await supabase
      .from("geographic_lines")
      .delete()
      .eq("id", id);
    if (error) throw error;
  }

  async listZones(lineId: string): Promise<Zone[]> {
    const { data, error } = await supabase
      .from("zones")
      .select("*")
      .eq("line_id", lineId)
      .order("sort_order", { ascending: true });
    if (error) throw error;
    return (data ?? []).map((row) => this.mapZone(row));
  }

  async createZone(payload: { lineId: string; name: string; sortOrder: number }): Promise<Zone> {
    const { data, error } = await supabase
      .from("zones")
      .insert({ line_id: payload.lineId, name: payload.name, sort_order: payload.sortOrder })
      .select()
      .single();
    if (error) throw error;
    return this.mapZone(data);
  }

  async updateZone(payload: { id: string; name: string; sortOrder: number; isActive: boolean }): Promise<Zone> {
    const { data, error } = await supabase
      .from("zones")
      .update({
        name: payload.name,
        sort_order: payload.sortOrder,
        is_active: payload.isActive
      })
      .eq("id", payload.id)
      .select()
      .single();
    if (error) throw error;
    return this.mapZone(data);
  }

  async deleteZone(id: string): Promise<void> {
    const { error } = await supabase.from("zones").delete().eq("id", id);
    if (error) throw error;
  }

  async reorderZones(zones: { id: string; sortOrder: number }[]): Promise<void> {
    const updates = zones.map((z) =>
      supabase.from("zones").update({ sort_order: z.sortOrder }).eq("id", z.id)
    );
    const results = await Promise.all(updates);
    const failed = results.find((r) => r.error);
    if (failed?.error) throw failed.error;
  }

  async listBlocks(zoneId: string): Promise<Block[]> {
    const { data, error } = await supabase.from("blocks").select("*").eq("zone_id", zoneId);
    if (error) throw error;
    return data as Block[];
  }

  async listAllBlocks(): Promise<Block[]> {
    const { data, error } = await supabase.from("blocks").select("*");
    if (error) throw error;
    return data as Block[];
  }

  async createBlock(payload: { zoneId: string; code: string }): Promise<Block> {
    const { data, error } = await supabase
      .from("blocks")
      .insert({ zone_id: payload.zoneId, code: payload.code })
      .select()
      .single();
    if (error) throw error;
    return data as Block;
  }
}
