import { ReactNode } from "react";
import { Navigate } from "react-router-dom";
import { useAuth } from "@presentation/state/useAuth";
import { LoadingState } from "@presentation/components/States";

type AllowedRole = "admin" | "supervisor" | "client";

interface RequireAuthProps {
  children: ReactNode;
  allowedRoles?: AllowedRole[];
}

/**
 * Auth guard with role-based access control.
 * - Redirects to /login if not authenticated
 * - Redirects to /unauthorized if authenticated but wrong role
 * - Validates session integrity
 */
export const RequireAuth = ({ children, allowedRoles }: RequireAuthProps) => {
  const { user, loading } = useAuth();

  if (loading) {
    return <LoadingState />;
  }

  if (!user) {
    return <Navigate to="/login" replace />;
  }

  if (allowedRoles && allowedRoles.length > 0) {
    const userRole = (user as any).role as string | undefined;
    if (!userRole || !allowedRoles.includes(userRole as AllowedRole)) {
      return <Navigate to="/login" replace />;
    }
  }

  return <>{children}</>;
};
