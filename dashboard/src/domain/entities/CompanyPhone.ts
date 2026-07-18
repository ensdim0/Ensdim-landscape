export type PhoneStatus = "active" | "inactive";

export type CompanyPhone = {
  id: string;
  phoneNumber: string;
  phoneName?: string | null;
  status: PhoneStatus;
  notes?: string | null;
  createdAt: string;
  lineCount?: number;
  lineNames?: string[];
};
