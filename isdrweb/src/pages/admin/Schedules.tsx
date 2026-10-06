/* eslint-disable @typescript-eslint/no-explicit-any */
import { Fragment, useCallback, useEffect, useState } from "react";
import { useNavigate, useParams, useSearchParams } from "react-router-dom";
import {
  Avatar,
  Button,
  Checkbox,
  Empty,
  ErrorState,
  Field,
  Icon,
  IconButton,
  Input,
  Loading,
  Page,
  Panel,
  PhotoInput,
  SearchBox,
  Select,
  TextArea,
  useConfirm,
  useToast,
} from "@/components/ui";
import { del, formData, get, post, put } from "@/lib/api";
import { FilterSelect, distinct, matches } from "@/components/ListFilters";
import ExportMenu from "@/components/ExportMenu";
import { fmtDate, fmtDayDate, fmtTimeStr, idOf, parseDate } from "@/lib/format";
import { useAppLayout } from "@/lib/appLayout";
import { EventScheduleListApp, EventSchedulesApp, ScheduleFormApp } from "./SchedulesApp";

/* =========================================================================
   SCHEDULE TABLE (shared with Event detail)
========================================================================= */

/** Calendar day a schedule is stored on (UTC date, shown as a local heading). */
function scheduleCalendarDay(s: any): Date | null {
  const d = parseDate(s?.date);
  if (!d) return null;
  return new Date(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
}

/** Day, then start time, then end time. A later update comes after a shared slot. */
function compareSchedules(a: any, b: any) {
  const da = scheduleCalendarDay(a)?.getTime() ?? 0;
  const db = scheduleCalendarDay(b)?.getTime() ?? 0;
  if (da !== db) return da - db;
  const from = String(a.fromTime ?? "").localeCompare(String(b.fromTime ?? ""));
  if (from) return from;
  const to = String(a.toTime ?? "").localeCompare(String(b.toTime ?? ""));
  if (to) return to;
  return (parseDate(a.updatedAt)?.getTime() ?? 0) - (parseDate(b.updatedAt)?.getTime() ?? 0);
}

type OrderedSchedule = { s: any; serial: number; dayKey: string; dayLabel: string };

/** Per-day serial numbers, restarting at 1 each calendar day. */
function orderSchedules(schedules: any[]): OrderedSchedule[] {
  const counts = new Map<string, number>();
  return [...schedules].sort(compareSchedules).map((s) => {
    const day = scheduleCalendarDay(s);
    const dayKey = day ? String(day.getTime()) : "";
    const serial = (counts.get(dayKey) ?? 0) + 1;
    counts.set(dayKey, serial);
    return { s, serial, dayKey, dayLabel: day ? fmtDayDate(day) : "No date" };
  });
}

export function ScheduleTable({
  schedules,
  onAdd,
  onDelete,
  onEdit,
}: {
  schedules: any[] | null;
  onAdd: () => void;
  onDelete: (id: string) => void;
  onEdit?: (id: string) => void;
}) {
  const [search, setSearch] = useState("");
  const [dateFilter, setDateFilter] = useState("");
  const [hallFilter, setHallFilter] = useState("");
  const [speakerFilter, setSpeakerFilter] = useState("");
  if (!schedules) return <Loading />;
  const ordered = orderSchedules(schedules);
  const dayOf = (s: any) => {
    const day = scheduleCalendarDay(s);
    return day ? fmtDate(day) : "";
  };
  const shown = ordered.filter(
    ({ s }) =>
      matches(s, search) &&
      (!dateFilter || dayOf(s) === dateFilter) &&
      (!hallFilter || (s.hall ?? "") === hallFilter) &&
      (!speakerFilter || (s.speakerName ?? "") === speakerFilter),
  );
  if (schedules.length === 0)
    return (
      <Empty
        icon="calendar_month"
        title="No schedules yet"
        action={
          <Button icon="add" onClick={onAdd}>
            Add Schedule
          </Button>
        }
      />
    );
  return (
    <div className="card overflow-hidden">
      <div className="flex items-center gap-3 border-b border-line px-5 py-4">
        <div className="flex-1 text-sm text-muted">
          {schedules.length} {schedules.length === 1 ? "session" : "sessions"}
        </div>
        <ExportMenu
          small
          title="Schedules"
          rows={shown.map((row) => ({ ...row.s, serial: row.serial }))}
          columns={[
            { header: "S.No", value: (s: any) => s.serial, width: 8 },
            { header: "Session", value: (s: any) => s.scheduleName, width: 30 },
            { header: "Speaker", value: (s: any) => s.speakerName, width: 20 },
            { header: "Date", value: (s: any) => dayOf(s), width: 14 },
            { header: "From", value: (s: any) => fmtTimeStr(s.fromTime), width: 10 },
            { header: "To", value: (s: any) => fmtTimeStr(s.toTime), width: 10 },
            { header: "Hall", value: (s: any) => s.hall, width: 14 },
          ]}
        />
        <Button small icon="add" onClick={onAdd}>
          Add Schedule
        </Button>
      </div>
      <div className="flex flex-wrap items-center gap-2 border-b border-line px-5 py-3">
        <div className="w-full sm:w-72">
          <SearchBox value={search} onChange={setSearch} placeholder="Search session, speaker, hall…" />
        </div>
        <FilterSelect
          label="dates"
          value={dateFilter}
          onChange={setDateFilter}
          options={[...new Set(ordered.map((row) => dayOf(row.s)).filter(Boolean))]}
        />
        <FilterSelect
          label="halls"
          value={hallFilter}
          onChange={setHallFilter}
          options={distinct(schedules.map((s) => s.hall))}
        />
        <FilterSelect
          label="speakers"
          value={speakerFilter}
          onChange={setSpeakerFilter}
          options={distinct(schedules.map((s) => s.speakerName))}
        />
      </div>
      {shown.length === 0 && (
        <div className="px-5 py-8 text-center text-sm text-muted">No sessions match your search / filters.</div>
      )}
      <div className="overflow-x-auto">
        <table className="data-table">
          <thead>
            <tr>
              <th className="w-14">S.No</th>
              <th>Session</th>
              <th>Speaker</th>
              <th>Date</th>
              <th>Time</th>
              <th>Hall</th>
              <th className="w-24 text-right" />
            </tr>
          </thead>
          <tbody>
            {shown.map((row, i) => {
              const s = row.s;
              const showDay = i === 0 || row.dayKey !== shown[i - 1].dayKey;
              return (
                <Fragment key={idOf(s)}>
                  {showDay && (
                    <tr className="bg-white/[0.03] hover:bg-white/[0.03]">
                      <td colSpan={7} className="py-2 text-[11px] font-semibold uppercase tracking-wider text-muted">
                        {row.dayLabel}
                      </td>
                    </tr>
                  )}
                  <tr>
                    <td className="tabular-nums text-muted">{row.serial}</td>
                    <td className="font-medium">{s.scheduleName}</td>
                    <td>
                      <div className="flex items-center gap-2.5">
                        {s.speakerPhoto ? (
                          <img src={s.speakerPhoto} alt="" className="h-8 w-8 shrink-0 rounded-full object-cover" />
                        ) : (
                          <Avatar name={s.speakerName} size={32} />
                        )}
                        <span className="text-white/80">{s.speakerName || "—"}</span>
                      </div>
                    </td>
                    <td className="whitespace-nowrap text-white/75">{dayOf(s)}</td>
                    <td className="whitespace-nowrap text-white/75">
                      {fmtTimeStr(s.fromTime)} – {fmtTimeStr(s.toTime)}
                    </td>
                    <td className="text-white/75">{s.hall || "—"}</td>
                    <td className="whitespace-nowrap text-right align-middle">
                      <span className="inline-flex items-center justify-end">
                        {onEdit && <IconButton icon="edit" outline title="Edit" onClick={() => onEdit(idOf(s))} />}
                        <IconButton
                          icon="delete"
                          outline
                          color="#EF4444"
                          title="Delete"
                          onClick={() => onDelete(idOf(s))}
                        />
                      </span>
                    </td>
                  </tr>
                </Fragment>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}

/* =========================================================================
   SCHEDULE LIST (all events' schedules)
========================================================================= */

export function ScheduleList() {
  // Phone width: the mobile app's screen.
  return useAppLayout() ? <EventSchedulesApp /> : <ScheduleListWeb />;
}

function ScheduleListWeb() {
  const navigate = useNavigate();
  const [events, setEvents] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");

  useEffect(() => {
    get("/managed-events").then((r) => {
      setEvents(r.success ? (r.events ?? []) : []);
      setLoading(false);
    });
  }, []);

  if (loading)
    return (
      <Page title="Schedules">
        <Loading />
      </Page>
    );
  if (!events.length)
    return (
      <Page title="Schedules">
        <Empty icon="event_busy" title="No events" subtitle="Create an event first." />
      </Page>
    );

  return (
    <Page title="Schedules" subtitle="Choose an event to manage its sessions" back={false}>
      <div className="mb-4 w-full sm:w-80">
        <SearchBox value={search} onChange={setSearch} placeholder="Search events…" />
      </div>
      {events.filter((e) => matches(e, search)).length === 0 && (
        <div className="mb-4 rounded-xl border border-line px-5 py-8 text-center text-sm text-muted">
          No events match your search.
        </div>
      )}
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
        {events
          .filter((e) => matches(e, search))
          .map((e) => (
            <button
              key={idOf(e)}
              onClick={() => navigate(`/admin/schedules/event/${idOf(e)}`)}
              className="card card-hover group flex w-full items-center gap-4 p-5 text-left"
            >
              <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-lg bg-[#F97316]/15">
                <Icon name="calendar_month" size={24} color="#F97316" />
              </span>
              <span className="min-w-0 flex-1">
                <span className="block truncate font-semibold group-hover:text-[#93C5FD]">{e.title}</span>
                <span className="block text-xs text-muted">{fmtDate(parseDate(e.eventDate))}</span>
              </span>
              <Icon name="arrow_forward" size={18} color="#6B7280" />
            </button>
          ))}
      </div>
    </Page>
  );
}

/* =========================================================================
   EVENT SCHEDULES
========================================================================= */

export function EventSchedules() {
  // Phone width: the mobile app's screen.
  return useAppLayout() ? <EventScheduleListApp /> : <EventSchedulesWeb />;
}

function EventSchedulesWeb() {
  const navigate = useNavigate();
  const toast = useToast();
  const confirm = useConfirm();
  const { eventId = "" } = useParams<{ eventId: string }>();

  const [schedules, setSchedules] = useState<any[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    const res = await get(`/managed-events/${eventId}/schedules`);
    if (!res.success) return setError(res.error || "Could not load schedules");
    setSchedules(res.schedules ?? []);
  }, [eventId]);
  useEffect(() => {
    load();
  }, [load]);

  const remove = async (sId: string) => {
    if (!(await confirm({ title: "Delete schedule?", confirm: "Delete", danger: true }))) return;
    const res = await del(`/managed-events/${eventId}/schedules/${sId}`);
    if (res.success) {
      setSchedules((l) => (l ?? []).filter((s) => idOf(s) !== sId));
      toast("Schedule deleted", "success");
    } else toast(res.error || "Could not delete", "error");
  };

  return (
    <Page title="Event Schedules" subtitle="Sessions in this event">
      {error ? (
        <ErrorState message={error} onRetry={load} />
      ) : (
        <ScheduleTable
          schedules={schedules}
          onAdd={() => navigate(`/admin/schedules/new?event=${eventId}`)}
          onDelete={remove}
          onEdit={(sId) => navigate(`/admin/schedules/new?event=${eventId}&schedule=${sId}`)}
        />
      )}
    </Page>
  );
}

/* =========================================================================
   CREATE / EDIT SCHEDULE  (?event=<id>[&schedule=<id>])
========================================================================= */

export function ScheduleEditor() {
  // Phone width: the mobile app's screen.
  return useAppLayout() ? <ScheduleFormApp /> : <ScheduleEditorWeb />;
}

function ScheduleEditorWeb() {
  const navigate = useNavigate();
  const toast = useToast();
  const [params] = useSearchParams();
  const eventId = params.get("event") ?? "";
  const scheduleId = params.get("schedule") ?? "";
  const editing = !!scheduleId;

  const [event, setEvent] = useState<any>(null);
  const [existing, setExisting] = useState<any>(null);
  const [speakers, setSpeakers] = useState<any[]>([]);
  const [speakerId, setSpeakerId] = useState("");
  const [packageIds, setPackageIds] = useState<string[]>([]);
  const [scheduleName, setScheduleName] = useState("");
  const [hall, setHall] = useState("");
  const [date, setDate] = useState("");
  const [fromTime, setFromTime] = useState("");
  const [toTime, setToTime] = useState("");
  const [description, setDescription] = useState("");
  const [photo, setPhoto] = useState<File | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    get("/speakers").then((r) => r.success && setSpeakers(r.speakers ?? []));
    get(`/managed-events/${eventId}`).then((r) => r.success && setEvent(r.event));
    if (!scheduleId) return;
    get(`/managed-events/${eventId}/schedules`).then((r) => {
      const s = (r.schedules ?? []).find((x: any) => idOf(x) === scheduleId);
      if (!s) return toast("Schedule not found", "error");
      setExisting(s);
      setSpeakerId(String(s.speakerId ?? ""));
      setPackageIds((s.packageIds ?? []).map(String));
      setScheduleName(s.scheduleName ?? "");
      setHall(s.hall ?? "");
      setDate(String(s.date ?? "").slice(0, 10));
      setFromTime(s.fromTime ?? "");
      setToTime(s.toTime ?? "");
      setDescription(s.description ?? "");
    });
  }, [eventId, scheduleId, toast]);

  const packages: any[] = event?.packages ?? [];
  // Old schedules may only have a speaker name (no linked speaker account).
  const legacySpeaker = editing && existing && !existing.speakerId ? String(existing.speakerName ?? "") : "";

  const save = async () => {
    if (!speakerId && !legacySpeaker) return toast("Select a speaker", "error");
    if (!packageIds.length && !(editing && existing && !(existing.packageIds ?? []).length))
      return toast("Select at least one package", "error");
    if (!scheduleName.trim()) return toast("Enter schedule name", "error");
    if (!date) return toast("Select a date", "error");
    if (!fromTime || !toTime) return toast("Set from/to time", "error");
    if (toTime <= fromTime) return toast("To time must be after from time", "error");
    setSaving(true);
    const fields = {
      scheduleName: scheduleName.trim(),
      speakerId,
      packageIds,
      hall: hall.trim(),
      date,
      fromTime,
      toTime,
      description: description.trim(),
    };
    const res = editing
      ? await put(`/managed-events/${eventId}/schedules/${scheduleId}`, fields)
      : await post(`/managed-events/${eventId}/schedules`, formData(fields, { photo }));
    setSaving(false);
    if (!res.success)
      return toast(res.error || (editing ? "Could not update schedule" : "Could not create schedule"), "error");
    toast(editing ? "Schedule updated" : "Schedule created", "success");
    navigate(-1);
  };

  return (
    <Page title={editing ? "Edit Schedule" : "Add Schedule"} subtitle={event?.title} width={1000}>
      <div className="grid gap-5 lg:grid-cols-3">
        <Panel className="lg:col-span-2" title="Session" icon="event_note" iconColor="#F97316">
          <div className="space-y-4">
            <Field label="Schedule Name *">
              <Input
                value={scheduleName}
                onChange={(e) => setScheduleName(e.target.value)}
                placeholder="e.g. Keynote Address"
              />
            </Field>
            <div className="grid gap-4 sm:grid-cols-2">
              <Field label="Speaker *" hint={legacySpeaker && !speakerId ? `Currently: ${legacySpeaker}` : undefined}>
                <Select
                  value={speakerId}
                  onChange={setSpeakerId}
                  placeholder={legacySpeaker ? `Keep "${legacySpeaker}"` : "Select speaker"}
                  options={speakers.map((s) => ({ value: idOf(s), label: s.name }))}
                />
              </Field>
              <Field label="Hall / Room">
                <Input value={hall} onChange={(e) => setHall(e.target.value)} placeholder="e.g. Main Hall" />
              </Field>
            </div>
            <div className="grid gap-4 sm:grid-cols-3">
              <Field label="Date *">
                <Input type="date" value={date} onChange={(e) => setDate(e.target.value)} />
              </Field>
              <Field label="From Time *">
                <Input type="time" value={fromTime} onChange={(e) => setFromTime(e.target.value)} />
              </Field>
              <Field label="To Time *">
                <Input type="time" value={toTime} onChange={(e) => setToTime(e.target.value)} />
              </Field>
            </div>
            <Field label="Description">
              <TextArea
                rows={5}
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="Optional description"
              />
            </Field>
          </div>
        </Panel>
        <div className="space-y-5">
          <Panel title="Packages *" subtitle="Who can see this session" icon="inventory_2" iconColor="#A855F7">
            {packages.length === 0 ? (
              <div className="text-sm text-muted">Add a package to this event first.</div>
            ) : (
              <div className="space-y-2.5">
                {packages.map((p) => {
                  const pid = String(p.id);
                  return (
                    <Checkbox
                      key={pid}
                      checked={packageIds.includes(pid)}
                      onChange={(on) => setPackageIds((l) => (on ? [...l, pid] : l.filter((x) => x !== pid)))}
                      label={p.name}
                    />
                  );
                })}
              </div>
            )}
          </Panel>
          {!editing && (
            <Panel title="Speaker Photo" icon="account_circle" iconColor="#A855F7">
              <PhotoInput file={photo} url={null} onFile={setPhoto} label="Speaker Photo" round />
            </Panel>
          )}
          <Button full icon="check" loading={saving} onClick={save}>
            {editing ? "Save Changes" : "Create Schedule"}
          </Button>
        </div>
      </div>
    </Page>
  );
}
