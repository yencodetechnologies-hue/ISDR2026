/* eslint-disable @typescript-eslint/no-explicit-any */
import { get, post } from "./api";
import { fmtTimeStr, idOf, parseDate, scheduleDay, scheduleTimes, startOfDay } from "./format";

export type ScheduleItem = { schedule: any; event: any; start: Date; end: Date };

/** A session saved without a clock. `day` is null when the admin left the date empty. */
export type OpenSession = { schedule: any; event: any; day: Date | null };

/** Each calendar day from an event's start date to its end date. */
export function daysOfEvent(event: any): Date[] {
  const start = parseDate(event?.eventDate);
  if (!start) return [];
  const end = parseDate(event?.eventEndDate) ?? start;
  const days: Date[] = [];
  let cursor = startOfDay(start);
  const last = startOfDay(end);
  while (cursor <= last && days.length < 60) {
    days.push(cursor);
    cursor = new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate() + 1);
  }
  return days;
}

/** Every managed event with all its schedules, as timed items (like the app's _fetchLiveSchedule). */
/** Every event's schedules; with `onlyEventId`, just that event's (the participant's own event). */
export async function loadAllSchedules(onlyEventId?: string | null): Promise<{
  events: any[];
  items: ScheduleItem[];
  open: OpenSession[];
  days: Date[];
  error?: string;
}> {
  const ev = await get("/managed-events");
  if (!ev.success) return { events: [], items: [], open: [], days: [], error: ev.error };
  const all: any[] = ev.events ?? [];
  const events = onlyEventId ? all.filter((e) => idOf(e) === onlyEventId) : all;
  const items: ScheduleItem[] = [];
  const open: OpenSession[] = [];
  const dayKeys = new Map<number, Date>();
  const results = await Promise.all(
    events.map(async (event) => {
      const id = idOf(event);
      if (!id) return null;
      for (const d of daysOfEvent(event)) dayKeys.set(d.getTime(), d);
      const res = await get(`/managed-events/${id}/schedules`);
      return res.success ? { event, schedules: (res.schedules ?? []) as any[] } : null;
    }),
  );
  for (const r of results) {
    if (!r) continue;
    for (const s of r.schedules) {
      const w = scheduleTimes(s);
      if (w) items.push({ schedule: s, event: r.event, start: w.start, end: w.end });
      else open.push({ schedule: s, event: r.event, day: scheduleDay(s) });
    }
  }
  items.sort(compareScheduleItems);
  const days = [...dayKeys.values()].sort((a, b) => a.getTime() - b.getTime());
  return { events, items, open, days };
}

/** Place a dateless/timeless session on its calendar day so day lists can show it. */
export function openAsItem(session: OpenSession): ScheduleItem | null {
  if (!session.day) return null;
  return {
    schedule: session.schedule,
    event: session.event,
    start: session.day,
    end: new Date(session.day.getTime() + 60 * 1000),
  };
}

/** One event + one of its schedules (for the schedule detail page). */
export async function loadSchedule(eventId: string, scheduleId: string) {
  const [ev, sc] = await Promise.all([get(`/managed-events/${eventId}`), get(`/managed-events/${eventId}/schedules`)]);
  const schedule = ((sc.schedules ?? []) as any[]).find((s) => idOf(s) === scheduleId) ?? null;
  return {
    event: ev.event ?? null,
    schedule,
    error: !schedule ? sc.error || ev.error || "Session not found" : undefined,
  };
}

export const scheduleHref = (item: { event: any; schedule: any }) =>
  `/schedule?e=${encodeURIComponent(idOf(item.event))}&s=${encodeURIComponent(idOf(item.schedule))}`;

function savedOrder(schedule: any): number | null {
  const n = Number(schedule?.sortOrder);
  return Number.isInteger(n) && n > 0 ? n : null;
}

