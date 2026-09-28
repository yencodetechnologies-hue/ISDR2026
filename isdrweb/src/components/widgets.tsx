/* eslint-disable @typescript-eslint/no-explicit-any, react-refresh/only-export-components */
import { useEffect, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import { get } from "@/lib/api";
import { REMINDER_CHOICES, reminderLabel } from "@/lib/schedules";
import { Icon, IconButton, Modal } from "./ui";

/** Bell with the unread count; opens Notifications. */
export function NotificationBell() {
  const navigate = useNavigate();
  const location = useLocation();
  const [count, setCount] = useState(0);
  useEffect(() => {
    let alive = true;
    const load = () =>
      get("/notifications/unread-count").then((r) => {
        if (alive && r.success) setCount(Number(r.count) || 0);
      });
    load();
    const t = setInterval(load, 60000);
    return () => {
      alive = false;
      clearInterval(t);
    };
  }, [location.pathname]);
  return <IconButton icon="notifications" outline title="Notifications" badge={count} onClick={() => navigate("/notifications")} />;
}

/** Ticker text from the admin's lines (one message per line). */
export function tickerTextFromLines(text: string) {
  const lines = text
    .split("\n")
    .map((l) => l.trim())
    .filter(Boolean);
  return lines.length ? `${lines.join("  •  ")}  •  ` : "";
}

/** Scrolling strap with the admin's news ticker (hidden when off / empty). Refreshes every minute. */
export function NewsTicker() {
  const [text, setText] = useState<string | null>(null);
  useEffect(() => {
    let alive = true;
    const load = () =>
      get("/news-ticker").then((r) => {
        if (!alive || !r.success || !r.ticker) return;
        const t = r.ticker.enabled === false ? "" : tickerTextFromLines(String(r.ticker.text ?? ""));
        setText(t || null);
      });
    load();
    const id = setInterval(load, 60000);
    return () => {
      alive = false;
      clearInterval(id);
    };
  }, []);
  if (!text) return null;
  const secs = Math.max(12, text.length * 0.18);
  return (
    <div className="flex items-center overflow-hidden rounded-xl bg-[#1E3A8A]">
      <span className="z-10 flex shrink-0 items-center gap-1 bg-[#1D4ED8] px-3 py-2 text-xs font-bold">
        <Icon name="campaign" size={16} />
        NEWS
      </span>
      <div className="relative flex-1 overflow-hidden py-2">
        <div className="flex w-max whitespace-nowrap text-[13px] font-medium" style={{ animation: `ticker ${secs}s linear infinite` }}>
          <span className="pr-10">{text}</span>
          <span className="pr-10">{text}</span>
        </div>
      </div>
    </div>
  );
}

/** "LIVE — Watch on YouTube" capsule when the admin has set a live URL. */
export function YoutubeLiveCapsule() {
  const [url, setUrl] = useState("");
  useEffect(() => {
    get("/youtube-live").then((r) => r.success && setUrl(String(r.url ?? "")));
  }, []);
  if (!url) return null;
  return (
    <a
      href={url}
      target="_blank"
      rel="noreferrer"
      className="mb-3 flex items-center gap-3 rounded-2xl border border-red-500/30 bg-red-500/10 px-4 py-3 hover:bg-red-500/15"
    >
      <span className="flex items-center gap-1.5 rounded-full bg-red-600 px-2 py-0.5 text-[11px] font-extrabold">
        <span className="h-1.5 w-1.5 rounded-full bg-white" />
        LIVE
      </span>
      <span className="flex-1 text-sm font-semibold">Watch on YouTube</span>
      <Icon name="open_in_new" size={18} color="#FCA5A5" />
    </a>
  );
}

/** Auto-scrolling image banner. */
export function BannerCarousel({ urls, height = 160 }: { urls: string[]; height?: number }) {
  const [i, setI] = useState(0);
  useEffect(() => {
    if (urls.length < 2) return;
    const t = setInterval(() => setI((x) => (x + 1) % urls.length), 4000);
    return () => clearInterval(t);
  }, [urls.length]);
  if (!urls.length) return null;
  const idx = i % urls.length;
  return (
    <div className="relative overflow-hidden rounded-2xl" style={{ height }}>
      <div className="flex h-full transition-transform duration-500" style={{ transform: `translateX(-${idx * 100}%)` }}>
        {urls.map((u) => (
          <img key={u} src={u} alt="" className="h-full w-full shrink-0 object-cover" />
        ))}
      </div>
      {urls.length > 1 && (
        <div className="absolute inset-x-0 bottom-2 flex justify-center gap-1.5">
          {urls.map((u, k) => (
            <button
              key={u}
              onClick={() => setI(k)}
              className="h-1.5 rounded-full bg-white transition-all"
              style={{ width: k === idx ? 16 : 6, opacity: k === idx ? 1 : 0.5 }}
            />
          ))}
        </div>
      )}
    </div>
  );
}

/** The admin's home banner images (Admin → Banner); empty when switched off. Refreshes every 30 s. */
export function useHomeBanner() {
  const [urls, setUrls] = useState<string[]>([]);
  useEffect(() => {
    let alive = true;
    const load = () =>
      get("/home-banner").then((r) => {
        if (!alive || !r.success || !r.banner) return;
        const next =
          r.banner.enabled === false
            ? []
            : ((r.banner.images as any[]) ?? []).map((x) => String(x?.url ?? "")).filter(Boolean);
        setUrls((prev) => (prev.join() === next.join() ? prev : next));
      });
    load();
    const t = setInterval(load, 30000);
    return () => {
      alive = false;
      clearInterval(t);
    };
  }, []);
  return urls;
}

/** "Remind me" picker: resolves minutes-before, -1 to turn off, or null when dismissed. */
export function ReminderSheet({
  open,
  scheduleName,
  start,
  current,
  onPick,
  onClose,
}: {
  open: boolean;
  scheduleName: string;
  start: Date | null;
  current: number | undefined;
  onPick: (minutes: number) => void;
  onClose: () => void;
}) {
  const now = new Date().getTime();
  return (
    <Modal
      open={open}
      onClose={onClose}
      title={
        <span className="flex items-center gap-2">
          <Icon name="notifications_active" color="#FBBF24" />
          Remind me
        </span>
      }
      width={420}
    >
      <div className="-mt-2 mb-2 truncate text-xs text-white/60">{scheduleName}</div>
      {REMINDER_CHOICES.map((m) => {
        const open = start ? start.getTime() - m * 60000 > now : false;
        const selected = current === m;
        return (
          <button
            key={m}
            disabled={!open}
            onClick={() => onPick(m)}
            className="flex w-full items-center gap-3 rounded-xl px-3 py-3 text-left text-sm hover:bg-white/5 disabled:opacity-30"
          >
            <Icon name={m === 0 ? "play_circle" : "schedule"} outline color="#60A5FA" />
            <span className={`flex-1 ${selected ? "font-bold" : ""}`}>{reminderLabel(m)}</span>
            {selected && <Icon name="check_circle" color="#22C55E" />}
          </button>
        );
      })}
      {current !== undefined && (
        <button onClick={() => onPick(-1)} className="flex w-full items-center gap-3 rounded-xl px-3 py-3 text-left text-sm font-semibold text-[#F87171] hover:bg-white/5">
          <Icon name="notifications_off" outline color="#F87171" />
          Turn off reminder
        </button>
      )}
    </Modal>
  );
}

export type NavItem = { label: string; icon: string; to?: string; onClick?: () => void };

/** Fixed bottom navigation bar. */
export function BottomNav({ items, active }: { items: NavItem[]; active: number }) {
  const navigate = useNavigate();
  return (
    <nav className="fixed inset-x-0 bottom-0 z-30 border-t border-line bg-bg/95 backdrop-blur">
      <div className="mx-auto flex h-16 max-w-[760px]">
        {items.map((it, i) => (
          <button
            key={it.label}
            onClick={() => (it.onClick ? it.onClick() : it.to && navigate(it.to))}
            className="flex flex-1 flex-col items-center justify-center gap-0.5 text-[11px] font-semibold"
            style={{ color: i === active ? "#60A5FA" : "#9CA3AF" }}
          >
            <Icon name={it.icon} size={24} outline={i !== active} />
            {it.label}
          </button>
        ))}
      </div>
    </nav>
  );
}

export type ModuleItem = { label: string; icon: string; color: string; to?: string; onClick?: () => void };

/** Grid of module tiles. */
export function ModuleGrid({ items, cols = "grid-cols-4 sm:grid-cols-6" }: { items: ModuleItem[]; cols?: string }) {
  const navigate = useNavigate();
  return (
    <div className={`grid gap-2 ${cols}`}>
      {items.map((m) => (
        <button
          key={m.label}
          onClick={() => (m.onClick ? m.onClick() : m.to && navigate(m.to))}
          className="flex flex-col items-center gap-1.5 rounded-xl px-1 py-3 hover:bg-white/5"
        >
          <span className="flex h-12 w-12 items-center justify-center rounded-2xl" style={{ background: `${m.color}22` }}>
            <Icon name={m.icon} size={26} color={m.color} />
          </span>
          <span className="text-center text-[11.5px] font-medium leading-tight text-white/85">{m.label}</span>
        </button>
      ))}
    </div>
  );
}

export function SectionTitle({ children, action }: { children: React.ReactNode; action?: React.ReactNode }) {
  return (
    <div className="mb-2.5 mt-6 flex items-center gap-2">
      <div className="flex-1 text-[13px] font-extrabold uppercase tracking-wide text-white/85">{children}</div>
      {action}
    </div>
  );
}
