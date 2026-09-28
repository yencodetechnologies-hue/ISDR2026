/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { useNavigate, useParams, useSearchParams } from "react-router-dom";
import {
  Avatar,
  Button,
  Empty,
  ErrorState,
  Icon,
  IconButton,
  Input,
  Loading,
  Page,
  Pill,
  SearchBox,
  Tabs,
  TextArea,
  useConfirm,
  useToast,
  Field,
  Select,
  PhotoInput,
} from "@/components/ui";
import { del, formData, get, post, put } from "@/lib/api";
import { fmtDate, fmtTimeStr, fullName, idOf, parseDate, cap } from "@/lib/format";

/* =========================================================================
   EVENT LIST
========================================================================= */

export function EventList() {
  const navigate = useNavigate();
  const [events, setEvents] = useState<any[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    const res = await get("/managed-events");
    if (!res.success) return setError(res.error || "Could not load events");
    setEvents(res.events ?? []);
  }, []);
  useEffect(() => {
    load();
  }, [load]);

  return (
    <Page
      title="Events"
      actions={
        <Button small icon="add" onClick={() => navigate("/admin/events/new")}>
          New
        </Button>
      }
    >
      {error ? (
        <ErrorState message={error} onRetry={load} />
      ) : !events ? (
        <Loading />
      ) : events.length === 0 ? (
        <Empty icon="event" title="No events yet" subtitle="Create your first event." action={<Button icon="add" onClick={() => navigate("/admin/events/new")}>New Event</Button>} />
      ) : (
        <div className="space-y-2.5">
          {events.map((e) => {
            const d = parseDate(e.eventDate);
            const end = parseDate(e.eventEndDate);
            return (
              <button
                key={idOf(e)}
                onClick={() => navigate(`/admin/events/${idOf(e)}`)}
                className="card flex w-full items-center gap-3 p-4 text-left hover:bg-[#191926]"
              >
                {e.photoUrl ? (
                  <img src={e.photoUrl} alt="" className="h-14 w-14 shrink-0 rounded-xl object-cover" />
                ) : (
                  <span className="flex h-14 w-14 shrink-0 items-center justify-center rounded-xl bg-accent/15">
                    <Icon name="event" size={28} color="#3B82F6" />
                  </span>
                )}
                <span className="min-w-0 flex-1">
                  <span className="block truncate font-bold">{e.title}</span>
                  <span className="mt-0.5 block text-xs text-muted">
                    {fmtDate(d)}
                    {end ? ` – ${fmtDate(end)}` : ""}
                  </span>
                  <span className="mt-1 flex items-center gap-3 text-xs text-muted">
                    <span className="flex items-center gap-1">
                      <Icon name="group" size={14} />
                      {e.bookedCount ?? 0}
                    </span>
                    <Pill color={e.status === "published" ? "#22C55E" : e.status === "cancelled" ? "#EF4444" : "#F59E0B"}>
                      {cap(e.status ?? "draft")}
                    </Pill>
                  </span>
                </span>
                <Icon name="chevron_right" color="#9CA3AF" />
              </button>
            );
          })}
        </div>
      )}
    </Page>
  );
}

/* =========================================================================
   CREATE / EDIT EVENT
========================================================================= */

