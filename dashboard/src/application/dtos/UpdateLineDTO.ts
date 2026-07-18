export type UpdateLineDTO = {
  id: string;
  name: string;
  lineType: string;
  contractTypeId?: string | null;
  phoneNumber?: string | null;
  carNumber?: string | null;
  vehicleId?: string | null;
  phoneId?: string | null;
  isActive: boolean;
};
