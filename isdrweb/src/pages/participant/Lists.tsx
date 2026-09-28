/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { ScheduleRow, useScheduleActions } from "@/components/ScheduleRow";
import { Avatar, Empty, ErrorState, Icon, IconButton, Loading, Page, useToast } from "@/components/ui";
import { BottomNav, ModuleGrid } from "@/components/widgets";
import { get } from "@/lib/api";
import { fmtDMon, fmtTime, idOf, monthShort, sameDay, scheduleTimes, startOfDay, weekday, weekdayLong } from "@/lib/format";
import { loadAllSchedules, scheduleHref, toggleFavorite, type ScheduleItem } from "@/lib/schedules";
import { HOME_SLOTS, PARTICIPANT_MODULES, participantNav } from "./modules";

const dayHeader = (d: Date) => `${weekdayLong(d)}, ${d.getDate()} ${monthShort(d)}`;

/** Group consecutive items by calendar day. */
function byDay<T>(list: T[], dayOf: (t: T) => Date | null) {
  const groups: { day: Date | null; list: T[] }[] = [];
  for (const t of list) {
    const d = dayOf(t);
    const last = groups[groups.length - 1];
    if (last && ((d && last.day && sameDay(d, last.day)) || (!d && !last.day))) last.list.push(t);
    else groups.push({ day: d, list: [t] });
  }
  return groups;
}

/** Schedule: every session that hasn't ended yet, grouped by day. */
export function UpcomingSchedules() {
  const actions = useScheduleActions();
  const [items, setItems] = useState<ScheduleItem[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const load = useCallback(async () => {
    const r = await loadAllSchedules();
    if (r.error) return setError(r.error || "Could not load schedules");
    const now = new Date();
    setError(null);
    setItems(r.items.filter((i) => i.end > now));
  }, []);
  useEffect(() => {
    load();
  }, [load]);
  return (
    <Page title="Schedule">
      {error ? (
        <ErrorState message={error} onRetry={load} />
      ) : !items ? (
        <Loading />
      ) : items.length === 0 ? (
        <Empty icon="event_busy" title="No upcoming sessions" />
      ) : (
        byDay(items, (i) => startOfDay(i.start)).map((g) => (
          <div key={g.day?.getTime()} className="mb-5">
            <div className="mb-2 text-sm font-bold text-white/80">{g.day && sameDay(g.day, new Date()) ? "Today" : g.day && dayHeader(g.day)}</div>
            <div className="space-y-2">
              {g.list.map((it) => (
                <ScheduleRow key={idOf(it.schedule)} item={it} actions={actions} />
              ))}
            </div>
          </div>
        ))
      )}
      {actions.sheet}
    </Page>
  );
}

/** All Sessions with day tabs (All Sessions / Day 1 / Day 2 …). */
export function AllSessions() {
  const [params, setParams] = useSearchParams();
  const actions = useScheduleActions();
  const [items, setItems] = useState<ScheduleItem[] | null>(null);
  const [days, setDays] = useState<Date[]>([]);
  const [error, setError] = useState<string | null>(null);
  const dayParam = params.get("day");
  const day = dayParam ? new Date(Number(dayParam)) : null;

  useEffect(() => {
    loadAllSchedules().then((r) => {
      if (r.error) return setError(r.error);
      setItems(r.items);
      setDays(
        r.days.length
          ? r.days
          : [...new Map(r.items.map((i) => [startOfDay(i.start).getTime(), startOfDay(i.start)])).values()].sort(
              (a, b) => a.getTime() - b.getTime(),
            ),
      );
    });
  }, []);

  const list = (items ?? []).filter((i) => !day || sameDay(i.start, day));
  const tab = (label: string, sub: string | null, d: Date | null) => {
    const active = (!d && !day) || (d && day && sameDay(d, day));
    return (
      <button
        key={label}
        onClick={() => setParams(d ? { day: String(d.getTime()) } : {}, { replace: true })}
        className={`shrink-0 rounded-xl px-4 py-2 text-center text-sm font-semibold ${active ? "bg-accent text-white" : "bg-field text-muted"}`}
      >
        {label}
        {sub && <div className="text-[10.5px] font-normal opacity-80">{sub}</div>}
      </button>
    );
  };

  return (
    <Page title={day ? `Day ${days.findIndex((d) => sameDay(d, day)) + 1}` : "All Sessions"}>
      <div className="mb-4 flex gap-2 overflow-x-auto pb-1">
        {tab("All Sessions", null, null)}
        {days.map((d, i) => tab(`Day ${i + 1}`, fmtDMon(d), d))}
      </div>
      {error ? (
        <ErrorState message={error} />
      ) : !items ? (
        <Loading />
      ) : list.length === 0 ? (
        <Empty icon="event_busy" title="No sessions on this day" />
      ) : (
        <div className="space-y-2">
          {list.map((it) => (
            <ScheduleRow key={idOf(it.schedule)} item={it} actions={actions} showDate={!day} />
          ))}
        </div>
      )}
      {actions.sheet}
    </Page>
  );
}

/** Favorites: hearted sessions by day; un-heart removes them. */
export function Favorites() {
  const navigate = useNavigate();
  const toast = useToast();
  const [schedules, setSchedules] = useState<any[] | null>(null);
  const [events, setEvents] = useState<Record<string, any>>({});
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    const res = await get("/managed-events/my-favorites");
    if (!res.success) return setError(res.error || "Could not load favorites");
    setError(null);
    setSchedules(res.schedules ?? []);
    setEvents(res.events && typeof res.events === "object" ? res.events : {});
  }, []);
  useEffect(() => {
    load();
  }, [load]);

  const unfavorite = async (s: any) => {
    setSchedules((l) => (l ?? []).filter((x) => idOf(x) !== idOf(s)));
    const res = await toggleFavorite(idOf(s));
    if (!res.success) {
      toast(res.error || "Could not update", "error");
      load();
    }
  };

  const sorted = [...(schedules ?? [])]
    .map((s) => ({ s, w: scheduleTimes(s) }))
    .sort((a, b) => (a.w?.start.getTime() ?? 0) - (b.w?.start.getTime() ?? 0));

  return (
    <Page title="Favorites" bottom={<BottomNav items={participantNav} active={1} />}>
      {error ? (
        <ErrorState message={error} onRetry={load} />
      ) : !schedules ? (
        <Loading />
      ) : sorted.length === 0 ? (
        <Empty icon="favorite" title="No favorites yet" subtitle="Tap the heart on a session to save it here." />
      ) : (
        byDay(sorted, (x) => (x.w ? startOfDay(x.w.start) : null)).map((g, gi) => (
          <div key={gi} className="mb-5">
            {g.day && <div className="mb-2 text-sm font-bold text-white/80">{dayHeader(g.day)}</div>}
            <div className="space-y-2">
              {g.list.map(({ s, w }) => {
                const event = events[String(s.eventId)] ?? { id: s.eventId };
                return (
                  <div
                    key={idOf(s)}
                    onClick={() => navigate(scheduleHref({ event, schedule: s }))}
                    className="card flex cursor-pointer items-center gap-3 p-3 hover:bg-[#191926]"
                  >
                    <Avatar src={s.speakerPhoto} name={s.speakerName} size={42} />
                    <div className="min-w-0 flex-1">
                      <div className="text-xs font-semibold text-accent">
                        {w ? `${fmtTime(w.start)} - ${fmtTime(w.end)}` : ""}
                        {s.speakerName && <span className="text-white/60"> · {s.speakerName}</span>}
                      </div>
                      <div className="truncate text-sm font-bold">{s.scheduleName}</div>
                      {s.hall && <div className="text-[11px] text-white/45">{s.hall}</div>}
                    </div>
                    <span onClick={(e) => e.stopPropagation()}>
                      <IconButton icon="favorite" title="Remove from favorites" color="#EF4444" onClick={() => unfavorite(s)} />
                    </span>
                  </div>
                );
              })}
            </div>
          </div>
        ))
      )}
    </Page>
  );
}

