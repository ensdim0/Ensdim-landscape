export const Roles = {
  Admin: "admin",
  Supervisor: "supervisor",
  Client: "client"
} as const;

export type RoleName = (typeof Roles)[keyof typeof Roles];
