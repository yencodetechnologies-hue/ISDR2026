/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { useNavigate, useParams, useSearchParams } from "react-router-dom";
import {
  Avatar,
  Button,
  Empty,
  ErrorState,
  Field,
  Icon,
  IconButton,
  Input,
  Loading,
  Page,
  PhotoInput,
  Select,
  TextArea,
  useConfirm,
  useToast,
} from "@/components/ui";
import { del, formData, get, post } from "@/lib/api";
import { fmtDate, fmtTimeStr, idOf, parseDate } from "@/lib/format";

/* =========================================================================
   SCHEDULE LIST (all events' schedules)
========================================================================= */

export function ScheduleList() {
  const navigate = useNavigate();
  const [events, setEvents] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    get("/managed-events").then((r) => {
      setEvents(r.success ? r.events ?? [] : []);
      setLoading(false);
    });
  }, []);

  if (loading) return <Page title="Schedules"><Loading /></Page>;
  if (!events.length) return <Page title="Schedules"><Empty icon="event_busy" title="No events" subtitle="Create an event first." /></Page>;

  return (
    <Page title="Schedules">
      <div className="space-y-2.5">
        {events.map((e) => (
          <button
            key={idOf(e)}
            onClick={() => navigate(`/admin/schedules/event/${idOf(e)}`)}
            className="card flex w-full items-center gap-3 p-4 text-left hover:bg-[#191926]"
          >
            <span className="flex h-12 w-12 items-center justify-center rounded-xl bg-[#F97316]/15">
              <Icon name="calendar_month" size={24} color="#F97316" />
            </span>
            <span className="min-w-0 flex-1">
              <span className="block truncate font-bold">{e.title}</span>
              <span className="block text-xs text-muted">{fmtDate(parseDate(e.eventDate))}</span>
            </span>
            <Icon name="chevron_right" color="#9CA3AF" />
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
    <Page
      title="Event Schedules"
      actions={<Button small icon="add" onClick={() => navigate(`/admin/schedules/new?event=${eventId}`)}>Add</Button>}
    >
      {error ? (
        <ErrorState message={error} onRetry={load} />
      ) : !schedules ? (
        <Loading />
      ) : schedules.length === 0 ? (
        <Empty icon="calendar_month" title="No schedules yet" action={<Button icon="add" onClick={() => navigate(`/admin/schedules/new?event=${eventId}`)}>Add Schedule</Button>} />
      ) : (
        <div className="space-y-2.5">
          {schedules.map((s) => {
            const d = parseDate(s.date);
            return (
              <div key={idOf(s)} className="card flex items-center gap-3 p-3.5">
                {s.speakerPhoto ? (
                  <img src={s.speakerPhoto} alt="" className="h-11 w-11 shrink-0 rounded-full object-cover" />
                ) : (
                  <Avatar name={s.speakerName} size={44} />
                )}
                <div className="min-w-0 flex-1">
                  <div className="truncate font-semibold">{s.scheduleName}</div>
                  <div className="truncate text-xs text-muted">{s.speakerName}{s.hall ? ` · ${s.hall}` : ""}</div>
                  <div className="text-xs text-muted">{fmtDate(d)} · {fmtTimeStr(s.fromTime)} – {fmtTimeStr(s.toTime)}</div>
                </div>
                <IconButton icon="delete" outline color="#EF4444" title="Delete" onClick={() => remove(idOf(s))} />
              </div>
            );
          })}
        </div>
      )}
    </Page>
  );
}

/* =========================================================================
   CREATE SCHEDULE
========================================================================= */

export function ScheduleEditor() {
  const navigate = useNavigate();
  const toast = useToast();
  const [params] = useSearchParams();
  const eventId = params.get("event") ?? "";

  const [speakers, setSpeakers] = useState<any[]>([]);
  const [speakerId, setSpeakerId] = useState("");
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
  }, []);

  const save = async () => {
    if (!scheduleName.trim()) return toast("Enter schedule name", "error");
    if (!date) return toast("Select a date", "error");
    if (!fromTime || !toTime) return toast("Set from/to time", "error");
    const speaker = speakers.find((s) => idOf(s) === speakerId);
    setSaving(true);
    const fd = formData(
      {
        scheduleName: scheduleName.trim(),
        speakerId: speakerId || undefined,
        speakerName: speaker?.name ?? "TBA",
        hall: hall.trim(),
        date,
        fromTime,
        toTime,
        description: description.trim(),
      },
      { photo },
    );
    const res = await post(`/managed-events/${eventId}/schedules`, fd);
    setSaving(false);
    if (!res.success) return toast(res.error || "Could not create schedule", "error");
    toast("Schedule created", "success");
    navigate(-1);
  };

  return (
    <Page title="Add Schedule">
      <div className="space-y-4">
        <Field label="Schedule Name">
          <Input value={scheduleName} onChange={(e) => setScheduleName(e.target.value)} placeholder="e.g. Keynote Address" />
        </Field>
        <Field label="Speaker">
          <Select
            value={speakerId}
            onChange={setSpeakerId}
            placeholder="Select speaker"
            options={speakers.map((s) => ({ value: idOf(s), label: s.name }))}
          />
        </Field>
        <Field label="Hall / Room">
          <Input value={hall} onChange={(e) => setHall(e.target.value)} placeholder="e.g. Main Hall" />
        </Field>
        <Field label="Date">
          <Input type="date" value={date} onChange={(e) => setDate(e.target.value)} />
        </Field>
        <div className="grid grid-cols-2 gap-3">
          <Field label="From Time">
            <Input type="time" value={fromTime} onChange={(e) => setFromTime(e.target.value)} />
          </Field>
          <Field label="To Time">
            <Input type="time" value={toTime} onChange={(e) => setToTime(e.target.value)} />
          </Field>
        </div>
        <Field label="Description">
          <TextArea value={description} onChange={(e) => setDescription(e.target.value)} placeholder="Optional description" />
        </Field>
        <PhotoInput file={photo} url={null} onFile={setPhoto} label="Speaker Photo" round />
        <Button full icon="check" loading={saving} onClick={save}>
          Create Schedule
        </Button>
      </div>
    </Page>
  );
}
