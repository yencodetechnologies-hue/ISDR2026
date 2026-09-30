/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useRef, useState } from "react";
import { useNavigate, useParams, useSearchParams } from "react-router-dom";
import { AppBar, Icon, Spinner, useConfirm, useToast } from "@/components/ui";
import { AppSpinner, AppSwitch } from "@/components/app/AppControls";
import { AppChip, AppDecorator } from "@/components/app/AppForm";
import { formData, get, post, put } from "@/lib/api";
import { fmtTimeStr, idOf, parseDate } from "@/lib/format";
import { del } from "@/lib/api";
import { eventDays } from "./EventManage";

const WEEK = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const MON = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const dayText = (d: Date) => `${WEEK[d.getDay()]}, ${d.getDate()} ${MON[d.getMonth()]} ${d.getFullYear()}`;
const timeText = (d: Date) => {
  const h = d.getHours();
  return `${h % 12 || 12}:${String(d.getMinutes()).padStart(2, "0")} ${h < 12 ? "AM" : "PM"}`;
};
const titleClass = "text-[18px] font-bold";

/* ------------------------------------------------------------------ */
/* Event Schedules — the app's EventSchedulesPage (pick an event)       */
/* ------------------------------------------------------------------ */

export function EventSchedulesApp() {
  const navigate = useNavigate();
  const [events, setEvents] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    const r = await get("/managed-events");
    setLoading(false);
    if (r.success) setEvents(r.events ?? []);
    else setError(r.error || "Failed to load events");
  }, []);
  useEffect(() => {
    load();
  }, [load]);

  return (
    <div className="min-h-screen bg-bg">
      <AppBar title="Event Schedules" titleClassName={titleClass} />
      {loading ? (
        <AppSpinner />
      ) : error ? (
        <div className="flex flex-col items-center px-6 pt-32 text-center">
          <div>{error}</div>
          <button
            onClick={load}
            className="mt-3 h-10 rounded-full border border-[#8E8E98] px-5 text-sm font-medium text-accent"
          >
            Retry
          </button>
        </div>
      ) : events.length === 0 ? (
        <div className="pt-40 text-center text-muted">No events yet</div>
      ) : (
        <div className="space-y-2.5 p-4">
          {events.map((e) => {
            const start = parseDate(e.eventDate);
            const cancelled = e.status === "cancelled";
            return (
              <button
                key={idOf(e)}
                onClick={() => navigate(`/admin/schedules/event/${idOf(e)}`)}
                className="flex w-full items-center rounded-2xl border border-white/10 bg-card p-3.5 text-left active:bg-white/[0.03]"
              >
                <span className="flex h-[42px] w-[42px] shrink-0 items-center justify-center rounded-xl bg-accent/[0.09]">
                  <Icon name="event_note" size={22} color="#3B82F6" />
                </span>
                <span className="ml-3 min-w-0 flex-1">
                  <span className="block text-[15.5px] font-extrabold">{e.title || "Event"}</span>
                  {start && (
                    <span className="mt-[3px] block text-[12.5px] text-muted">
                      {dayText(start)} · {timeText(start)}
                    </span>
                  )}
                  {e.venue && <span className="mt-0.5 block text-[12.5px] text-muted">{e.venue}</span>}
                </span>
                <span
                  className="ml-2 rounded-full px-[9px] py-[3px] text-[10.5px] font-extrabold"
                  style={
                    cancelled
                      ? { background: "rgba(239,68,68,0.15)", color: "#FCA5A5" }
                      : { background: "rgba(34,197,94,0.15)", color: "#86EFAC" }
                  }
                >
                  {e.status ?? "Active"}
                </span>
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* One event's schedules — the app's EventScheduleListPage             */
/* ------------------------------------------------------------------ */

/** Start/end of a schedule on its calendar day (the date is stored as a UTC day). */
function windowOf(s: any) {
  const d = new Date(String(s.date ?? ""));
  if (isNaN(d.getTime())) return null;
  const at = (hhmm: string) => {
    const [h, m] = String(hhmm ?? "").split(":");
    return new Date(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), Number(h) || 0, Number(m) || 0);
  };
  return {
    start: at(s.fromTime),
    end: at(s.toTime),
    day: new Date(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()),
  };
}

/** LIVE / Upcoming / Tomorrow / "3 Oct" — null once over. */
function bannerOf(s: any, now: Date): { label: string; live: boolean } | null {
  const w = windowOf(s);
  if (!w) return null;
  if (now >= w.start && now < w.end) return { label: "LIVE", live: true };
  if (now >= w.end) return null;
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const diff = Math.round((w.day.getTime() - today.getTime()) / 86400000);
  if (diff <= 0) return { label: "Upcoming", live: false };
  if (diff === 1) return { label: "Tomorrow", live: false };
  return { label: `${w.day.getDate()} ${MON[w.day.getMonth()]}`, live: false };
}

export function EventScheduleListApp() {
  const { eventId = "" } = useParams<{ eventId: string }>();
  const navigate = useNavigate();
  const toast = useToast();
  const confirm = useConfirm();
  const [event, setEvent] = useState<any>(null);
  const [schedules, setSchedules] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [now, setNow] = useState(() => new Date());

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    const [ev, r] = await Promise.all([get(`/managed-events/${eventId}`), get(`/managed-events/${eventId}/schedules`)]);
    setLoading(false);
    if (ev.success) setEvent(ev.event);
    if (r.success) setSchedules(r.schedules ?? []);
    else setError(r.error || "Failed to load schedules");
  }, [eventId]);
  useEffect(() => {
    load();
    const t = setInterval(() => setNow(new Date()), 30000);
    return () => clearInterval(t);
  }, [load]);

  const remove = async (s: any) => {
    if (!(await confirm({ title: "Delete this schedule?", confirm: "Delete", cancel: "No" }))) return;
    const r = await del(`/managed-events/${eventId}/schedules/${idOf(s)}`);
    if (r.success) load();
    else toast(r.error || "Delete failed");
  };

  // Live schedules first, the rest keep their date/time order.
  const ordered = [
    ...schedules.filter((s) => bannerOf(s, now)?.live),
    ...schedules.filter((s) => !bannerOf(s, now)?.live),
  ];

  return (
    <div className="flex min-h-screen flex-col bg-bg">
      <AppBar title={event?.title || "Schedules"} titleClassName={titleClass} />
      <div className="px-4 pb-2 pt-4">
        <button
          onClick={() => navigate(`/admin/schedules/new?event=${eventId}`)}
          className="flex h-12 w-full items-center justify-center gap-2 rounded-[14px] bg-accent font-bold"
        >
          <Icon name="add" />
          Add Schedule
        </button>
      </div>
      {loading ? (
        <AppSpinner />
      ) : error ? (
        <div className="flex flex-col items-center pt-24 text-center">
          <div>{error}</div>
          <button
            onClick={load}
            className="mt-2.5 h-10 rounded-full border border-[#8E8E98] px-5 text-sm font-medium text-accent"
          >
            Retry
          </button>
        </div>
      ) : schedules.length === 0 ? (
        <div className="pt-[120px] text-center text-muted">No schedules added yet</div>
      ) : (
        <div className="space-y-2.5 px-4 pb-6 pt-2">
          {ordered.map((s) => {
            const w = windowOf(s);
            const banner = bannerOf(s, now);
            return (
              <div key={idOf(s)} className="flex items-start rounded-2xl border border-white/10 bg-card p-3.5">
                <span className="flex h-[52px] w-[52px] shrink-0 items-center justify-center overflow-hidden rounded-full bg-accent/[0.09]">
                  {s.speakerPhoto ? (
                    <img src={s.speakerPhoto} alt="" className="h-full w-full object-cover" />
                  ) : (
                    <Icon name="person" color="#3B82F6" />
                  )}
                </span>
                <div className="ml-3 min-w-0 flex-1">
                  <div className="flex items-start gap-2">
                    <div className="min-w-0 flex-1 text-[15.5px] font-extrabold">{s.scheduleName}</div>
                    {banner && (
                      <span
                        className="inline-flex shrink-0 items-center gap-[3px] rounded-full px-[9px] py-[3px] text-[11px] font-extrabold"
                        style={
                          banner.live
                            ? { background: "rgba(34,197,94,0.15)", color: "#86EFAC", letterSpacing: 0.8 }
                            : { background: "rgba(59,130,246,0.09)", color: "#3B82F6", letterSpacing: 0.2 }
                        }
                      >
                        {banner.live && (
                          <span className="relative flex h-3.5 w-3.5 items-center justify-center">
                            <span className="absolute h-3.5 w-3.5 animate-ping rounded-full bg-[#22C55E]/50" />
                            <span className="h-[7px] w-[7px] rounded-full bg-[#22C55E]" />
                          </span>
                        )}
                        {banner.label}
                      </span>
                    )}
                  </div>
                  <div className="mt-0.5 text-[13px] font-semibold text-accent">{s.speakerName}</div>
                  <div className="mt-1 text-[12.5px] text-muted">
                    {w ? dayText(w.day) : ""} · {fmtTimeStr(s.fromTime)} - {fmtTimeStr(s.toTime)}
                  </div>
                  {s.hall && (
                    <div className="mt-0.5 flex items-center gap-1 text-[12.5px] text-muted">
                      <Icon name="meeting_room" outline size={13} color="#9CA3AF" />
                      {s.hall}
                    </div>
                  )}
                  {s.description && <div className="mt-1.5 text-[12.5px]">{s.description}</div>}
                </div>
                <div className="ml-1 flex flex-col">
                  <button
                    onClick={() => navigate(`/admin/schedules/new?event=${eventId}&schedule=${idOf(s)}`)}
                    className="flex h-10 w-10 items-center justify-center rounded-full active:bg-white/10"
                    title="Edit"
                  >
                    <Icon name="edit" outline size={20} color="#60A5FA" />
                  </button>
                  <button
                    onClick={() => remove(s)}
                    className="flex h-10 w-10 items-center justify-center rounded-full active:bg-white/10"
                    title="Delete"
                  >
                    <Icon name="delete" outline size={20} color="#EF4444" />
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Add / Edit Schedule — the app's AddEventSchedulePage                 */
/* ------------------------------------------------------------------ */

/** A tappable From/To field that opens the device time picker. */
function TimeField({ label, value, onChange }: { label: string; value: string; onChange: (v: string) => void }) {
  const ref = useRef<HTMLInputElement>(null);
  const open = () => {
    const el = ref.current;
    if (!el) return;
    try {
      el.showPicker();
    } catch {
      el.focus();
      el.click();
    }
  };
  return (
    <div className="relative flex-1">
      <AppDecorator label={label} icon="schedule" onClick={open}>
        <span className={`font-semibold ${value ? "text-white" : "text-muted"}`}>
          {value ? fmtTimeStr(value) : "Select"}
        </span>
      </AppDecorator>
      <input
        ref={ref}
        type="time"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="pointer-events-none absolute bottom-0 left-0 h-0 w-0 opacity-0"
        tabIndex={-1}
      />
    </div>
  );
}

function TextArea({
  label,
  icon,
  value,
  onChange,
  rows = 1,
  error,
}: {
  label: string;
  icon: string;
  value: string;
  onChange: (v: string) => void;
  rows?: number;
  error?: string | null;
}) {
  const [focused, setFocused] = useState(false);
  const floated = focused || value.length > 0;
  const line = error ? "#EF4444" : focused ? "#3B82F6" : "rgba(255,255,255,0.08)";
  return (
    <div>
      <div className="relative rounded-[14px] bg-field" style={{ boxShadow: `inset 0 0 0 1px ${line}` }}>
        <span className="pointer-events-none absolute left-3.5 top-4">
          <Icon name={icon} outline size={20} color="#60A5FA" />
        </span>
        <label
          className="pointer-events-none absolute transition-all duration-150"
          style={
            floated
              ? {
                  left: 12,
                  top: -8,
                  fontSize: 12,
                  color: error ? "#EF4444" : focused ? "#60A5FA" : "#9CA3AF",
                  padding: "0 4px",
                  background: "linear-gradient(to bottom, #0A0A12 50%, #1E1E2A 50%)",
                  lineHeight: "16px",
                }
              : { left: 48, top: 16, fontSize: 15, color: "#9CA3AF" }
          }
        >
          {label}
        </label>
        {rows > 1 ? (
          <textarea
            value={value}
            rows={rows}
            onFocus={() => setFocused(true)}
            onBlur={() => setFocused(false)}
            onChange={(e) => onChange(e.target.value)}
            className="block w-full resize-none bg-transparent py-4 pl-12 pr-3.5 text-[15px] outline-none"
          />
        ) : (
          <input
            value={value}
            onFocus={() => setFocused(true)}
            onBlur={() => setFocused(false)}
            onChange={(e) => onChange(e.target.value)}
            className="w-full bg-transparent py-4 pl-12 pr-3.5 text-[15px] outline-none"
          />
        )}
      </div>
      {error && <div className="ml-3 mt-1.5 text-xs text-[#EF4444]">{error}</div>}
    </div>
  );
}

export function ScheduleFormApp() {
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const toast = useToast();
  const eventId = params.get("event") ?? "";
  const scheduleId = params.get("schedule") ?? "";
  const isEdit = !!scheduleId;
  const [event, setEvent] = useState<any>(null);
  const [existing, setExisting] = useState<any>(null);
  const [speakers, setSpeakers] = useState<any[] | null>(null);
  const [speakerId, setSpeakerId] = useState("");
  const [packageIds, setPackageIds] = useState<string[]>([]);
  const [removedPackages, setRemovedPackages] = useState(0);
  const [name, setName] = useState("");
  const [hall, setHall] = useState("");
  const [description, setDescription] = useState("");
  const [dates, setDates] = useState<string[]>([]);
  const [sameTime, setSameTime] = useState(true);
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");
  const [fromByDate, setFromByDate] = useState<Record<string, string>>({});
  const [toByDate, setToByDate] = useState<Record<string, string>>({});
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    (async () => {
      const [ev, sp, sch] = await Promise.all([
        get(`/managed-events/${eventId}`),
        get("/speakers"),
        isEdit ? get(`/managed-events/${eventId}/schedules`) : Promise.resolve({ success: false } as any),
      ]);
      const e = ev.success ? ev.event : null;
      setEvent(e);
      const list: any[] = sp.success ? (sp.speakers ?? []) : [];
      setSpeakers(list);
      if (isEdit && sch.success) {
        const s = (sch.schedules ?? []).find((x: any) => idOf(x) === scheduleId);
        if (s) {
          setExisting(s);
          setName(s.scheduleName ?? "");
          setHall(s.hall ?? "");
          setDescription(s.description ?? "");
          const sid = String(s.speakerId ?? "");
          setSpeakerId(list.some((x) => idOf(x) === sid) ? sid : "");
          const current = new Set(((e?.packages ?? []) as any[]).map((p) => String(p.id)));
          const saved: string[] = (s.packageIds ?? []).map(String);
          const kept = saved.filter((id) => current.has(id));
          setPackageIds(kept);
          setRemovedPackages(saved.length - kept.length);
          const d = new Date(String(s.date ?? ""));
          if (!isNaN(d.getTime()))
            setDates([
              `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}-${String(d.getUTCDate()).padStart(2, "0")}`,
            ]);
          setFrom(String(s.fromTime ?? ""));
          setTo(String(s.toTime ?? ""));
        }
      }
    })();
  }, [eventId, scheduleId, isEdit]);

  const packages: { id: string; name: string }[] = ((event?.packages ?? []) as any[])
    .map((p) => ({ id: String(p.id ?? ""), name: String(p.name ?? "") }))
    .filter((p) => p.id);
  const days = event ? eventDays(event) : [];
  const pickedDays = days.filter((d) => dates.includes(d.iso));
  const perDate = !sameTime && dates.length > 1;
  const legacySpeakerName =
    isEdit && existing && !String(existing.speakerId ?? "") ? String(existing.speakerName ?? "") : "";
  const hadNoPackages = isEdit && existing && !(existing.packageIds ?? []).length;

  const save = async () => {
    const e: Record<string, string> = {};
    if (!name.trim()) e.name = "Enter the schedule name";
    if (!hall.trim()) e.hall = "Enter the hall";
    if (speakers && speakers.length && !speakerId && !legacySpeakerName) e.speaker = "Select a speaker";
    setErrors(e);
    if (Object.keys(e).length) return;
    if (!packageIds.length && !hadNoPackages) return toast("Select at least one package");
    if (!speakerId && !legacySpeakerName) return toast("Select a speaker");
    if (!dates.length) return toast("Select at least one event day");
    const slots: { date: string; fromTime: string; toTime: string }[] = [];
    for (const day of pickedDays) {
      const f = perDate ? fromByDate[day.iso] : from;
      const t = perDate ? toByDate[day.iso] : to;
      const forDay = perDate ? ` for ${day.label}` : "";
      if (!f || !t) return toast(`Select from and to time${forDay}`);
      if (t <= f) return toast(`To time must be after from time${forDay}`);
      slots.push({ date: day.iso, fromTime: f, toTime: t });
    }
    setSaving(true);
    const r = isEdit
      ? await put(`/managed-events/${eventId}/schedules/${scheduleId}`, {
          speakerId,
          packageIds,
          scheduleName: name.trim(),
          hall: hall.trim(),
          ...slots[0],
          description: description.trim(),
        })
      : await post(
          `/managed-events/${eventId}/schedules`,
          formData({
            speakerId,
            packageIds,
            scheduleName: name.trim(),
            hall: hall.trim(),
            slots,
            description: description.trim(),
          }),
        );
    setSaving(false);
    if (r.success) navigate(-1);
    else toast(r.error || (isEdit ? "Failed to update schedule" : "Failed to add schedule"));
  };

  const togglePackage = (id: string) => setPackageIds((l) => (l.includes(id) ? l.filter((x) => x !== id) : [...l, id]));
  const toggleDay = (iso: string) =>
    setDates((l) => (isEdit ? [iso] : l.includes(iso) ? l.filter((x) => x !== iso) : [...l, iso]));

  return (
    <div className="min-h-screen bg-bg">
      <AppBar title={isEdit ? "Edit Schedule" : "Add Schedule"} outfit />
      {!event || speakers === null ? (
        <AppSpinner />
      ) : (
        <div className="space-y-3 p-4 pt-5">
          <AppDecorator label="Packages (who can see it)" icon="card_membership">
            {packages.length === 0 ? (
              <span className="text-muted">This event has no packages. Add packages to the event first.</span>
            ) : (
              <div className="flex flex-wrap gap-2">
                {packages.map((p) => (
                  <AppChip
                    key={p.id}
                    label={p.name}
                    check
                    selected={packageIds.includes(p.id)}
                    onClick={() => togglePackage(p.id)}
                  />
                ))}
              </div>
            )}
          </AppDecorator>
          {removedPackages > 0 && (
            <div className="ml-1 flex items-start gap-1.5 text-xs text-[#FBBF24]">
              <Icon name="info" outline size={16} color="#FBBF24" />
              {removedPackages === 1
                ? "The package this schedule was saved with has been deleted from the event. Select its package again."
                : `${removedPackages} packages this schedule was saved with have been deleted from the event. Select its packages again.`}
            </div>
          )}
          {speakers.length === 0 ? (
            <AppDecorator label="Speaker" icon="person" onClick={() => navigate("/admin/speakers")}>
              <span className="text-[#60A5FA]">No speakers yet — tap to add them on the Speakers page</span>
            </AppDecorator>
          ) : (
            <div>
              <div
                className="relative rounded-[14px] bg-field"
                style={{ boxShadow: `inset 0 0 0 1px ${errors.speaker ? "#EF4444" : "rgba(255,255,255,0.08)"}` }}
              >
                <span
                  className="pointer-events-none absolute left-3 top-[-8px] px-1 text-xs leading-4"
                  style={{
                    color: errors.speaker ? "#EF4444" : "#9CA3AF",
                    background: "linear-gradient(to bottom, #0A0A12 50%, #1E1E2A 50%)",
                  }}
                >
                  Speaker
                </span>
                <span className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2">
                  <Icon name="person" outline size={20} color="#60A5FA" />
                </span>
                <select
                  value={speakerId}
                  onChange={(e) => setSpeakerId(e.target.value)}
                  className={`w-full appearance-none bg-transparent py-4 pl-12 pr-10 text-[15px] outline-none ${
                    speakerId || legacySpeakerName ? "text-white" : "text-muted"
                  }`}
                >
                  <option value="" disabled hidden>
                    {legacySpeakerName || "Select speaker"}
                  </option>
                  {speakers.map((s) => (
                    <option key={idOf(s)} value={idOf(s)} className="text-white">
                      {s.name}
                    </option>
                  ))}
                </select>
                {!speakerId && (
                  <span
                    className={`pointer-events-none absolute left-12 top-1/2 -translate-y-1/2 text-[15px] ${
                      legacySpeakerName ? "text-white" : "text-muted"
                    }`}
                  >
                    {legacySpeakerName || "Select speaker"}
                  </span>
                )}
                <span className="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2">
                  <Icon name="arrow_drop_down" size={24} color="#9CA3AF" />
                </span>
              </div>
              {errors.speaker && <div className="ml-3 mt-1.5 text-xs text-[#EF4444]">{errors.speaker}</div>}
            </div>
          )}
          <TextArea
            label="Name of the schedule"
            icon="event_note"
            value={name}
            onChange={setName}
            error={errors.name}
          />
          <TextArea label="Hall / venue" icon="meeting_room" value={hall} onChange={setHall} error={errors.hall} />
          <AppDecorator label="Date (event days)" icon="calendar_month">
            {days.length === 0 ? (
              <span className="text-muted">This event has no dates</span>
            ) : (
              <div className="flex flex-wrap gap-2">
                {days.map((d) => (
                  <AppChip
                    key={d.iso}
                    label={d.label}
                    selected={dates.includes(d.iso)}
                    onClick={() => toggleDay(d.iso)}
                  />
                ))}
              </div>
            )}
          </AppDecorator>
          {dates.length > 1 ? (
            <label className="flex cursor-pointer items-center justify-between px-1 py-2">
              <span className="text-sm font-semibold">Same time for all dates</span>
              <AppSwitch checked={sameTime} onChange={setSameTime} />
            </label>
          ) : null}
          {perDate ? (
            pickedDays.map((day) => (
              <div key={day.iso}>
                <div className="mb-1.5 ml-1 font-bold">{day.label}</div>
                <div className="flex gap-2.5">
                  <TimeField
                    label="From time"
                    value={fromByDate[day.iso] ?? ""}
                    onChange={(v) => setFromByDate((m) => ({ ...m, [day.iso]: v }))}
                  />
                  <TimeField
                    label="To time"
                    value={toByDate[day.iso] ?? ""}
                    onChange={(v) => setToByDate((m) => ({ ...m, [day.iso]: v }))}
                  />
                </div>
              </div>
            ))
          ) : (
            <div className="flex gap-2.5">
              <TimeField label="From time" value={from} onChange={setFrom} />
              <TimeField label="To time" value={to} onChange={setTo} />
            </div>
          )}
          <TextArea label="Description" icon="notes" value={description} onChange={setDescription} rows={3} />
          <div className="pt-2">
            <button
              onClick={saving ? undefined : save}
              className="flex h-[50px] w-full items-center justify-center rounded-[14px] bg-accent text-[15px] font-bold"
            >
              {saving ? <Spinner size={22} color="#fff" /> : "Save Schedule"}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
