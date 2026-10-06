/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useRef, useState } from "react";
import { AppBar, Icon, Spinner, useToast } from "@/components/ui";
import { AppBarAction } from "@/components/app/AppChrome";
import { useNavigate } from "react-router-dom";
import { del, get, put, qs } from "@/lib/api";
import { idOf, parseDate } from "@/lib/format";
import { NOTIFICATION_TYPES, notificationHref, notificationMeta, useLiveNotifications } from "@/lib/notifications";

type Filter = { type?: string; read?: boolean };
const LIMIT = 20;
const MON = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const MONTH = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

/** The app's _groupNotificationsByDate labels. */
function groupLabel(d: Date) {
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  const day = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
  if (day === today) return "Today";
  if (day === today - 86400000) return "Yesterday";
  if (day > today - 7 * 86400000) return "This Week";
  return `${MONTH[d.getMonth()]} ${d.getFullYear()}`;
}
/** DateFormat('MMM dd, yyyy • hh:mm a'). */
function stamp(d: Date) {
  const h = d.getHours();
  const two = (n: number) => String(n).padStart(2, "0");
  return `${MON[d.getMonth()]} ${two(d.getDate())}, ${d.getFullYear()} • ${two(h % 12 || 12)}:${two(d.getMinutes())} ${h < 12 ? "AM" : "PM"}`;
}
const TYPE: Record<string, [string, string]> = Object.fromEntries(
  NOTIFICATION_TYPES.map((t) => [t.key, [t.color, t.icon]]),
);

