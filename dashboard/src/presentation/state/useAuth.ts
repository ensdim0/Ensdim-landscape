import { useCallback, useEffect, useState } from "react";
import { User } from "@domain/entities/User";
import { container } from "@infrastructure/di/container";
import { supabase } from "@infrastructure/supabase/client";
import { login as loginUseCase } from "@application/use-cases/auth/login";
import { logout as logoutUseCase } from "@application/use-cases/auth/logout";
import { useToast } from "@presentation/components/ToastProvider";

export const useAuth = () => {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const { notify } = useToast();

  useEffect(() => {
    let isMounted = true;

    const loadSession = async () => {
      try {
        const { data } = await supabase.auth.getSession();
        if (!isMounted) return;
        if (!data.session) {
          setUser(null);
          setLoading(false);
          return;
        }
        const currentUser = await container.authRepository.getCurrentUser();
        if (!isMounted) return;
        setUser(currentUser);
        setLoading(false);
      } catch (e: any) {
        if (e?.name === 'AbortError') return; // Ignore lock abort
        if (!isMounted) return;
        setUser(null);
        setLoading(false);
      }
    };

    const { data: authListener } = supabase.auth.onAuthStateChange(() => {
      loadSession();
    });

    loadSession();

    return () => {
      isMounted = false;
      authListener.subscription.unsubscribe();
    };
  }, []);

  const login = useCallback(async (email: string, password: string) => {
    const result = await loginUseCase(container.authRepository, { email, password });
    if (!result.ok) {
      notify(result.error.message);
      return false;
    }
    const currentUser = await container.authRepository.getCurrentUser();
    setUser(currentUser);
    return true;
  }, [notify]);

  const logout = useCallback(async () => {
    const result = await logoutUseCase(container.authRepository);
    if (!result.ok) {
      notify(result.error.message);
      return;
    }
    setUser(null);
  }, [notify]);

  return { user, loading, login, logout };
};
