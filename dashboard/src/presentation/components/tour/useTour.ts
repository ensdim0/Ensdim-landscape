import { useEffect } from "react";
import { TourStep, useTourContext } from "@presentation/components/tour/TourContext";

/**
 * Registers `steps` as the guided tour for the page it's called from.
 * Auto-plays once per user (persisted in localStorage) and lets the
 * Header's "?" button replay it on demand via `replayCurrentPage`.
 *
 * Pass an empty array while the page's data (and therefore its
 * `data-tour` targets) hasn't loaded yet — the tour registers itself
 * once `steps` first becomes non-empty, so it never spotlights DOM
 * that isn't there yet.
 */
export const useTour = (pageId: string, steps: TourStep[]) => {
  const { registerPageTour } = useTourContext();
  const ready = steps.length > 0;

  // Registers once per page mount (as soon as steps are ready) —
  // re-running on every render would re-trigger the "seen" check and
  // could re-open a tour the user just closed.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => {
    if (!ready) return;
    registerPageTour(pageId, steps);
  }, [pageId, ready]);
};
