/* eslint-disable @typescript-eslint/no-explicit-any */
import { useEffect, useState } from "react";

/** Below the website's `lg` breakpoint (1024px) pages use the app's phone layout; at and above it, the desktop website. */
const QUERY = "(max-width: 1023.98px)";

export function isMobileNow(): boolean {
  if (typeof window === "undefined") return false;
  return window.innerWidth < 1024 || (typeof window.matchMedia === "function" && window.matchMedia(QUERY).matches);
}

/** True at phone / tablet width (< 1024px) — the website then renders the app's screens. */
export function useMobile(): boolean {
  const [mobile, setMobile] = useState(isMobileNow);

  useEffect(() => {
    const update = () => {
      setMobile(isMobileNow());
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

    return () => {
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
    };
  }, []);

  return mobile;
}