/** Same calendar day: saved S.No, then clock. Other days stay in date order. */
export function compareScheduleItems(a: ScheduleItem, b: ScheduleItem): number {
  const ad = startOfDay(a.start).getTime();
  const bd = startOfDay(b.start).getTime();
  if (ad !== bd) return ad - bd;
  const ao = savedOrder(a.schedule);
  const bo = savedOrder(b.schedule);
  if (ao != null && bo != null && ao !== bo) return ao - bo;
  if (ao != null && bo == null) return -1;
  if (ao == null && bo != null) return 1;
  const time = a.start.getTime() - b.start.getTime();
  if (time) return time;
  return String(idOf(a.schedule)).localeCompare(String(idOf(b.schedule)));
}

/**
 * Consecutive sessions that share a hall, in the order they were given.
 * Callers pass the admin S.No order. A hall is not pulled above an earlier serial.
 */
export function groupByHall<T>(items: T[], hallOf: (item: T) => string): { hall: string; list: T[] }[] {
  const groups: { hall: string; list: T[] }[] = [];
  for (const item of items) {
    const hall = hallOf(item).trim() || "Other";
    const last = groups[groups.length - 1];
    if (last && last.hall === hall) last.list.push(item);
    else groups.push({ hall, list: [item] });
  }
  return groups;
}

const PLACEHOLDER_SPEAKER = /^(—|-|speaker not listed)$/i;

/** Panel names are stored joined with " · ". Placeholders such as "—" are dropped. */
export function splitSpeakerNames(raw: unknown): string[] {
  const seen = new Set<string>();
  const names: string[] = [];
  for (const part of String(raw ?? "").split(" · ")) {
    const name = part.trim();
    if (!name || PLACEHOLDER_SPEAKER.test(name)) continue;
    const key = name.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    names.push(name);
  }
  return names;
}

export const displaySpeaker = (raw: unknown) => splitSpeakerNames(raw).join(" · ");

export const visibleFromTime = (s: any) => (s?.hideFromTime ? "" : String(s?.fromTime ?? "").trim());
export const visibleToTime = (s: any) => (s?.hideToTime ? "" : String(s?.toTime ?? "").trim());

/** Clock text for participants. A hidden from or to time is left out. */
export function participantTimeLabel(s: any) {
  const from = visibleFromTime(s);
  const to = visibleToTime(s);
  if (from && to) return `${fmtTimeStr(from)} - ${fmtTimeStr(to)}`;
  if (from) return fmtTimeStr(from);
  if (to) return fmtTimeStr(to);
  return "";
}

export const participantShowsDate = (s: any) => !s?.hideDate && !!s?.date;

/* Favourites (hearted schedules) */

export async function loadFavorites(): Promise<Set<string>> {
  const res = await get("/managed-events/my-favorites");
  return new Set(res.success ? ((res.scheduleIds as any[]) ?? []).map(String) : []);
}

export const toggleFavorite = (scheduleId: string) => post(`/managed-events/favorites/${scheduleId}`);

/* Start reminders */

export const REMINDER_CHOICES = [0, 5, 10, 15, 30, 60];

export const reminderLabel = (minutes: number) =>
  minutes === 0 ? "At session start" : minutes === 60 ? "1 hour before" : `${minutes} min before`;

export async function loadReminders(): Promise<Map<string, number>> {
  const res = await get("/managed-events/my-reminders");
  const out = new Map<string, number>();
  if (!res.success) return out;
  if (res.reminders && typeof res.reminders === "object") {
    for (const [k, v] of Object.entries(res.reminders)) out.set(k, Number(v) || 0);
  } else {
    for (const id of (res.scheduleIds as any[]) ?? []) out.set(String(id), 0);
  }
  return out;
}

/** minutes = null turns the reminder off. */
export const setReminder = (scheduleId: string, minutes: number | null) =>
  post(`/managed-events/reminders/${scheduleId}`, minutes === null ? { remove: true } : { minutesBefore: minutes });