export function EventEditor() {
  const navigate = useNavigate();
  const toast = useToast();
  const [params] = useSearchParams();
  const eventId = params.get("id");
  const editing = !!eventId;
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [venue, setVenue] = useState("");
  const [eventDate, setEventDate] = useState("");
  const [eventEndDate, setEventEndDate] = useState("");
  const [status, setStatus] = useState("published");
  const [photo, setPhoto] = useState<File | null>(null);
  const [photoUrl, setPhotoUrl] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!eventId) return;
    get(`/managed-events/${eventId}`).then((r) => {
      if (!r.success || !r.event) return;
      const e = r.event;
      setTitle(e.title ?? "");
      setDescription(e.description ?? "");
      setVenue(e.venue ?? "");
      setStatus(e.status ?? "published");
      setPhotoUrl(e.photoUrl ?? null);
      const d = parseDate(e.eventDate);
      if (d) setEventDate(`${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`);
      const ed = parseDate(e.eventEndDate);
      if (ed) setEventEndDate(`${ed.getFullYear()}-${String(ed.getMonth() + 1).padStart(2, "0")}-${String(ed.getDate()).padStart(2, "0")}`);
    });
  }, [eventId]);

  const save = async () => {
    if (!title.trim()) return toast("Enter the event title", "error");
    if (!eventDate) return toast("Select the event date", "error");
    setSaving(true);
    const fd = formData(
      { title: title.trim(), description: description.trim(), venue: venue.trim(), eventDate, eventEndDate: eventEndDate || null, status },
      { photo },
    );
    const res = editing ? await put(`/managed-events/${eventId}`, fd) : await post("/managed-events", fd);
    setSaving(false);
    if (!res.success) return toast(res.error || "Could not save event", "error");
    toast(editing ? "Event updated" : "Event created", "success");
    navigate(-1);
  };

  return (
    <Page title={editing ? "Edit Event" : "New Event"}>
      <div className="space-y-4">
        <PhotoInput file={photo} url={photoUrl} onFile={setPhoto} onRemove={() => { setPhoto(null); setPhotoUrl(null); }} label="Event Photo" />
        <Field label="Title">
          <Input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Event title" />
        </Field>
        <Field label="Description">
          <TextArea value={description} onChange={(e) => setDescription(e.target.value)} placeholder="Event description" />
        </Field>
        <Field label="Venue">
          <Input value={venue} onChange={(e) => setVenue(e.target.value)} placeholder="Venue" />
        </Field>
        <div className="grid grid-cols-2 gap-3">
          <Field label="Start Date">
            <Input type="date" value={eventDate} onChange={(e) => setEventDate(e.target.value)} />
          </Field>
          <Field label="End Date">
            <Input type="date" value={eventEndDate} onChange={(e) => setEventEndDate(e.target.value)} />
          </Field>
        </div>
        <Field label="Status">
          <Select value={status} onChange={setStatus} options={[
            { value: "draft", label: "Draft" },
            { value: "published", label: "Published" },
            { value: "cancelled", label: "Cancelled" },
            { value: "completed", label: "Completed" },
          ]} />
        </Field>
        <Button full icon="check" loading={saving} onClick={save}>
          {editing ? "Save Changes" : "Create Event"}
        </Button>
      </div>
    </Page>
  );
}

/* =========================================================================
   EVENT DETAIL — registrations, schedules, and actions
========================================================================= */

