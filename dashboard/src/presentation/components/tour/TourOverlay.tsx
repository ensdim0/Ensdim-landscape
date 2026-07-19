import { useLayoutEffect, useRef, useState } from "react";
import { X } from "lucide-react";
import { useTourContext } from "@presentation/components/tour/TourContext";

const SPOTLIGHT_PADDING = 8;
const TOOLTIP_WIDTH = 340;
const TOOLTIP_MARGIN = 14;

type Rect = { top: number; left: number; width: number; height: number };
type Position = { top: number; left: number };

const getTargetRect = (selector: string): Rect | null => {
  const el = document.querySelector(selector);
  if (!el) return null;
  const rect = el.getBoundingClientRect();
  return { top: rect.top, left: rect.left, width: rect.width, height: rect.height };
};

const getSpotlightBox = (rect: Rect) => ({
  top: rect.top - SPOTLIGHT_PADDING,
  left: rect.left - SPOTLIGHT_PADDING,
  width: rect.width + SPOTLIGHT_PADDING * 2,
  height: rect.height + SPOTLIGHT_PADDING * 2,
});

/**
 * Full-viewport tour overlay: cuts a spotlight hole around the current
 * step's target (via a box-shadow "hole" so no RTL-sensitive left/right
 * math is needed — everything is derived from the target's real
 * getBoundingClientRect()) and shows an explanatory tooltip card next to it.
 *
 * The tooltip is placed in two passes: it first renders hidden so its real
 * (content-dependent) size can be measured, then it's repositioned on
 * whichever side of the spotlight has more room and clamped fully inside
 * the viewport — so it never gets pushed off-screen by a tall target
 * (e.g. the sidebar nav) or a long line of text.
 */
export const TourOverlay = () => {
  const { active, next, skip } = useTourContext();
  const [rect, setRect] = useState<Rect | null>(null);
  const [position, setPosition] = useState<Position | null>(null);
  const tooltipRef = useRef<HTMLDivElement>(null);

  const step = active?.steps[active.index] ?? null;

  // Locate the current step's target, scroll it into view if needed, and
  // keep tracking its position as the page scrolls or resizes.
  useLayoutEffect(() => {
    if (!step) {
      setRect(null);
      return;
    }

    const el = document.querySelector(step.target);
    if (!el) {
      // Target isn't on the page (e.g. a collapsed section) — skip
      // forward instead of showing a spotlight over nothing.
      setRect(null);
      next();
      return;
    }
    el.scrollIntoView({ block: "center", behavior: "instant" });

    const measure = () => setRect(getTargetRect(step.target));
    measure();
    window.addEventListener("resize", measure);
    document.addEventListener("scroll", measure, true);
    return () => {
      window.removeEventListener("resize", measure);
      document.removeEventListener("scroll", measure, true);
    };
  }, [step, next]);

  // Once the spotlight position is known and the tooltip has rendered with
  // this step's real content, measure its actual size and compute a
  // clamped, fully-on-screen position for it.
  useLayoutEffect(() => {
    if (!rect || !tooltipRef.current) {
      setPosition(null);
      return;
    }

    const { width: tooltipWidth, height: tooltipHeight } = tooltipRef.current.getBoundingClientRect();
    const viewportWidth = window.innerWidth;
    const viewportHeight = window.innerHeight;
    const spotlight = getSpotlightBox(rect);

    const spaceAbove = spotlight.top;
    const spaceBelow = viewportHeight - (spotlight.top + spotlight.height);
    const placeBelow = spaceBelow >= tooltipHeight + TOOLTIP_MARGIN || spaceBelow >= spaceAbove;

    let top = placeBelow
      ? spotlight.top + spotlight.height + TOOLTIP_MARGIN
      : spotlight.top - TOOLTIP_MARGIN - tooltipHeight;
    top = Math.min(Math.max(top, TOOLTIP_MARGIN), viewportHeight - tooltipHeight - TOOLTIP_MARGIN);

    const left = Math.min(
      Math.max(spotlight.left, TOOLTIP_MARGIN),
      viewportWidth - tooltipWidth - TOOLTIP_MARGIN
    );

    setPosition({ top, left });
  }, [rect]);

  if (!active || !step || !rect) return null;

  const spotlight = getSpotlightBox(rect);
  const isLast = active.index === active.steps.length - 1;

  return (
    <div className="tour-root" role="dialog" aria-modal="true">
      <div
        className="tour-spotlight"
        style={{
          top: spotlight.top,
          left: spotlight.left,
          width: spotlight.width,
          height: spotlight.height,
        }}
      />
      <div
        ref={tooltipRef}
        className="tour-tooltip"
        style={{
          top: position?.top ?? spotlight.top,
          left: position?.left ?? spotlight.left,
          width: TOOLTIP_WIDTH,
          visibility: position ? "visible" : "hidden",
        }}
      >
        <button type="button" className="tour-tooltip-close" onClick={skip} aria-label="إغلاق الشرح">
          <X size={16} />
        </button>
        <p className="tour-tooltip-step">
          {active.index + 1} / {active.steps.length}
        </p>
        <h4 className="tour-tooltip-title">{step.title}</h4>
        <p className="tour-tooltip-content">{step.content}</p>
        <div className="tour-tooltip-actions">
          <button type="button" className="tour-tooltip-skip" onClick={skip}>
            تخطي
          </button>
          <button type="button" className="tour-tooltip-next" onClick={next}>
            {isLast ? "تمام، فهمت" : "التالي"}
          </button>
        </div>
      </div>
    </div>
  );
};
