/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { AppBar, Avatar, Icon, useToast } from "@/components/ui";
import { AppSpinner } from "@/components/app/AppControls";
import { get } from "@/lib/api";
import { fmtDMon, idOf, monthShort, sameDay, weekday, weekdayLong } from "@/lib/format";
import {
  displaySpeaker,
  groupByHall,
  loadAllSchedules,
  compareScheduleItems,
  participantTimeLabel,
  openAsItem,
  scheduleHref,
  splitSpeakerNames,
  toggleFavorite,
  type OpenSession,
  type ScheduleItem,
} from "@/lib/schedules";

/* ------------------------------------------------------------------ */
/* 1. Upcoming Schedules (Screen 3)                                     */
/* ------------------------------------------------------------------ */

export function UpcomingSchedulesApp() {
  const navigate = useNavigate();
  const [items, setItems] = useState<ScheduleItem[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    const res = await loadAllSchedules();
    if (res.error) return setError(res.error || "Could not load schedules");
    const now = new Date();
    setError(null);
    setItems(res.items.filter((i) => i.end > now).sort(compareScheduleItems));
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const now = new Date();
  const byDays: { day: Date; list: ScheduleItem[] }[] = [];
  if (items) {
    for (const it of items) {
      const d = new Date(it.start.getFullYear(), it.start.getMonth(), it.start.getDate());
      const last = byDays[byDays.length - 1];
      if (last && sameDay(last.day, d)) last.list.push(it);
      else byDays.push({ day: d, list: [it] });
    }
  }

  return (
    <div className="min-h-screen bg-[#0A0A12] text-white">
      <AppBar title="Upcoming Schedules" outfit titleClassName="!text-left font-outfit text-[18px] font-bold" />
      <div className="px-4 pb-12 pt-2">
        {!items && !error ? (
          <div className="py-24">
            <AppSpinner />
          </div>
        ) : error || !items || items.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-28 text-center">
            <Icon name="event_note" size={44} color="#9CA3AF" />
            <div className="mt-3 font-outfit text-[17px] font-bold">
              {error || "No upcoming sessions"}
            </div>
            <div className="mt-1 text-xs text-muted">Check back later for newly scheduled sessions.</div>
          </div>
        ) : (
          byDays.map((group) => {
            const isToday = sameDay(group.day, now);
            return (
              <div key={group.day.getTime()} className="mb-6">
                <div className="mb-2 font-inter text-[12.5px] font-bold text-muted">
                  {isToday
                    ? `Today · ${group.day.getDate()} ${monthShort(group.day)}`
                    : `${weekdayLong(group.day)}, ${group.day.getDate()} ${monthShort(group.day)}`}
                </div>
                <div className="space-y-4">
                  {groupByHall(group.list, (it) => String(it.schedule.hall ?? "")).map((hallGroup, hallIndex) => (
                    <div key={`${hallGroup.hall}-${hallIndex}`}>
                      <div className="mb-2 flex items-center gap-1.5 font-inter text-[12px] font-bold text-[#93C5FD]">
                        <Icon name="location_on" size={14} />
                        {hallGroup.hall}
                      </div>
                      <div className="space-y-2.5">
                  {hallGroup.list.map((it) => {
                    const s = it.schedule ?? {};
                    const isLive = now >= it.start && now < it.end;
                    const speaker = displaySpeaker(s.speakerName);

                    return (
                      <div
                        key={idOf(s)}
                        onClick={() => navigate(scheduleHref(it))}
                        className="group cursor-pointer rounded-[14px] border border-white/[0.08] bg-[#14141F] p-3.5 transition active:scale-[0.99]"
                        style={{ borderColor: isLive ? "rgba(34,197,94,0.5)" : "rgba(255,255,255,0.08)" }}
                      >
                        <div className="flex items-start justify-between gap-2">
                          <div className="min-w-0 flex-1">
                            <div className="font-inter text-[11px] font-semibold text-muted">
                              {participantTimeLabel(s)}
                            </div>
                            <div className="mt-1 truncate font-outfit text-[14.5px] font-bold text-white group-hover:text-[#60A5FA]">
                              {s.scheduleName}
                            </div>
                            {speaker && (
                              <div className="mt-0.5 truncate font-inter text-[11.5px] text-muted">{speaker}</div>
                            )}
                          </div>
                          <span
                            className="shrink-0 rounded-full px-2 py-0.5 font-inter text-[10px] font-extrabold"
                            style={{
                              background: isLive ? "rgba(34,197,94,0.18)" : "rgba(59,130,246,0.18)",
                              color: isLive ? "#22C55E" : "#3B82F6",
                            }}
                          >
                            {isLive ? "Live" : "Upcoming"}
                          </span>
                        </div>
                      </div>
                    );
                  })}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* 2. All Sessions with Day Tabs (Screen 4)                             */
/* ------------------------------------------------------------------ */

export function AllSessionsApp() {
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  const [items, setItems] = useState<ScheduleItem[] | null>(null);
  const [open, setOpen] = useState<OpenSession[]>([]);
  const [days, setDays] = useState<Date[]>([]);
  const [eventTitle, setEventTitle] = useState("ISDR 2026 Conference");
  const [error, setError] = useState<string | null>(null);

  const dayParam = params.get("day");
  const activeDay = dayParam ? new Date(Number(dayParam)) : null;

  useEffect(() => {
    loadAllSchedules().then((r) => {
      if (r.error) return setError(r.error);
      setItems(r.items);
      setOpen(r.open);
      const evDays = r.days.length
        ? r.days
        : [...new Set(r.items.map((i) => new Date(i.start.getFullYear(), i.start.getMonth(), i.start.getDate()).getTime()))]
            .map((t) => new Date(t))
            .sort((a, b) => a.getTime() - b.getTime());
      setDays(evDays);
      if (r.items.length && r.items[0].event?.title) {
        setEventTitle(String(r.items[0].event.title));
      }
    });
  }, []);

  const placed = [
    ...(items ?? []),
    ...open.map(openAsItem).filter((it): it is ScheduleItem => !!it),
  ];
  const undated = open.filter((o) => !o.day);
  const list = placed
    .filter((i) => !activeDay || sameDay(i.start, activeDay))
    .sort(compareScheduleItems);
  const showUndated = !activeDay && undated.length > 0;
  const dayGroups: { day: Date; list: ScheduleItem[] }[] = [];
  for (const it of list) {
    const d = new Date(it.start.getFullYear(), it.start.getMonth(), it.start.getDate());
    const last = dayGroups[dayGroups.length - 1];
    if (last && sameDay(last.day, d)) last.list.push(it);
    else dayGroups.push({ day: d, list: [it] });
  }

  const now = new Date();

  return (
    <div className="min-h-screen bg-[#0A0A12] text-white">
      {/* Custom stylized header matching Flutter all_sessions_page.dart */}
      <div className="flex items-center border-b border-white/[0.08] px-3.5 py-2.5">
        <button
          onClick={() => navigate(-1)}
          aria-label="Back"
          className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full border border-[#3B82F6]/50 bg-[#111A3D] text-white active:scale-95"
        >
          <Icon name="arrow_back" size={22} />
        </button>
        <div className="mx-3 h-12 w-px bg-white/20" />
        <div className="min-w-0 flex-1">
          <div className="bg-gradient-to-r from-[#C084FC] to-[#60A5FA] bg-clip-text font-outfit text-base font-extrabold text-transparent">
            ISDR 2026
          </div>
          <div className="truncate font-outfit text-lg font-extrabold leading-tight text-white">{eventTitle}</div>
          <div className="truncate font-inter text-[11px] text-white/70">
            Innovate &nbsp;•&nbsp; Collaborate &nbsp;•&nbsp; Build the Future
          </div>
        </div>
        <div className="ml-2 shrink-0 text-[#3B82F6]/50">
          <Icon name="location_city" size={40} />
        </div>
      </div>

      {/* Horizontal Tabs: All Sessions / Day 1 / Day 2... */}
      <div className="flex gap-2 overflow-x-auto px-4 py-3 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
        <button
          onClick={() => setParams({}, { replace: true })}
          className={`flex shrink-0 items-center gap-1.5 rounded-full px-4 py-2 font-inter text-xs font-bold transition ${
            !activeDay
              ? "bg-gradient-to-r from-[#3B82F6] to-[#8B5CF6] text-white shadow-md"
              : "border border-white/10 bg-[#14141F] text-muted hover:text-white"
          }`}
        >
          <Icon name="event_note" size={15} />
          All Sessions
        </button>
        {days.map((d, i) => {
          const active = activeDay && sameDay(d, activeDay);
          return (
            <button
              key={d.getTime()}
              onClick={() => setParams({ day: String(d.getTime()) }, { replace: true })}
              className={`flex shrink-0 items-center gap-1.5 rounded-full px-4 py-2 font-inter text-xs font-bold transition ${
                active
                  ? "bg-gradient-to-r from-[#3B82F6] to-[#8B5CF6] text-white shadow-md"
                  : "border border-white/10 bg-[#14141F] text-muted hover:text-white"
              }`}
            >
              <Icon name="calendar_today" size={14} />
              Day {i + 1}
              <span className="font-normal opacity-70">({fmtDMon(d)})</span>
            </button>
          );
        })}
      </div>

      {/* Session Cards List */}
      <div className="space-y-3 px-4 pb-12">
        {!items && !error ? (
          <div className="py-24">
            <AppSpinner />
          </div>
        ) : error || (list.length === 0 && !showUndated) ? (
          <div className="flex flex-col items-center justify-center py-24 text-center">
            <Icon name="event_busy" size={44} color="#9CA3AF" />
            <div className="mt-3 font-outfit text-base font-bold">
              {error || "No sessions found for this day"}
            </div>
          </div>
        ) : (
          <>
          {dayGroups.map((group) => (
            <div key={group.day.getTime()} className="mb-6">
              {!activeDay && (
                <div className="mb-2 font-inter text-[12.5px] font-bold text-muted">
                  {weekdayLong(group.day)}, {group.day.getDate()} {monthShort(group.day)}
                </div>
              )}
              {groupByHall(group.list, (it) => String(it.schedule.hall ?? "")).map((hallGroup, hallIndex) => (
                <div key={`${hallGroup.hall}-${hallIndex}`} className="mb-4">
                  <div className="mb-2 flex items-center gap-1.5 font-inter text-[12px] font-bold text-[#93C5FD]">
                    <Icon name="location_on" size={14} />
                    {hallGroup.hall}
                  </div>
                  <div className="space-y-3">
                    {hallGroup.list.map((it) => {
                      const s = it.schedule ?? {};
                      const clock = participantTimeLabel(s);
                      const hasTime = !!(String(s.fromTime ?? "").trim() && String(s.toTime ?? "").trim());
                      const isLive = hasTime && now >= it.start && now < it.end;
                      const isDone = hasTime && now >= it.end;
                      const speakerPhoto = String(s.speakerPhoto ?? "");
                      const speakerName = displaySpeaker(s.speakerName);
                      const avatarName = splitSpeakerNames(s.speakerName)[0] ?? "";

                      return (
                        <div
                          key={idOf(s)}
                          onClick={() => navigate(scheduleHref(it))}
                          className="group cursor-pointer rounded-[16px] border border-white/[0.08] bg-[#14141F] p-4 transition hover:bg-white/[0.03] active:scale-[0.99]"
                        >
                          <div className="flex items-center justify-between">
                            <div className="font-inter text-[11.5px] font-semibold text-[#60A5FA]">
                              {clock}
                            </div>
                            {hasTime && (
                              <span
                                className="rounded-full px-2 py-0.5 font-inter text-[10px] font-extrabold"
                                style={{
                                  background: isLive
                                    ? "rgba(34,197,94,0.18)"
                                    : isDone
                                      ? "rgba(100,116,139,0.2)"
                                      : "rgba(59,130,246,0.18)",
                                  color: isLive ? "#22C55E" : isDone ? "#94A3B8" : "#60A5FA",
                                }}
                              >
                                {isLive ? "Live" : isDone ? "Completed" : "Upcoming"}
                              </span>
                            )}
                          </div>
                          <div className="mt-1.5 font-outfit text-[15px] font-bold text-white group-hover:text-[#60A5FA]">
                            {s.scheduleName}
                          </div>
                          {speakerName && (
                            <div className="mt-2.5 flex items-center gap-2.5">
                              <Avatar src={speakerPhoto} name={avatarName} size={30} />
                              <div className="truncate font-inter text-xs font-semibold text-white/80">{speakerName}</div>
                            </div>
                          )}
                        </div>
                      );
                    })}
                  </div>
                </div>
              ))}
            </div>
          ))}
          {showUndated &&
            groupByHall(undated, (o) => String(o.schedule.hall ?? "")).map((hallGroup, hallIndex) => (
              <div key={`open-${hallGroup.hall}-${hallIndex}`} className="mb-4">
                <div className="mb-2 flex items-center gap-1.5 font-inter text-[12px] font-bold text-[#93C5FD]">
                  <Icon name="location_on" size={14} />
                  {hallGroup.hall}
                </div>
                <div className="space-y-3">
                  {hallGroup.list.map((o) => {
                    const s = o.schedule ?? {};
                    const speakerName = displaySpeaker(s.speakerName);
                    return (
                      <div
                        key={idOf(s)}
                        onClick={() => navigate(scheduleHref(o))}
                        className="group cursor-pointer rounded-[16px] border border-white/[0.08] bg-[#14141F] p-4 transition hover:bg-white/[0.03] active:scale-[0.99]"
                      >
                        <div className="font-outfit text-[15px] font-bold text-white group-hover:text-[#60A5FA]">
                          {s.scheduleName}
                        </div>
                        {speakerName && (
                          <div className="mt-2.5 truncate font-inter text-xs font-semibold text-white/80">{speakerName}</div>
                        )}
                      </div>
                    );
                  })}
                </div>
              </div>
            ))}
          </>
        )}
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* 3. Favorites / My Schedule (Screen 5)                               */
/* ------------------------------------------------------------------ */

export function FavoritesApp() {
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

  const unfavorite = async (e: React.MouseEvent, s: any) => {
    e.stopPropagation();
    setSchedules((l) => (l ?? []).filter((x) => idOf(x) !== idOf(s)));
    const res = await toggleFavorite(idOf(s));
    if (!res.success) {
      toast(res.error || "Could not update", "error");
      load();
    }
  };

  const byDays: { day: Date | null; list: any[] }[] = [];
  if (schedules) {
    for (const s of schedules) {
      const d = s.date ? new Date(s.date) : null;
      const last = byDays[byDays.length - 1];
      if (last && ((d && last.day && sameDay(last.day, d)) || (!d && !last.day))) {
        last.list.push(s);
      } else {
        byDays.push({ day: d, list: [s] });
      }
    }
  }

  return (
    <div className="min-h-screen bg-[#0A0A12] text-white">
      <AppBar title="Favorites" outfit titleClassName="!text-left font-outfit text-[18px] font-bold" />
      <div className="px-4 pb-12 pt-2">
        {!schedules && !error ? (
          <div className="py-24">
            <AppSpinner />
          </div>
        ) : error || !schedules || schedules.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-28 text-center">
            <Icon name="favorite_border" size={44} color="#9CA3AF" />
            <div className="mt-3 font-outfit text-[17px] font-bold">{error || "No favorites yet"}</div>
            <div className="mt-1 font-inter text-xs text-muted">
              Tap the ♥ heart on any session to save it here.
            </div>
          </div>
        ) : (
          byDays.map((group, gi) => (
            <div key={gi} className="mb-6">
              {group.day && (
                <div className="mb-2 font-inter text-[12.5px] font-bold text-muted">
                  {weekdayLong(group.day)}, {group.day.getDate()} {monthShort(group.day)}
                </div>
              )}
              <div className="space-y-2.5">
                {group.list.map((s) => {
                  const ev = events[String(s.eventId)] ?? { id: s.eventId };
                  const hall = String(s.hall ?? "");
                  const speaker = displaySpeaker(s.speakerName);

                  return (
                    <div
                      key={idOf(s)}
                      onClick={() => navigate(scheduleHref({ event: ev, schedule: s }))}
                      className="group cursor-pointer rounded-[14px] border border-white/[0.08] bg-[#14141F] p-3.5 transition active:scale-[0.99]"
                    >
                      <div className="flex items-center justify-between gap-2">
                        <div className="min-w-0 flex-1">
                          <div className="font-inter text-[11px] font-semibold text-muted">
                            {[participantTimeLabel(s), hall]
                              .filter(Boolean)
                              .join("  ·  ")}
                          </div>
                          <div className="mt-1 truncate font-outfit text-[14.5px] font-bold text-white group-hover:text-[#60A5FA]">
                            {s.scheduleName}
                          </div>
                          {speaker && (
                            <div className="mt-0.5 truncate font-inter text-[11.5px] text-muted">{speaker}</div>
                          )}
                        </div>
                        <button
                          onClick={(e) => unfavorite(e, s)}
                          aria-label="Remove from favorites"
                          className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-[#EF4444] hover:bg-white/10"
                        >
                          <Icon name="favorite" size={22} />
                        </button>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* 4. Speakers (Screen 6)                                               */
/* ------------------------------------------------------------------ */

export function SpeakersApp() {
  const navigate = useNavigate();
  const [speakers, setSpeakers] = useState<{ name: string; photo: string; sessions: ScheduleItem[] }[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadAllSchedules().then((r) => {
      if (r.error) return setError(r.error || "Could not load speakers");
      const map = new Map<string, { name: string; photo: string; sessions: ScheduleItem[] }>();
      const sessions = [
        ...r.items,
        ...r.open.map((o) => openAsItem(o)).filter((it): it is ScheduleItem => !!it),
        ...r.open
          .filter((o) => !o.day)
          .map((o) => ({ schedule: o.schedule, event: o.event, start: new Date(0), end: new Date(0) })),
      ];
      for (const it of sessions) {
        const photo = String(it.schedule.speakerPhoto ?? "");
        for (const name of splitSpeakerNames(it.schedule.speakerName)) {
          const key = name.toLowerCase();
          if (!map.has(key)) map.set(key, { name, photo, sessions: [] });
          const entry = map.get(key)!;
          if (!entry.sessions.some((s) => idOf(s.schedule) === idOf(it.schedule))) entry.sessions.push(it);
        }
      }
      setSpeakers([...map.values()]);
    });
  }, []);

  return (
    <div className="min-h-screen bg-[#0A0A12] text-white">
      <AppBar title="Speakers" outfit titleClassName="!text-left font-outfit text-[18px] font-bold" />
      <div className="px-4 pb-12 pt-2">
        {!speakers && !error ? (
          <div className="py-24">
            <AppSpinner />
          </div>
        ) : error || !speakers || speakers.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-28 text-center">
            <Icon name="groups" size={44} color="#9CA3AF" />
            <div className="mt-3 font-outfit text-[17px] font-bold">{error || "No speakers yet"}</div>
            <div className="mt-1 font-inter text-xs text-muted">Speaker bios will be published shortly.</div>
          </div>
        ) : (
          <div className="space-y-3">
            {speakers.map((sp, i) => (
              <div
                key={sp.name}
                className="rounded-[14px] border border-white/[0.08] bg-[#14141F] p-3.5 shadow-sm"
              >
                <div className="flex items-center gap-3">
                  <span className="w-5 text-center font-outfit text-sm font-bold text-muted">{i + 1}</span>
                  <Avatar src={sp.photo} name={sp.name.replace(/^Dr\.?\s*/i, "")} size={48} />
                  <div className="min-w-0 flex-1">
                    <div className="font-outfit text-[15.5px] font-bold text-white">{sp.name}</div>
                    <div className="font-inter text-[11.5px] text-muted">
                      {sp.sessions.length === 1 ? "1 session" : `${sp.sessions.length} sessions`}
                    </div>
                  </div>
                </div>

                {/* Speaker's sessions list */}
                <div className="mt-2.5 space-y-1.5">
                  {sp.sessions.map((it) => {
                    const s = it.schedule ?? {};
                    const hall = String(s.hall ?? "");

                    return (
                      <div
                        key={idOf(s)}
                        onClick={() => navigate(scheduleHref(it))}
                        className="flex cursor-pointer items-center justify-between rounded-[10px] bg-white/[0.04] px-3 py-2 transition hover:bg-white/[0.08]"
                      >
                        <div className="min-w-0 flex-1">
                          <div className="truncate font-inter text-xs font-semibold text-white">
                            {s.scheduleName}
                          </div>
                          <div className="mt-0.5 font-inter text-[11px] text-[#60A5FA]">
                            {[
                              s.date && !s.hideDate ? `${weekday(it.start)}, ${it.start.getDate()} ${monthShort(it.start)}` : "",
                              participantTimeLabel(s),
                              hall,
                            ]
                              .filter(Boolean)
                              .join(" · ")}
                          </div>
                        </div>
                        <Icon name="chevron_right" size={18} color="#9CA3AF" />
                      </div>
                    );
                  })}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
