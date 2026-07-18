export type CreateUserDTO = {
  email?: string;
  fullName: string;
  role: string;
  password?: string;
  phone: string;
  assignedLineId?: string;
  assignmentStartDate?: string;
  assignmentEndDate?: string;
};
