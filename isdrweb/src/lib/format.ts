/* eslint-disable @typescript-eslint/no-explicit-any */
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const MONTHS_LONG = [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
];
const DAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const DAYS_LONG = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

export const monthShort = (d: Date) => MONTHS[d.getMonth()];
export const monthLong = (d: Date) => MONTHS_LONG[d.getMonth()];
export const weekday = (d: Date) => DAYS[d.getDay()];
export const weekdayLong = (d: Date) => DAYS_LONG[d.getDay()];

/** The id of a Mongo-ish record. */
export const idOf = (x: any): string => String(x?.id ?? x?._id ?? "");

export function parseDate(v: any): Date | null {
  if (!v) return null;
  const d = v instanceof Date ? v : new Date(v);
  return isNaN(d.getTime()) ? null : d;
}

const pad = (n: number) => String(n).padStart(2, "0");

/** h:mm AM */
export function fmtTime(d: Date | null | undefined) {
  if (!d) return "";
  const h = d.getHours();
  return `${h % 12 || 12}:${pad(d.getMinutes())} ${h < 12 ? "AM" : "PM"}`;
}

/** "14:30" / "2:30 PM" → "2:30 PM" */
export function fmtTimeStr(s: any) {
  const str = String(s ?? "").trim();
  const m = /^(\d{1,2}):(\d{2})\s*(am|pm)?$/i.exec(str);
  if (!m) return str;
  let h = Number(m[1]);
  const min = m[2];
  if (m[3]) return `${h % 12 || 12}:${min} ${m[3].toUpperCase()}`;
  const ap = h < 12 ? "AM" : "PM";
  h = h % 12 || 12;
  return `${h}:${min} ${ap}`;
}

/** 5 Oct 2026 */
export const fmtDate = (d: Date | null | undefined) => (d ? `${d.getDate()} ${monthShort(d)} ${d.getFullYear()}` : "");
/** Mon, 5 Oct 2026 */
export const fmtDayDate = (d: Date | null | undefined) => (d ? `${weekday(d)}, ${fmtDate(d)}` : "");
/** Mon, 5 Oct 2026 · 2:30 PM */
export const fmtDateTime = (d: Date | null | undefined) => (d ? `${fmtDayDate(d)} · ${fmtTime(d)}` : "");
/** 5 Oct, 2:30 PM */
export const fmtShortDateTime = (d: Date | null | undefined) =>
  d ? `${d.getDate()} ${monthShort(d)}, ${fmtTime(d)}` : "";
/** 5 Oct */
export const fmtDMon = (d: Date | null | undefined) => (d ? `${d.getDate()} ${monthShort(d)}` : "");

export function timeAgo(v: any) {
  const d = parseDate(v);
  if (!d) return "";
  const s = Math.floor((new Date().getTime() - d.getTime()) / 1000);
  if (s < 60) return "Just now";
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  const days = Math.floor(h / 24);
  if (days < 7) return `${days}d ago`;
  return fmtDate(d);
}

export const startOfDay = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate());
export const sameDay = (a: Date, b: Date) =>
  a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();

/** YYYY-MM-DD in local time. */
export const isoDay = (d: Date) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;

/** Parse "HH:mm" or "h:mm AM" into [hours, minutes]. */
export function parseHm(s: any): [number, number] | null {
  const m = /^(\d{1,2}):(\d{2})\s*(am|pm)?$/i.exec(String(s ?? "").trim());
  if (!m) return null;
  let h = Number(m[1]);
  const min = Number(m[2]);
  if (m[3]) {
    const pm = m[3].toLowerCase() === "pm";
    if (h === 12) h = pm ? 12 : 0;
    else if (pm) h += 12;
  }
  return [h, min];
}

/**
 * Start/end of a schedule row: the schedule's calendar day (its `date`, read
 * in UTC like the app) + the local fromTime / toTime.
 */
export function scheduleTimes(s: any): { start: Date; end: Date } | null {
  const d = parseDate(s?.date);
  if (!d) return null;
  const y = d.getUTCFullYear();
  const mo = d.getUTCMonth();
  const day = d.getUTCDate();
  const f = parseHm(s?.fromTime) ?? [0, 0];
  const t = parseHm(s?.toTime) ?? f;
  const start = new Date(y, mo, day, f[0], f[1]);
  let end = new Date(y, mo, day, t[0], t[1]);
  if (end <= start) end = new Date(start.getTime() + 60 * 60000);
  return { start, end };
}

/** The schedule's calendar day as a local Date. */
export function scheduleDay(s: any): Date | null {
  const d = parseDate(s?.date);
  return d ? new Date(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()) : null;
}

/** Value for <input type="datetime-local">. */
export const toLocalInput = (d: Date) =>
  `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;

export const fullName = (r: any) =>
  [r?.title, r?.firstName, r?.middleName, r?.lastName]
    .map((x) => String(x ?? "").trim())
    .filter(Boolean)
    .join(" ") || String(r?.name ?? "");

export const cap = (s: any) => {
  const t = String(s ?? "");
  return t ? t[0].toUpperCase() + t.slice(1) : "";
};
