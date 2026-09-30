/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { AppPage } from "@/components/app/AppChrome";
import { AppSearchField, AppSpinner, AppSquareButton, AppSwitch } from "@/components/app/AppControls";
import { Icon } from "@/components/ui";
import { get, put } from "@/lib/api";
import { idOf, parseDate } from "@/lib/format";

const WEEK = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const MON = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

/** "Mon, 28 Sep 2026 · 9:00 AM" — the app's _whenLabel. */
function whenLabel(e: any) {
  const d = parseDate(e.eventDate);
  if (!d) return "—";
  const h = d.getHours();
  const time = `${h % 12 || 12}:${String(d.getMinutes()).padStart(2, "0")} ${h < 12 ? "AM" : "PM"}`;
  return `${WEEK[d.getDay()]}, ${d.getDate()} ${MON[d.getMonth()]} ${d.getFullYear()} · ${time}`;
}

const isActiveEvent = (e: any) => e.isActive !== false && String(e.status ?? "") !== "cancelled";

/** Events at phone width — the app's ManagedEventsTab. */
export default function EventsApp() {
  const navigate = useNavigate();
  const [events, setEvents] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [toggling, setToggling] = useState<Set<string>>(new Set());

  const load = useCallback(async () => {
    setLoading(true);
    setMessage(null);
    const res = await get("/managed-events");
    setLoading(false);
    if (res.success) setEvents(res.events ?? []);
    else setMessage(res.error || "Failed to load");
  }, []);
  useEffect(() => {
    load();
  }, [load]);

  const toggleActive = async (e: any, active: boolean) => {
    const id = idOf(e);
    if (!id || toggling.has(id)) return;
    setToggling((s) => new Set(s).add(id));
    setEvents((l) => l.map((x) => (idOf(x) === id ? { ...x, isActive: active } : x)));
    const res = await put(`/managed-events/${id}`, {
      isActive: active,
      ...(active && e.status === "cancelled" ? { status: "published" } : {}),
    });
    setToggling((s) => {
      const n = new Set(s);
      n.delete(id);
      return n;
    });
    if (!res.success) {
      setMessage(res.error || "Failed to update status");
      load();
      return;
    }
    if (res.event) setEvents((l) => l.map((x) => (idOf(x) === id ? res.event : x)));
  };

  const q = search.trim().toLowerCase();
  const filtered = !q
    ? events
    : events.filter((e) =>
        [e.title, e.venue, e.status, isActiveEvent(e) ? "active" : "inactive"].some((v) =>
          String(v ?? "")
            .toLowerCase()
            .includes(q),
        ),
      );

  return (
    <AppPage title="Events" pad={false}>
      <div className="flex items-center gap-2.5 px-4 py-3">
        <AppSearchField value={search} onChange={setSearch} placeholder="Search by title, venue, status..." />
        <AppSquareButton icon="add" title="Create event" onClick={() => navigate("/admin/events/new")} />
      </div>
      {message && <div className="px-4 pb-2 text-[13px] font-semibold text-accent">{message}</div>}
      {loading ? (
        <AppSpinner />
      ) : events.length === 0 ? (
        <div className="px-6 pt-16 text-center">
          <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-full bg-accent/[0.06]">
            <Icon name="confirmation_number" outline size={30} color="#3B82F6" />
          </div>
          <div className="mt-4 font-sora text-[17px] font-bold">No events yet</div>
          <div className="mx-auto mt-2 max-w-xs px-5 text-[13px] leading-[1.4] text-muted">
            Tap + to create an event and share the register link.
          </div>
          <button
            onClick={() => navigate("/admin/events/new")}
            className="mt-6 inline-flex items-center gap-2 rounded-xl bg-accent px-6 py-3.5 font-sora text-sm font-semibold shadow-md"
          >
            <Icon name="add" size={20} />
            Create event
          </button>
        </div>
      ) : filtered.length === 0 ? (
        <div className="px-6 pt-[72px] text-center text-sm text-muted">No events match your search.</div>
      ) : (
        <div className="space-y-3 px-4 pb-6 pt-1">
          {filtered.map((e) => {
            const id = idOf(e);
            const active = isActiveEvent(e);
            return (
              <div
                key={id}
                onClick={() => navigate(`/admin/events/${id}`)}
                className="flex cursor-pointer items-center rounded-2xl border border-white/[0.08] bg-card p-3.5 shadow-[0_3px_10px_rgba(0,0,0,0.02)] active:bg-white/[0.03]"
              >
                {e.photoUrl ? (
                  <img src={e.photoUrl} alt="" className="h-[52px] w-[52px] shrink-0 rounded-xl object-cover" />
                ) : (
                  <span className="flex h-[52px] w-[52px] shrink-0 items-center justify-center rounded-xl border border-white/10 bg-field">
                    <Icon name="calendar_month" size={24} color="#E2E8F0" />
                  </span>
                )}
                <div className="ml-3 min-w-0 flex-1">
                  <div className="font-sora text-[15px] font-bold">{e.title || "Event"}</div>
                  <div className="mt-1 text-xs font-medium text-muted">{whenLabel(e)}</div>
                  <div className="mt-1 flex items-center">
                    <span className="rounded-md bg-field px-[7px] py-0.5 text-[11px] font-semibold text-[#CBD5E1]">
                      {e.bookedCount ?? 0} registered
                    </span>
                    {e.status && <span className="ml-1.5 text-[11px] font-medium text-[#94A3B8]">· {e.status}</span>}
                  </div>
                </div>
                <div className="ml-2 flex flex-col items-center" onClick={(ev) => ev.stopPropagation()}>
                  <AppSwitch
                    checked={active}
                    disabled={toggling.has(id) || e.status === "cancelled"}
                    onChange={(v) => toggleActive(e, v)}
                  />
                  <span className={`mt-1 text-[10px] font-bold ${active ? "text-[#10B981]" : "text-[#94A3B8]"}`}>
                    {active ? "Active" : "Inactive"}
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </AppPage>
  );
}