/** The app's NotificationItem: swipe left to delete, tap to mark read. */
function NotificationCard({ n, onTap, onDelete }: { n: any; onTap: () => void; onDelete: () => void }) {
  const meta = notificationMeta(n.type);
  const [typeColor, typeIcon] = TYPE[n.type] ?? [meta.color, meta.icon];
  const unread = !n.read;
  const d = parseDate(n.createdAt) ?? new Date();
  const [dx, setDx] = useState(0);
  const [gone, setGone] = useState(false);
  const [dragging, setDragging] = useState(false);
  const start = useRef<{ x: number; y: number; swiping: boolean } | null>(null);
  const moved = useRef(false);

  const onDown = (e: React.PointerEvent) => {
    start.current = { x: e.clientX, y: e.clientY, swiping: false };
    moved.current = false;
  };
  const onMove = (e: React.PointerEvent) => {
    const s = start.current;
    if (!s) return;
    const x = e.clientX - s.x;
    if (!s.swiping && Math.abs(x) > 8 && Math.abs(x) > Math.abs(e.clientY - s.y)) s.swiping = true;
    if (s.swiping) {
      moved.current = true;
      setDragging(true);
      setDx(Math.min(0, x));
    }
  };
  const onUp = (e: React.PointerEvent) => {
    const w = (e.currentTarget as HTMLElement).offsetWidth;
    start.current = null;
    setDragging(false);
    if (dx < -w * 0.4) {
      setDx(-w - 20);
      setGone(true);
      setTimeout(onDelete, 200);
    } else setDx(0);
  };

  return (
    <div
      className="relative mx-4 my-1 overflow-hidden transition-[max-height,opacity] duration-200"
      style={{ maxHeight: gone ? 0 : 400, opacity: gone ? 0 : 1 }}
    >
      <div className="absolute inset-y-0 left-2 right-0 flex items-center justify-end rounded-2xl bg-[#DC2626] pr-[22px]">
        <Icon name="delete" />
      </div>
      <div
        onPointerDown={onDown}
        onPointerMove={onMove}
        onPointerUp={onUp}
        onPointerCancel={() => {
          setDragging(false);
          setDx(0);
        }}
        onClick={() => !moved.current && onTap()}
        className={`relative flex touch-pan-y items-center overflow-hidden rounded-2xl bg-card active:brightness-110 ${dragging ? "" : "transition-transform duration-200"}`}
        style={{
          transform: `translateX(${dx}px)`,
          boxShadow: `inset 0 0 0 ${unread ? 1.5 : 1}px ${unread ? "#3B82F6" : "rgba(255,255,255,0.08)"}, 0 3px ${unread ? 12 : 8}px rgba(0,0,0,${unread ? 0.06 : 0.03})`,
        }}
      >
        <div className="w-1 self-stretch" style={{ minHeight: 76, background: unread ? "#3B82F6" : `${typeColor}4d` }} />
        <div className="flex min-w-0 flex-1 items-start gap-3 px-3.5 py-3">
          <span
            className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl"
            style={{ background: `${typeColor}1f` }}
          >
            <Icon name={typeIcon} size={22} color={typeColor} />
          </span>
          <div className="min-w-0 flex-1">
            <div className="flex items-center">
              <div className={`flex-1 font-sora text-[14.5px] leading-[1.25] ${unread ? "font-bold" : "font-semibold"}`}>
                {n.title}
              </div>
              {unread && <span className="ml-1.5 h-2 w-2 shrink-0 rounded-full bg-[#10B981]" />}
            </div>
            <div className="mt-1 line-clamp-2 text-[12.5px] font-medium leading-[1.35] text-[#CBD5E1]">{n.body}</div>
            <div className="mt-1.5 flex items-center gap-1 text-[11px] font-medium text-[#8C8C90]">
              <Icon name="schedule" size={13} color="#8C8C90" />
              {stamp(d)}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

/** Notifications at phone width — the app's NotificationsPage (opens on Unread). */
export default function NotificationsApp() {
  const toast = useToast();
  const navigate = useNavigate();
  const { revision, refresh } = useLiveNotifications();
  const seenRevision = useRef(0);
  const [filter, setFilter] = useState<Filter>({ read: false });
  const [items, setItems] = useState<any[]>([]);
  const [unread, setUnread] = useState(0);
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [menu, setMenu] = useState(false);
  const fetching = useRef(false);

  const loadCount = useCallback(async () => {
    const r = await get("/notifications/unread-count");
    if (r.success) setUnread(Number(r.count) || 0);
  }, []);
  const load = useCallback(
    async (p: number, silent = false) => {
      fetching.current = true;
      if (p === 1 && !silent) setLoading(true);
      const r = await get(
        `/notifications${qs({ page: p, limit: LIMIT, type: filter.type, read: filter.read === undefined ? undefined : String(filter.read) })}`,
      );
      fetching.current = false;
      setLoading(false);
      if (!r.success) return setError(r.error || "Failed to fetch notifications");
      setError(null);
      const list: any[] = r.notifications ?? [];
      setItems((prev) => (p === 1 ? list : [...prev, ...list]));
      setPage(p);
      const pg = r.pagination;
      setHasMore(pg ? Number(pg.page ?? p) < Number(pg.pages ?? pg.totalPages ?? 0) : list.length === LIMIT);
    },
    [filter],
  );
  useEffect(() => {
    load(1);
    loadCount();
  }, [load, loadCount]);

  useEffect(() => {
    if (seenRevision.current === revision) return;
    seenRevision.current = revision;
    load(1, true);
    loadCount();
  }, [revision, load, loadCount]);

  // Next page at 90% scrolled.
  useEffect(() => {
    const onScroll = () => {
      const el = document.scrollingElement ?? document.documentElement;
      if (hasMore && !fetching.current && el.scrollTop + el.clientHeight >= el.scrollHeight * 0.9) load(page + 1);
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, [hasMore, page, load]);

  const markRead = async (n: any) => {
    if (n.read) return;
    setItems((l) => l.map((x) => (idOf(x) === idOf(n) ? { ...x, read: true } : x)));
    setUnread((c) => Math.max(0, c - 1));
    await put(`/notifications/${idOf(n)}/read`);
    refresh();
  };
  const open = (n: any) => {
    void markRead(n);
    const href = notificationHref(n);
    if (href) navigate(href);
  };
  const markAll = async () => {
    const r = await put("/notifications/read-all");
    if (r.success) {
      setItems((l) => l.map((x) => ({ ...x, read: true })));
      setUnread(0);
      refresh();
    } else toast(r.error || "Failed");
  };
  const remove = async (n: any) => {
    setItems((l) => l.filter((x) => idOf(x) !== idOf(n)));
    if (!n.read) setUnread((c) => Math.max(0, c - 1));
    const r = await del(`/notifications/${idOf(n)}`);
    refresh();
    if (!r.success) {
      toast(r.error || "Failed to delete");
      load(1);
      loadCount();
    }
  };

  const active = (key: string) =>
    key === "all"
      ? filter.type === undefined && filter.read === undefined
      : key === "unread"
        ? filter.read === false && filter.type === undefined
        : key === "read"
          ? filter.read === true && filter.type === undefined
          : filter.type === key;
  const apply = (key: string) => {
    setMenu(false);
    setFilter(key === "all" ? {} : key === "unread" ? { read: false } : key === "read" ? { read: true } : { type: key });
  };

  const groups: { label: string; list: any[] }[] = [];
  for (const n of items) {
    const label = groupLabel(parseDate(n.createdAt) ?? new Date());
    const g = groups.find((x) => x.label === label);
    if (g) g.list.push(n);
    else groups.push({ label, list: [n] });
  }

  const menuItem = (key: string, label: string) => (
    <button key={key} onClick={() => apply(key)} className="block h-12 w-full px-4 text-left text-sm active:bg-white/10">
      {label}
    </button>
  );

  return (
    <div className="flex min-h-screen flex-col bg-bg">
      <AppBar
        title="Notifications"
        actions={
          <>
            {unread > 0 && <AppBarAction icon="done_all" title="Mark all as read" onClick={markAll} />}
            <div className="relative">
              <AppBarAction icon="tune" title="Filter" onClick={() => setMenu((v) => !v)} />
              {menu && (
                <>
                  <div className="fixed inset-0 z-40" onClick={() => setMenu(false)} />
                  <div className="absolute right-1 top-11 z-50 min-w-[170px] rounded-[14px] bg-field py-2 shadow-lg">
                    {menuItem("unread", "Unread")}
                    {menuItem("read", "Read")}
                    {menuItem("all", "All")}
                    <div className="my-2 h-px bg-white/10" />
                    {NOTIFICATION_TYPES.map((t) => menuItem(t.key, t.label))}
                  </div>
                </>
              )}
            </div>
          </>
        }
      />
      <div className="mx-4 mb-2 mt-3.5 flex items-center rounded-[20px] bg-gradient-to-br from-[#0F172A] to-[#1E3A8A] p-[18px] shadow-[0_6px_16px_rgba(0,0,0,0.12)]">
        <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-[14px] border border-white/25 bg-white/[0.12]">
          <Icon name="notifications_active" size={24} />
        </span>
        <div className="ml-3.5 min-w-0 flex-1">
          <div className="font-sora text-base font-bold">
            {unread > 0 ? `${unread} unread notification${unread === 1 ? "" : "s"}` : "All caught up"}
          </div>
          <div className="mt-[3px] text-xs font-medium text-white/70">
            {unread > 0 ? "Tap a notification to mark it as read" : "No new alerts right now"}
          </div>
        </div>
        {unread > 0 && (
          <span className="rounded-full border border-white/40 bg-white/20 px-2.5 py-[5px] text-[13px] font-bold">
            {unread}
          </span>
        )}
      </div>
      <div className="flex h-11 shrink-0 gap-2 overflow-x-auto px-4 py-1 [scrollbar-width:none]">
        {[
          ["unread", "Unread"],
          ["read", "Read"],
          ["all", "All"],
        ].map(([key, label]) => {
          const on = active(key);
          return (
            <button
              key={key}
              onClick={() => apply(key)}
              className={`shrink-0 rounded-full border px-4 text-[12.5px] font-bold ${on ? "shadow-md" : ""}`}
              style={{
                background: on ? "#3B82F6" : "#14141F",
                borderColor: on ? "#3B82F6" : "rgba(255,255,255,0.08)",
                color: on ? "#fff" : "#CBD5E1",
              }}
            >
              {label}
            </button>
          );
        })}
      </div>
      {loading ? (
        <div className="flex flex-1 items-center justify-center">
          <Spinner size={36} color="#3B82F6" />
        </div>
      ) : error ? (
        <div className="flex flex-1 flex-col items-center justify-center p-8 text-center">
          <span className="flex h-[72px] w-[72px] items-center justify-center rounded-full bg-[#FEE2E2]">
            <Icon name="error" outline size={36} color="#DC2626" />
          </span>
          <div className="mt-5 text-[15px] text-[#64748B]">{error}</div>
          <button
            onClick={() => load(1)}
            className="mt-5 inline-flex h-11 items-center gap-2 rounded-xl bg-accent px-5 text-sm font-semibold"
          >
            <Icon name="refresh" size={18} />
            Retry
          </button>
        </div>
      ) : items.length === 0 ? (
        <div className="flex flex-1 flex-col items-center justify-center p-8 text-center">
          <span className="flex h-20 w-20 items-center justify-center rounded-full bg-accent/15">
            <Icon name="notifications_none" size={40} color="#3B82F6" />
          </span>
          <div className="mt-[18px] font-sora text-xl font-bold">No notifications</div>
          <div className="mt-1.5 text-sm font-medium text-[#8C8C90]">You're all caught up!</div>
        </div>
      ) : (
        <div className="pb-5 pt-1.5">
          {groups.map((g) => (
            <div key={g.label}>
              <div className="flex items-center gap-2 pb-1.5 pl-5 pr-4 pt-3">
                <span className="h-4 w-1 rounded bg-accent" />
                <span className="font-sora text-sm font-bold">{g.label}</span>
              </div>
              {g.list.map((n) => (
                <NotificationCard key={idOf(n)} n={n} onTap={() => open(n)} onDelete={() => remove(n)} />
              ))}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
