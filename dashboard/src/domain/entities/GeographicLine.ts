export type LineStatus = "active" | "inactive";

export type GeographicLine = {
  id: string;
  name: string;
  lineType: string;
  contractTypeId?: string | null;
  phoneNumber?: string | null;
  carNumber?: string | null;
  vehicleId?: string | null;
  vehiclePlate?: string | null;
  phoneId?: string | null;
  phoneDisplay?: string | null;
  status: LineStatus;
  createdAt: string;
  zoneCount?: number;
};
