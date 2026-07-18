import { GeographicLine } from "@domain/entities/GeographicLine";
import { Zone } from "@domain/entities/Zone";
import { Block } from "@domain/entities/Block";

export interface LineRepository {
  listLines(): Promise<GeographicLine[]>;
  createLine(payload: { name: string; lineType: string; contractTypeId?: string | null; phoneNumber?: string | null; carNumber?: string | null; vehicleId?: string | null; phoneId?: string | null }): Promise<GeographicLine>;
  updateLine(payload: {
    id: string;
    name: string;
    lineType: string;
    contractTypeId?: string | null;
    phoneNumber?: string | null;
    carNumber?: string | null;
    vehicleId?: string | null;
    phoneId?: string | null;
    isActive: boolean;
  }): Promise<GeographicLine>;
  deleteLine(id: string): Promise<void>;
  listZones(lineId: string): Promise<Zone[]>;
  createZone(payload: { lineId: string; name: string; sortOrder: number }): Promise<Zone>;
  updateZone(payload: { id: string; name: string; sortOrder: number; isActive: boolean }): Promise<Zone>;
  deleteZone(id: string): Promise<void>;
  reorderZones(zones: { id: string; sortOrder: number }[]): Promise<void>;
  listBlocks(zoneId: string): Promise<Block[]>;
  listAllBlocks(): Promise<Block[]>;
  createBlock(payload: { zoneId: string; code: string }): Promise<Block>;
}
