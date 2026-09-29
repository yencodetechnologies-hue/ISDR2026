import { useEffect, useState } from "react";
import { Icon, useToast } from "@/components/ui";

/**
 * Best-effort screenshot protection for the QR pass on desktop browsers (the app
 * uses the OS-level ScreenProtector; a web page can't block the OS screenshot).
 * The pass is hidden:
 *  - when a screenshot key is pressed (PrintScreen, Win/Cmd+Shift+S/3/4/5), and the
 *    clipboard is overwritten so a PrintScreen copy doesn't hold the pass;
 *  - while the window is not focused or the tab is hidden (the Snipping Tool /
 *    screen-capture overlays take focus);
 *  - when printing.
 * Right-click, drag and text selection are disabled on the pass.
 */
export default function ScreenshotGuard({ children }: { children: React.ReactNode }) {
  const toast = useToast();
  const [hidden, setHidden] = useState(() => typeof document !== "undefined" && !document.hasFocus());

  useEffect(() => {
    let timer: ReturnType<typeof setTimeout> | undefined;
    const hideFor = (ms: number) => {
      setHidden(true);
      clearTimeout(timer);
      timer = setTimeout(() => setHidden(!document.hasFocus() || document.hidden), ms);
    };
    const blocked = () => {
      hideFor(1500);
      navigator.clipboard?.writeText("").catch(() => {});
      toast("Screenshots are not allowed on the QR Pass", "error");
    };
    const onKey = (e: KeyboardEvent) => {
      const k = e.key.toLowerCase();
      const combo = (e.metaKey || e.ctrlKey) && e.shiftKey && ["s", "3", "4", "5"].includes(k);
      if (k === "printscreen" || e.code === "PrintScreen" || combo) {
        e.preventDefault();
        blocked();
      } else if ((e.ctrlKey || e.metaKey) && (k === "p" || k === "s")) {
        // Print / save page.
        e.preventDefault();
        toast("Printing or saving the QR Pass is not allowed", "error");
      }
    };
    const onBlur = () => setHidden(true);
    const onFocus = () => {
      clearTimeout(timer);
      setHidden(document.hidden);
    };
    const onVisibility = () => setHidden(document.hidden || !document.hasFocus());

    window.addEventListener("keydown", onKey, true);
    window.addEventListener("keyup", onKey, true);
    window.addEventListener("blur", onBlur);
    window.addEventListener("focus", onFocus);
    document.addEventListener("visibilitychange", onVisibility);
    return () => {
      clearTimeout(timer);
      window.removeEventListener("keydown", onKey, true);
      window.removeEventListener("keyup", onKey, true);
      window.removeEventListener("blur", onBlur);
      window.removeEventListener("focus", onFocus);
      document.removeEventListener("visibilitychange", onVisibility);
    };
  }, [toast]);

  return (
    <div
      className="screenshot-guard relative select-none"
      onContextMenu={(e) => e.preventDefault()}
      onDragStart={(e) => e.preventDefault()}
      onCopy={(e) => e.preventDefault()}
    >
      <div style={hidden ? { filter: "blur(24px)", opacity: 0.15 } : undefined}>{children}</div>
      {hidden && (
        <button
          type="button"
          onClick={() => window.focus()}
          className="absolute inset-0 flex flex-col items-center justify-center gap-2 rounded-xl bg-black/70 text-center text-sm font-semibold text-white/80"
        >
          <Icon name="visibility_off" size={34} />
          Pass hidden for security
          <span className="text-xs font-normal text-white/55">Click here to show it again</span>
        </button>
      )}
    </div>
  );
}
