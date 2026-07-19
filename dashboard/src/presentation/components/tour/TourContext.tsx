import { ReactNode, createContext, useCallback, useContext, useMemo, useRef, useState } from "react";
import { useAuth } from "@presentation/state/useAuth";

export type TourStep = {
  /** CSS selector for the element to spotlight, e.g. `[data-tour="stat-clients"]`. */
  target: string;
  title: string;
  content: string;
};

type ActiveTour = {
  pageId: string;
  steps: TourStep[];
  index: number;
};

type TourContextValue = {
  active: ActiveTour | null;
  registerPageTour: (pageId: string, steps: TourStep[]) => void;
  replayCurrentPage: () => void;
  next: () => void;
  skip: () => void;
};

const TourContext = createContext<TourContextValue | undefined>(undefined);

const seenKey = (userId: string, pageId: string) => `tour_seen_${userId}_${pageId}`;

export const TourProvider = ({ children }: { children: ReactNode }) => {
  const { user } = useAuth();
  const [active, setActive] = useState<ActiveTour | null>(null);
  // Tracks the most recently mounted page's tour so the header's replay
  // button can restart it without the page having to expose anything itself.
  const currentPageRef = useRef<{ pageId: string; steps: TourStep[] } | null>(null);

  const markSeen = useCallback(
    (pageId: string) => {
      if (!user) return;
      localStorage.setItem(seenKey(user.id, pageId), "1");
    },
    [user]
  );

  const registerPageTour = useCallback(
    (pageId: string, steps: TourStep[]) => {
      currentPageRef.current = { pageId, steps };
      if (!user || steps.length === 0) return;
      const seen = localStorage.getItem(seenKey(user.id, pageId));
      if (seen) return;
      setActive({ pageId, steps, index: 0 });
    },
    [user]
  );

  const replayCurrentPage = useCallback(() => {
    const current = currentPageRef.current;
    if (!current || current.steps.length === 0) return;
    setActive({ pageId: current.pageId, steps: current.steps, index: 0 });
  }, []);

  const next = useCallback(() => {
    setActive((prev) => {
      if (!prev) return prev;
      if (prev.index >= prev.steps.length - 1) {
        markSeen(prev.pageId);
        return null;
      }
      return { ...prev, index: prev.index + 1 };
    });
  }, [markSeen]);

  const skip = useCallback(() => {
    setActive((prev) => {
      if (prev) markSeen(prev.pageId);
      return null;
    });
  }, [markSeen]);

  const value = useMemo(
    () => ({ active, registerPageTour, replayCurrentPage, next, skip }),
    [active, registerPageTour, replayCurrentPage, next, skip]
  );

  return <TourContext.Provider value={value}>{children}</TourContext.Provider>;
};

export const useTourContext = () => {
  const context = useContext(TourContext);
  if (!context) {
    throw new Error("TourProvider is missing");
  }
  return context;
};
