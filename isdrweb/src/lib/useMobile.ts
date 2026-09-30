/* eslint-disable @typescript-eslint/no-explicit-any */
import { useEffect, useState } from "react";

/** Below the website's `lg` breakpoint (1024px) pages use the app's phone layout; at and above it, the desktop website. */
const QUERY = "(max-width: 1023.98px)";
const MOBILE_UA = /iPhone|iPod|Android.*Mobile|webOS|BlackBerry|IEMobile|Opera Mini/i;

function viewportWidth(): number {
  const widths: number[] = [];
  if (typeof window.innerWidth === "number" && window.innerWidth > 0) widths.push(window.innerWidth);
  const vv = window.visualViewport?.width;
  if (typeof vv === "number" && vv > 0) widths.push(vv);
  const cw = document.documentElement?.clientWidth;
  if (typeof cw === "number" && cw > 0) widths.push(cw);
  return widths.length ? Math.min(...widths) : 1024;
}

export function isMobileNow(): boolean {
  if (typeof window === "undefined") return false;
  if (viewportWidth() < 1024) return true;
  try {
    if (typeof window.matchMedia === "function" && window.matchMedia(QUERY).matches) return true;
  } catch {
    /* ignore */
  }
  // Chrome device mode can report a desktop innerWidth while the UA stays a phone.
  try {
    if (MOBILE_UA.test(navigator.userAgent)) return true;
  } catch {
    /* ignore */
  }
  return false;
}

/** True at phone / tablet width (< 1024px) — the website then renders the app's screens. */
export function useMobile(): boolean {
  const [mobile, setMobile] = useState(isMobileNow);

  useEffect(() => {
    let desktopTimer: ReturnType<typeof setTimeout> | null = null;

    const apply = (next: boolean) => {
      setMobile((prev) => (prev === next ? prev : next));
    };

    const update = () => {
      const next = isMobileNow();
      if (desktopTimer) {
        clearTimeout(desktopTimer);
        desktopTimer = null;
      }
      if (next) {
        apply(true);
        return;
      }
      // DevTools / keyboard / console docking can fire a one-shot "desktop" resize.
      // Wait a tick and re-read before leaving the app layout.
      desktopTimer = setTimeout(() => {
        desktopTimer = null;
        apply(isMobileNow());
      }, 150);
    };

    update();

    let mq: MediaQueryList | null = null;
    try {
      if (typeof window.matchMedia === "function") {
        mq = window.matchMedia(QUERY);
        if (mq.addEventListener) {
          mq.addEventListener("change", update);
        } else if ("addListener" in mq) {
          (mq as any).addListener(update);
        }
      }
    } catch {
      /* ignore */
    }

    window.addEventListener("resize", update, { passive: true });
    window.addEventListener("orientationchange", update, { passive: true });
    window.visualViewport?.addEventListener("resize", update);

    return () => {
      if (desktopTimer) clearTimeout(desktopTimer);
      try {
        if (mq?.removeEventListener) {
          mq.removeEventListener("change", update);
        } else if (mq && "removeListener" in mq) {
          (mq as any).removeListener(update);
        }
      } catch {
        /* ignore */
      }
      window.removeEventListener("resize", update);
      window.removeEventListener("orientationchange", update);
      window.visualViewport?.removeEventListener("resize", update);
    };
  }, []);

  return mobile;
}
