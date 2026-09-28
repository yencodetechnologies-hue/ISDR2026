/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { Button, Empty, ErrorState, Icon, IconButton, Loading, Page, useToast } from "@/components/ui";
import { del, get, put, qs } from "@/lib/api";
import { fmtTime, idOf, monthLong, parseDate, startOfDay } from "@/lib/format";

type Filter = { key: string; type?: string; read?: boolean };
const FILTERS: (Filter & { label: string })[] = [
  { key: "all", label: "All" },
  { key: "unread", label: "Unread", read: false },
  { key: "read", label: "Read", read: true },
  { key: "message", label: "Message", type: "message" },
  { key: "maintenance", label: "Maintenance", type: "maintenance" },
  { key: "complaint", label: "Complaint", type: "complaint" },
  { key: "notice", label: "Notice", type: "notice" },
];
const LIMIT = 20;

function groupLabel(d: Date) {
  const today = startOfDay(new Date());
  const diff = Math.round((today.getTime() - startOfDay(d).getTime()) / 86400000);
  if (diff <= 0) return "Today";
  if (diff === 1) return "Yesterday";
  if (diff < 7) return "This Week";
  return `${monthLong(d)} ${d.getFullYear()}`;
}

/** Notifications: filter, mark read (tap), mark all read, delete. */
export default function Notifications() {
  const toast = useToast();
  const [filter, setFilter] = useState<Filter>(FILTERS[0]);
  const [items, setItems] = useState<any[]>([]);
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(false);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [menu, setMenu] = useState(false);

  const load = useCallback(
    async (p: number) => {
      if (p === 1) setLoading(true);
      else setLoadingMore(true);
      const res = await get(
        `/notifications${qs({ page: p, limit: LIMIT, type: filter.type, read: filter.read === undefined ? undefined : String(filter.read) })}`,
      );
      setLoading(false);
      setLoadingMore(false);
      if (!res.success) return setError(res.error || "Failed to fetch notifications");
      setError(null);
      const list: any[] = res.notifications ?? [];
      setItems((prev) => (p === 1 ? list : [...prev, ...list]));
      setPage(p);
      const pg = res.pagination;
      setHasMore(pg ? Number(pg.page ?? p) < Number(pg.pages ?? pg.totalPages ?? 0) : list.length === LIMIT);
    },
    [filter],
  );

  useEffect(() => {
    load(1);
  }, [load]);

  const markRead = async (n: any) => {
    if (n.read) return;
    setItems((l) => l.map((x) => (idOf(x) === idOf(n) ? { ...x, read: true } : x)));
    await put(`/notifications/${idOf(n)}/read`);
  };

  const markAll = async () => {
    const res = await put("/notifications/read-all");
    if (res.success) setItems((l) => l.map((x) => ({ ...x, read: true })));
    else toast(res.error || "Failed", "error");
  };

  const remove = async (n: any) => {
    setItems((l) => l.filter((x) => idOf(x) !== idOf(n)));
    const res = await del(`/notifications/${idOf(n)}`);
    if (!res.success) {
      toast(res.error || "Failed to delete", "error");
      load(1);
    }
  };

  const unread = items.filter((n) => !n.read).length;
  const groups: { label: string; list: any[] }[] = [];
  for (const n of items) {
    const d = parseDate(n.createdAt) ?? new Date();
    const label = groupLabel(d);
    const g = groups.find((x) => x.label === label);
    if (g) g.list.push(n);
    else groups.push({ label, list: [n] });
  }

  return (
    <Page
      title="Notifications"
      actions={
        <>
          {unread > 0 && <IconButton icon="done_all" title="Mark all as read" onClick={markAll} />}
          <div className="relative">
            <IconButton icon="tune" title="Filter" onClick={() => setMenu((m) => !m)} />
            {menu && (
              <div className="absolute right-0 top-11 z-40 w-44 overflow-hidden rounded-xl border border-line bg-field py-1 shadow-xl">
                {FILTERS.map((f) => (
                  <button
                    key={f.key}
                    onClick={() => {
                      setFilter(f);
                      setMenu(false);
                    }}
                    className="flex w-full items-center justify-between px-4 py-2 text-left text-sm hover:bg-white/5"
                  >
                    {f.label}
                    {filter.key === f.key && <Icon name="check" size={18} color="#3B82F6" />}
                  </button>
                ))}
              </div>
            )}
          </div>
        </>
      }
    >
      <div className="mb-3 flex gap-2 overflow-x-auto">
        {FILTERS.slice(0, 3).map((f) => (
          <button
            key={f.key}
            onClick={() => setFilter(f)}
            className={`rounded-full px-4 py-1.5 text-sm font-semibold ${filter.key === f.key ? "bg-accent text-white" : "bg-field text-muted"}`}
          >
            {f.label}
          </button>
        ))}
      </div>
      <div className="mb-3 text-sm text-muted">
        {unread > 0 ? `${unread} unread · Tap a notification to mark it as read` : "All caught up · No new alerts right now"}
      </div>
      {loading ? (
        <Loading />
      ) : error ? (
        <ErrorState message={error} onRetry={() => load(1)} />
      ) : items.length === 0 ? (
        <Empty icon="notifications_off" title="No notifications" subtitle="You're all caught up!" />
      ) : (
        <div className="space-y-5">
          {groups.map((g) => (
            <div key={g.label}>
              <div className="mb-2 text-xs font-bold uppercase tracking-wide text-muted">{g.label}</div>
              <div className="space-y-2">
                {g.list.map((n) => {
                  const d = parseDate(n.createdAt);
                  return (
                    <div
                      key={idOf(n)}
                      onClick={() => markRead(n)}
                      className={`card flex cursor-pointer gap-3 p-3.5 ${n.read ? "opacity-70" : "border-accent/30"}`}
                    >
                      <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-accent/15">
                        <Icon name="notifications" size={20} color="#60A5FA" />
                      </div>
                      <div className="min-w-0 flex-1">
                        <div className="flex items-start gap-2">
                          <div className="flex-1 text-sm font-bold">{n.title}</div>
                          {!n.read && <span className="mt-1.5 h-2 w-2 shrink-0 rounded-full bg-accent" />}
                        </div>
                        <div className="mt-0.5 whitespace-pre-wrap text-[13px] text-white/75">{n.body}</div>
                        {d && (
                          <div className="mt-1 text-[11px] text-muted">
                            {d.toLocaleDateString("en-US", { month: "short", day: "2-digit", year: "numeric" })} • {fmtTime(d)}
                          </div>
                        )}
                      </div>
                      <span onClick={(e) => e.stopPropagation()}>
                        <IconButton icon="delete" outline title="Delete" color="#EF4444" size={20} onClick={() => remove(n)} />
                      </span>
                    </div>
                  );
                })}
              </div>
            </div>
          ))}
          {hasMore && (
            <Button variant="outline" full loading={loadingMore} onClick={() => load(page + 1)}>
              Load more
            </Button>
          )}
        </div>
      )}
    </Page>
  );
}