/** Speakers: everyone with a session, numbered, with their sessions listed. */
export function Speakers() {
  const navigate = useNavigate();
  const [speakers, setSpeakers] = useState<{ name: string; photo: string; sessions: ScheduleItem[] }[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  useEffect(() => {
    loadAllSchedules().then((r) => {
      if (r.error) return setError(r.error || "Could not load speakers");
      const map = new Map<string, { name: string; photo: string; sessions: ScheduleItem[] }>();
      for (const it of r.items) {
        const name = String(it.schedule.speakerName ?? "").trim();
        if (!name) continue;
        const key = name.toLowerCase();
        if (!map.has(key)) map.set(key, { name, photo: String(it.schedule.speakerPhoto ?? ""), sessions: [] });
        map.get(key)!.sessions.push(it);
      }
      setSpeakers([...map.values()]);
    });
  }, []);
  return (
    <Page title="Speakers" bottom={<BottomNav items={participantNav} active={2} />}>
      {error ? (
        <ErrorState message={error} />
      ) : !speakers ? (
        <Loading />
      ) : speakers.length === 0 ? (
        <Empty icon="groups" title="No speakers yet" />
      ) : (
        <div className="space-y-2.5">
          {speakers.map((sp, i) => (
            <div key={sp.name} className="card p-3">
              <div className="flex items-center gap-3">
                <span className="w-6 text-center text-sm font-bold text-muted">{i + 1}</span>
                <Avatar src={sp.photo} name={sp.name.replace(/^Dr\.?\s*/i, "")} size={46} />
                <div className="min-w-0 flex-1">
                  <div className="font-bold">{sp.name}</div>
                  <div className="text-xs text-muted">{sp.sessions.length === 1 ? "1 session" : `${sp.sessions.length} sessions`}</div>
                </div>
              </div>
              <div className="mt-2 space-y-1.5 pl-9">
                {sp.sessions.map((s) => (
                  <button
                    key={idOf(s.schedule)}
                    onClick={() => navigate(scheduleHref(s))}
                    className="flex w-full items-center gap-2 rounded-lg bg-field px-3 py-2 text-left hover:bg-white/10"
                  >
                    <div className="min-w-0 flex-1">
                      <div className="truncate text-sm font-semibold">{s.schedule.scheduleName}</div>
                      <div className="text-[11.5px] text-muted">
                        {weekday(s.start)}, {s.start.getDate()} {monthShort(s.start)} · {fmtTime(s.start)}
                        {s.schedule.hall ? ` · ${s.schedule.hall}` : ""}
                      </div>
                    </div>
                    <Icon name="chevron_right" size={18} color="#9CA3AF" />
                  </button>
                ))}
              </div>
            </div>
          ))}
        </div>
      )}
    </Page>
  );
}

/** More: the modules that don't fit in the home grid. */
export function ParticipantMore() {
  const overflow = PARTICIPANT_MODULES.length > HOME_SLOTS + 1 ? PARTICIPANT_MODULES.slice(HOME_SLOTS) : [];
  return (
    <Page title="More" bottom={<BottomNav items={participantNav} active={4} />}>
      <div className="card p-2">
        <ModuleGrid items={overflow} cols="grid-cols-3 sm:grid-cols-4" />
      </div>
    </Page>
  );
}