export function EventDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const toast = useToast();
  const confirm = useConfirm();
  const [event, setEvent] = useState<any>(null);
  const [registrations, setRegistrations] = useState<any[] | null>(null);
  const [schedules, setSchedules] = useState<any[] | null>(null);
  const [tab, setTab] = useState<"info" | "regs" | "schedules">("info");
  const [search, setSearch] = useState("");
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    const [ev, regs, sch] = await Promise.all([
      get(`/managed-events/${id}`),
      get(`/managed-events/${id}/registrations`),
      get(`/managed-events/${id}/schedules`),
    ]);
    if (!ev.success) return setError(ev.error || "Could not load event");
    setEvent(ev.event);
    setRegistrations(regs.registrations ?? []);
    setSchedules(sch.schedules ?? []);
  }, [id]);
  useEffect(() => {
    load();
  }, [load]);

  const deleteEvent = async () => {
    if (!(await confirm({ title: "Delete event?", message: "This will permanently delete the event and all its data.", confirm: "Delete", danger: true })))
      return;
    const res = await del(`/managed-events/${id}`);
    if (res.success) {
      toast("Event deleted", "success");
      navigate("/admin/events", { replace: true });
    } else toast(res.error || "Could not delete", "error");
  };

  const filteredRegs = (registrations ?? []).filter((r) => {
    if (!search) return true;
    const s = search.toLowerCase();
    return (
      (r.name ?? "").toLowerCase().includes(s) ||
      fullName(r).toLowerCase().includes(s) ||
      (r.mobileNumber ?? "").includes(s) ||
      (r.email ?? "").toLowerCase().includes(s) ||
      (r.idNumber ?? "").toLowerCase().includes(s)
    );
  });

  const deleteReg = async (regId: string) => {
    if (!(await confirm({ title: "Remove participant?", confirm: "Remove", danger: true }))) return;
    const res = await del(`/managed-events/${id}/registrations/${regId}`);
    if (res.success) {
      setRegistrations((l) => (l ?? []).filter((r) => idOf(r) !== regId));
      toast("Participant removed", "success");
    } else toast(res.error || "Could not remove", "error");
  };

  const deleteSchedule = async (sId: string) => {
    if (!(await confirm({ title: "Delete schedule?", confirm: "Delete", danger: true }))) return;
    const res = await del(`/managed-events/${id}/schedules/${sId}`);
    if (res.success) {
      setSchedules((l) => (l ?? []).filter((s) => idOf(s) !== sId));
      toast("Schedule deleted", "success");
    } else toast(res.error || "Could not delete", "error");
  };

  if (error) return <Page title="Event"><ErrorState message={error} onRetry={load} /></Page>;
  if (!event) return <Page title="Event"><Loading /></Page>;

  const d = parseDate(event.eventDate);
  const end = parseDate(event.eventEndDate);

  return (
    <Page
      title={event.title}
      subtitle={`${fmtDate(d)}${end ? ` – ${fmtDate(end)}` : ""}`}
      actions={
        <div className="flex gap-1">
          <IconButton icon="edit" title="Edit" onClick={() => navigate(`/admin/events/new?id=${id}`)} />
          <IconButton icon="delete" title="Delete" color="#EF4444" onClick={deleteEvent} />
        </div>
      }
    >
      <Tabs
        value={tab}
        onChange={setTab}
        tabs={[
          { value: "info", label: "Info" },
          { value: "regs", label: "Participants", count: registrations?.length },
          { value: "schedules", label: "Schedules", count: schedules?.length },
        ]}
      />

      <div className="mt-4">
        {tab === "info" && (
          <div className="space-y-3">
            <div className="card p-4">
              {event.photoUrl && <img src={event.photoUrl} alt="" className="mb-3 h-40 w-full rounded-xl object-cover" />}
              <div className="text-lg font-bold">{event.title}</div>
              {event.venue && (
                <div className="mt-1 flex items-center gap-1.5 text-sm text-muted">
                  <Icon name="location_on" outline size={16} />
                  {event.venue}
                </div>
              )}
              <div className="mt-1 flex items-center gap-1.5 text-sm text-muted">
                <Icon name="calendar_today" outline size={16} />
                {fmtDate(d)}{end ? ` – ${fmtDate(end)}` : ""}
              </div>
              <div className="mt-1 flex items-center gap-1.5 text-sm text-muted">
                <Icon name="group" outline size={16} />
                {event.bookedCount ?? 0} participants
              </div>
              <Pill color={event.status === "published" ? "#22C55E" : "#F59E0B"} >{cap(event.status ?? "draft")}</Pill>
              {event.description && <div className="mt-3 whitespace-pre-wrap text-sm text-white/80">{event.description}</div>}
            </div>
            {(event.packages ?? []).length > 0 && (
              <div className="card p-4">
                <div className="mb-2 text-sm font-bold text-muted">Packages</div>
                <div className="space-y-2">
                  {event.packages.map((p: any) => (
                    <div key={p.id} className="rounded-xl bg-field p-3">
                      <div className="flex items-center justify-between">
                        <div className="font-semibold">{p.name}</div>
                        <div className="text-xs font-bold text-accent">₹{p.rate}</div>
                      </div>
                      {(p.entryExitDates ?? []).length > 0 && (
                        <div className="mt-1 text-xs text-emerald-400 font-semibold flex items-center gap-1">
                          <Icon name="login" size={14} />
                          Entry & Exit: {p.entryExitDates.length} {p.entryExitDates.length === 1 ? "day" : "days"} authorized
                        </div>
                      )}
                      {(p.inclusions ?? []).length > 0 && (
                        <div className="mt-1.5 flex flex-wrap gap-1">
                          {p.inclusions.map((inc: any, i: number) => (
                            <Pill key={i} color="#60A5FA">{inc.name}</Pill>
                          ))}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            )}
            <Button full variant="outline" icon="notifications" onClick={() => navigate(`/admin/send-notification?event=${id}`)}>
              Send Notification to Participants
            </Button>
          </div>
        )}

        {tab === "regs" && (
          <>
            <SearchBox value={search} onChange={setSearch} placeholder="Search participants..." />
            <div className="mt-3 space-y-2">
              {!registrations ? (
                <Loading />
              ) : filteredRegs.length === 0 ? (
                <Empty icon="group_off" title={search ? "No matching participants" : "No participants"} />
              ) : (
                filteredRegs.map((r) => {
                  const name = fullName(r) || r.name || "Participant";
                  return (
                    <div key={idOf(r)} className="card flex items-center gap-3 p-3.5">
                      <Avatar src={r.photoUrl} name={name} size={40} />
                      <div className="min-w-0 flex-1">
                        <div className="truncate font-semibold">{name}</div>
                        <div className="truncate text-xs text-muted">
                          {r.mobileNumber}
                          {r.email ? ` · ${r.email}` : ""}
                        </div>
                        <div className="mt-0.5 flex flex-wrap gap-1.5">
                          {r.packageName && <Pill color="#60A5FA">{r.packageName}</Pill>}
                          <Pill color={r.status === "checked_in" ? "#22C55E" : r.status === "cancelled" ? "#EF4444" : "#F59E0B"}>
                            {cap(r.status ?? "registered")}
                          </Pill>
                          {r.idNumber && <Pill color="#9CA3AF">ID: {r.idNumber}</Pill>}
                        </div>
                      </div>
                      <IconButton icon="delete" outline color="#EF4444" title="Remove" onClick={() => deleteReg(idOf(r))} />
                    </div>
                  );
                })
              )}
            </div>
          </>
        )}

        {tab === "schedules" && (
          <>
            <Button small icon="add" className="mb-3" onClick={() => navigate(`/admin/schedules/new?event=${id}`)}>
              Add Schedule
            </Button>
            <div className="space-y-2">
              {!schedules ? (
                <Loading />
              ) : schedules.length === 0 ? (
                <Empty icon="calendar_month" title="No schedules yet" />
              ) : (
                schedules.map((s) => {
                  const d2 = parseDate(s.date);
                  return (
                    <div key={idOf(s)} className="card flex items-center gap-3 p-3.5">
                      {s.speakerPhoto ? (
                        <img src={s.speakerPhoto} alt="" className="h-11 w-11 shrink-0 rounded-full object-cover" />
                      ) : (
                        <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-accent/15">
                          <Icon name="person" size={22} color="#3B82F6" />
                        </span>
                      )}
                      <div className="min-w-0 flex-1">
                        <div className="truncate font-semibold">{s.scheduleName}</div>
                        <div className="truncate text-xs text-muted">
                          {s.speakerName}
                          {s.hall ? ` · ${s.hall}` : ""}
                        </div>
                        <div className="text-xs text-muted">
                          {fmtDate(d2)} · {fmtTimeStr(s.fromTime)} – {fmtTimeStr(s.toTime)}
                        </div>
                      </div>
                      <IconButton icon="delete" outline color="#EF4444" title="Delete" onClick={() => deleteSchedule(idOf(s))} />
                    </div>
                  );
                })
              )}
            </div>
          </>
        )}
      </div>
    </Page>
  );
}
