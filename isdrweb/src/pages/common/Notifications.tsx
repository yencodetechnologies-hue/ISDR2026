/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { Button, Empty, ErrorState, Icon, IconButton, Loading, Page, useToast } from "@/components/ui";
import { del, get, put, qs } from "@/lib/api";
import { fmtTime, idOf, monthLong, parseDate, startOfDay } from "@/lib/format";

type Filter = { key: string; type?: string; read?: boolean };
const FILTERS: (Filter & { label: string })[] = [
  { key: "unread", label: "Unread", read: false },
  { key: "read", label: "Read", read: true },
  { key: "all", label: "All" },
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

  const filterIcon: Record<string, string> = {
    all: "inbox",
    unread: "mark_email_unread",
    read: "drafts",
    message: "chat",
    maintenance: "build",
    complaint: "report",
    notice: "campaign",
  };

  return (
    <Page
      title="Notifications"
      subtitle={
        unread > 0
          ? `${unread} unread · Click a notification to mark it as read`
          : "All caught up · No new alerts right now"
      }
      actions={
        unread > 0 && (
          <Button variant="outline" icon="done_all" onClick={markAll}>
            Mark all as read
          </Button>
        )
      }
      width={1100}
    >
      <div className="grid gap-5 lg:grid-cols-[220px_1fr]">
        <aside className="lg:sticky lg:top-24 lg:self-start">
          <div className="card flex gap-1 overflow-x-auto p-2 lg:flex-col">
            {FILTERS.map((f, i) => (
              <div key={f.key} className="contents">
                {i === 3 && <div className="eyebrow mx-2 mb-1 mt-3 hidden text-[10px] lg:block">By type</div>}
                <button
                  onClick={() => setFilter(f)}
                  className={`flex shrink-0 items-center gap-2.5 rounded-lg px-3 py-2 text-left text-sm font-medium transition ${
                    filter.key === f.key ? "bg-accent/15 text-white" : "text-white/65 hover:bg-white/5 hover:text-white"
                  }`}
                >
                  <Icon
                    name={filterIcon[f.key] ?? "label"}
                    size={18}
                    outline={filter.key !== f.key}
                    color={filter.key === f.key ? "#60A5FA" : undefined}
                  />
                  {f.label}
                </button>
              </div>
            ))}
          </div>
        </aside>
        <div>
          {loading ? (
            <Loading />
          ) : error ? (
            <ErrorState message={error} onRetry={() => load(1)} />
          ) : items.length === 0 ? (
            <Empty icon="notifications_off" title="No notifications" subtitle="You're all caught up!" />
          ) : (
            <div className="space-y-6">
              {groups.map((g) => (
                <div key={g.label}>
                  <div className="eyebrow mb-2">{g.label}</div>
                  <div className="card divide-y divide-line overflow-hidden">
                    {g.list.map((n) => {
                      const d = parseDate(n.createdAt);
                      return (
                        <div
                          key={idOf(n)}
                          onClick={() => markRead(n)}
                          className={`group flex cursor-pointer gap-4 px-5 py-4 transition hover:bg-white/[0.03] ${n.read ? "" : "bg-accent/[0.05]"}`}
                        >
                          <div
                            className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-lg ${n.read ? "bg-white/5" : "bg-accent/15"}`}
                          >
                            <Icon name="notifications" size={20} color={n.read ? "#9CA3AF" : "#60A5FA"} />
                          </div>
                          <div className="min-w-0 flex-1">
                            <div className="flex items-start gap-2">
                              <div
                                className={`flex-1 text-sm ${n.read ? "font-medium text-white/80" : "font-semibold"}`}
                              >
                                {n.title}
                              </div>
                              {d && <div className="shrink-0 text-xs text-muted">{fmtTime(d)}</div>}
                            </div>
                            <div className="mt-0.5 whitespace-pre-wrap text-[13px] text-white/65">{n.body}</div>
                            {d && (
                              <div className="mt-1.5 text-[11px] text-muted">
                                {d.toLocaleDateString("en-US", { month: "short", day: "2-digit", year: "numeric" })}
                              </div>
                            )}
                          </div>
                          <div className="flex flex-col items-center gap-2">
                            {!n.read && <span className="mt-1.5 h-2 w-2 shrink-0 rounded-full bg-accent" />}
                            <span
                              onClick={(e) => e.stopPropagation()}
                              className="opacity-60 transition group-hover:opacity-100"
                            >
                              <IconButton
                                icon="delete"
                                outline
                                title="Delete"
                                color="#EF4444"
                                size={19}
                                onClick={() => remove(n)}
                              />
                            </span>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              ))}
              {hasMore && (
                <div className="flex justify-center">
                  <Button variant="outline" loading={loadingMore} onClick={() => load(page + 1)}>
                    Load more
                  </Button>
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </Page>
  );
}
