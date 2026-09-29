/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
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
  Select,
  TextArea,
  useConfirm,
  useToast,
} from "@/components/ui";
import { del, formData, get, post, put } from "@/lib/api";
import { fmtDate, fmtTimeStr, idOf, parseDate } from "@/lib/format";

/* =========================================================================
   SCHEDULE TABLE (shared with Event detail)
========================================================================= */

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
  if (!schedules) return <Loading />;
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
        <Button small icon="add" onClick={onAdd}>
          Add Schedule
        </Button>
      </div>
      <div className="overflow-x-auto">
        <table className="data-table">
          <thead>
            <tr>
              <th>Session</th>
              <th>Speaker</th>
              <th>Date</th>
              <th>Time</th>
              <th>Hall</th>
              <th className="w-14 text-right" />
            </tr>
          </thead>
          <tbody>
            {schedules.map((s) => (
              <tr key={idOf(s)}>
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
                <td className="whitespace-nowrap text-white/75">{fmtDate(parseDate(s.date))}</td>
                <td className="whitespace-nowrap text-white/75">
                  {fmtTimeStr(s.fromTime)} – {fmtTimeStr(s.toTime)}
                </td>
                <td className="text-white/75">{s.hall || "—"}</td>
                <td className="text-right">
                  {onEdit && <IconButton icon="edit" outline title="Edit" onClick={() => onEdit(idOf(s))} />}
                  <IconButton icon="delete" outline color="#EF4444" title="Delete" onClick={() => onDelete(idOf(s))} />
                </td>
              </tr>
            ))}
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
  const navigate = useNavigate();
  const [events, setEvents] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

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
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
        {events.map((e) => (
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
        />
      )}
    </Page>
  );
}

/* =========================================================================
   CREATE / EDIT SCHEDULE  (?event=<id>[&schedule=<id>])
========================================================================= */

export function ScheduleEditor() {
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
