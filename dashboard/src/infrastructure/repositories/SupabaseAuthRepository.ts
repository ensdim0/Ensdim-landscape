import { AuthRepository, AuthSession } from "@domain/repositories/AuthRepository";
import { supabase } from "@infrastructure/supabase/client";
import { User } from "@domain/entities/User";

type RoleInfo = {
  role: string;
  fullName: string;
  tenantId?: string;
  tenantName?: string;
  tenantStatus?: User["tenantStatus"];
};

const mapUser = (user: any, info: RoleInfo): User => ({
  id: user.id,
  email: user.email ?? "",
  fullName: info.fullName ?? user.user_metadata?.full_name ?? "",
  role: info.role as User["role"],
  createdAt: user.created_at,
  tenantId: info.tenantId,
  tenantName: info.tenantName,
  tenantStatus: info.tenantStatus
});

/**
 * Fetch user role from profiles table (the source of truth for roles).
 *
 * users_view deliberately returns no row for a suspended tenant's user (see
 * current_tenant_id()), so my_tenant_status() is queried separately — it
 * bypasses that filter — purely so the app can tell "suspended" apart from
 * "something is actually broken" and show the right screen.
 */
const fetchUserRole = async (userId: string): Promise<RoleInfo> => {
  const [{ data }, { data: tenantStatusRows }] = await Promise.all([
    supabase.from("users_view").select("role, fullName, tenantId, tenantName").eq("id", userId).maybeSingle(),
    supabase.rpc("my_tenant_status")
  ]);

  const tenantStatusRow = Array.isArray(tenantStatusRows) ? tenantStatusRows[0] : tenantStatusRows;

  return {
    role: data?.role ?? "client",
    fullName: data?.fullName ?? "",
    tenantId: data?.tenantId ?? tenantStatusRow?.tenant_id ?? undefined,
    tenantName: data?.tenantName ?? tenantStatusRow?.tenant_name ?? undefined,
    tenantStatus: tenantStatusRow?.status ?? undefined
  };
};

const resolveLoginEmail = async (identifier: string): Promise<string> => {
  const cleaned = typeof identifier === 'string' ? identifier.trim().toLowerCase() : '';
  if (!cleaned) return cleaned;

  if (cleaned.includes("@")) {
    return cleaned;
  }

  const normalizedPhone = cleaned.replace(/[^0-9+]/g, "");
  if (!normalizedPhone) {
    throw new Error("Invalid login identifier");
  }

  const { data, error } = await supabase.rpc("resolve_login_email", {
    login_identifier: cleaned,
  });

  if (error) {
    // Backward compatibility for environments that still use phone@bustan.local auth emails.
    if ((error as any).status === 404) {
      return `${normalizedPhone}@bustan.local`;
    }
    throw error;
  }

  if (typeof data === "string" && data.trim()) {
    return data.trim().toLowerCase();
  }

  return `${normalizedPhone}@bustan.local`;
};

export class SupabaseAuthRepository implements AuthRepository {
  async login(email: string, password: string): Promise<AuthSession> {
    const resolvedEmail = await resolveLoginEmail(email);
    const { data, error } = await supabase.auth.signInWithPassword({
      email: resolvedEmail,
      password
    });
    if (error || !data.session || !data.user) {
      throw error ?? new Error("Invalid login");
    }

    const info = await fetchUserRole(data.user.id);

    return {
      accessToken: data.session.access_token,
      user: mapUser(data.user, info)
    };
  }

  async logout(): Promise<void> {
    const { error } = await supabase.auth.signOut();
    if (error) throw error;
  }

  async getCurrentUser(): Promise<User | null> {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) return null;

    const { data, error } = await supabase.auth.getUser();
    if (error || !data.user) return null;

    const info = await fetchUserRole(data.user.id);
    return mapUser(data.user, info);
  }
}
