/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { ScheduleRow, useScheduleActions } from "@/components/ScheduleRow";
import { Avatar, Empty, ErrorState, Icon, IconButton, Loading, Page, useToast } from "@/components/ui";
import { ModuleGrid } from "@/components/widgets";
import { get } from "@/lib/api";
import {
  fmtDMon,
  fmtTime,
  idOf,
  monthShort,
  sameDay,
  scheduleTimes,
  startOfDay,
  weekday,
  weekdayLong,
} from "@/lib/format";
import { loadAllSchedules, scheduleHref, toggleFavorite, type ScheduleItem } from "@/lib/schedules";
import { PARTICIPANT_MODULES } from "./modules";

/** Day heading with a count, used by the grouped lists. */
function DayHeading({ label, count }: { label: React.ReactNode; count: number }) {
  return (
    <div className="mb-3 flex items-center gap-3">
      <h2 className="text-base font-semibold">{label}</h2>
      <span className="rounded-full bg-white/5 px-2 py-0.5 text-xs font-semibold text-muted">{count}</span>
      <div className="h-px flex-1 bg-line" />
    </div>
  );
}

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
    <Page title="Schedule" subtitle="Every session that hasn't ended yet" width={1000}>
      {error ? (
        <ErrorState message={error} onRetry={load} />
      ) : !items ? (
        <Loading />
      ) : items.length === 0 ? (
        <Empty icon="event_busy" title="No upcoming sessions" />
      ) : (
        byDay(items, (i) => startOfDay(i.start)).map((g) => (
          <div key={g.day?.getTime()} className="mb-8">
            <DayHeading
              label={g.day && sameDay(g.day, new Date()) ? "Today" : g.day && dayHeader(g.day)}
              count={g.list.length}
            />
            <div className="space-y-2.5">
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
        className={`shrink-0 rounded-lg border px-4 py-2 text-left text-sm font-semibold transition ${
          active
            ? "border-accent bg-accent/15 text-white"
            : "border-line text-muted hover:border-white/20 hover:text-white"
        }`}
      >
        {label}
        {sub && <div className="text-[11px] font-normal opacity-80">{sub}</div>}
      </button>
    );
  };

  return (
    <Page
      title={day ? `Day ${days.findIndex((d) => sameDay(d, day)) + 1}` : "All Sessions"}
      subtitle={items ? `${list.length} ${list.length === 1 ? "session" : "sessions"}` : undefined}
      width={1000}
    >
      <div className="mb-5 flex gap-2 overflow-x-auto pb-1">
        {tab("All Sessions", "Every day", null)}
        {days.map((d, i) => tab(`Day ${i + 1}`, fmtDMon(d), d))}
      </div>
      {error ? (
        <ErrorState message={error} />
      ) : !items ? (
        <Loading />
      ) : list.length === 0 ? (
        <Empty icon="event_busy" title="No sessions on this day" />
      ) : (
        <div className="space-y-2.5">
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
    <Page title="Favorites" subtitle="Sessions you've saved" back={false}>
      {error ? (
        <ErrorState message={error} onRetry={load} />
      ) : !schedules ? (
        <Loading />
      ) : sorted.length === 0 ? (
        <Empty icon="favorite" title="No favorites yet" subtitle="Click the heart on a session to save it here." />
      ) : (
        byDay(sorted, (x) => (x.w ? startOfDay(x.w.start) : null)).map((g, gi) => (
          <div key={gi} className="mb-8">
            {g.day && <DayHeading label={dayHeader(g.day)} count={g.list.length} />}
            <div className="grid gap-3 md:grid-cols-2">
              {g.list.map(({ s, w }) => {
                const event = events[String(s.eventId)] ?? { id: s.eventId };
                return (
                  <div
                    key={idOf(s)}
                    onClick={() => navigate(scheduleHref({ event, schedule: s }))}
                    className="card card-hover group flex cursor-pointer items-center gap-3 p-4"
                  >
                    <Avatar src={s.speakerPhoto} name={s.speakerName} size={44} />
                    <div className="min-w-0 flex-1">
                      <div className="text-xs font-semibold text-accent">
                        {w ? `${fmtTime(w.start)} - ${fmtTime(w.end)}` : ""}
                      </div>
                      <div className="truncate font-semibold group-hover:text-[#93C5FD]">{s.scheduleName}</div>
                      <div className="truncate text-xs text-muted">
                        {[s.speakerName, s.hall].filter(Boolean).join(" · ")}
                      </div>
                    </div>
                    <span onClick={(e) => e.stopPropagation()}>
                      <IconButton
                        icon="favorite"
                        title="Remove from favorites"
                        color="#EF4444"
                        onClick={() => unfavorite(s)}
                      />
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
    <Page
      title="Speakers"
      subtitle={speakers ? `${speakers.length} speakers at the conference` : undefined}
      back={false}
    >
      {error ? (
        <ErrorState message={error} />
      ) : !speakers ? (
        <Loading />
      ) : speakers.length === 0 ? (
        <Empty icon="groups" title="No speakers yet" />
      ) : (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {speakers.map((sp, i) => (
            <div key={sp.name} className="card flex flex-col p-5">
              <div className="flex items-center gap-3.5">
                <div className="relative">
                  <Avatar src={sp.photo} name={sp.name.replace(/^Dr\.?\s*/i, "")} size={56} />
                  <span className="absolute -left-1 -top-1 flex h-5 min-w-5 items-center justify-center rounded-full bg-field px-1 text-[10px] font-bold text-muted ring-2 ring-card">
                    {i + 1}
                  </span>
                </div>
                <div className="min-w-0 flex-1">
                  <div className="font-semibold">{sp.name}</div>
                  <div className="text-xs text-muted">
                    {sp.sessions.length === 1 ? "1 session" : `${sp.sessions.length} sessions`}
                  </div>
                </div>
              </div>
              <div className="mt-4 space-y-1.5">
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

/** More: every participant section. */
export function ParticipantMore() {
  return (
    <Page title="All Sections" back={false}>
      <ModuleGrid items={PARTICIPANT_MODULES} />
    </Page>
  );
}
