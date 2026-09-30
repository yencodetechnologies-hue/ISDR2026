/* eslint-disable @typescript-eslint/no-explicit-any */
import { Fragment, useCallback, useEffect, useState } from "react";
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
  Panel,
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
import { del, formData, get, post, put, qs } from "@/lib/api";
import { PARTICIPANT_EXPORT_COLUMNS, PARTICIPANT_QR } from "./participantExport";
import EventDetailApp from "./EventDetailApp";
import { useAppLayout } from "@/lib/appLayout";
import EventsApp from "./EventsApp";
import { FilterSelect, distinct, matches } from "@/components/ListFilters";
import ExportMenu from "@/components/ExportMenu";
import { fmtDate, idOf, parseDate, cap } from "@/lib/format";
import { BadgeModal, ClaimsModal, displayName, PackageCard, PackageModal, ParticipantModal } from "./EventManage";
import { ImportParticipantsModal } from "./ImportParticipants";
import { ScheduleTable } from "./Schedules";
import EventFormApp from "./EventFormApp";

/* =========================================================================
   EVENT LIST
========================================================================= */

export function EventList() {
  // Phone width: the mobile app's Events screen.
  return useAppLayout() ? <EventsApp /> : <EventListWeb />;
}

function EventListWeb() {
  const navigate = useNavigate();
  const [events, setEvents] = useState<any[] | null>(null);
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    const res = await get("/managed-events");
    if (!res.success) return setError(res.error || "Could not load events");
    setEvents(res.events ?? []);
  }, []);
  useEffect(() => {
    load();
  }, [load]);

  const shownEvents = (events ?? []).filter(
    (e) => matches(e, search) && (!statusFilter || (e.status ?? "draft") === statusFilter),
  );

  return (
    <Page
      title="Events"
      subtitle={events ? `${events.length} ${events.length === 1 ? "event" : "events"}` : undefined}
      actions={
        <div className="flex flex-wrap gap-2">
          <ExportMenu
            title="Events"
            rows={shownEvents}
            columns={[
              { header: "Title", value: (e: any) => e.title, width: 30 },
              { header: "Status", value: (e: any) => cap(e.status ?? "draft"), width: 12 },
              { header: "Start date", value: (e: any) => fmtDate(parseDate(e.eventDate)), width: 14 },
              {
                header: "End date",
                value: (e: any) => (e.eventEndDate ? fmtDate(parseDate(e.eventEndDate)) : ""),
                width: 14,
              },
              { header: "Venue", value: (e: any) => e.venue, width: 30 },
              { header: "Packages", value: (e: any) => (e.packages ?? []).length, width: 10 },
              { header: "Participants", value: (e: any) => e.bookedCount ?? 0, width: 12 },
            ]}
          />
          <Button icon="add" onClick={() => navigate("/admin/events/new")}>
            New Event
          </Button>
        </div>
      }
    >
      {error ? (
        <ErrorState message={error} onRetry={load} />
      ) : !events ? (
        <Loading />
      ) : events.length === 0 ? (
        <Empty
          icon="event"
          title="No events yet"
          subtitle="Create your first event."
          action={
            <Button icon="add" onClick={() => navigate("/admin/events/new")}>
              New Event
            </Button>
          }
        />
      ) : (
        <>
          <div className="mb-4 flex flex-wrap items-center gap-3">
            <div className="w-full sm:w-80">
              <SearchBox value={search} onChange={setSearch} placeholder="Search events, venue…" />
            </div>
            <FilterSelect
              label="statuses"
              value={statusFilter}
              onChange={setStatusFilter}
              options={distinct(events.map((e) => e.status ?? "draft")).map((s) => ({ value: s, label: cap(s) }))}
            />
          </div>
          {shownEvents.length === 0 && (
            <div className="mb-4 rounded-xl border border-line px-5 py-8 text-center text-sm text-muted">
              No results match your search / filters.
            </div>
          )}
          <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
            {shownEvents.map((e) => {
              const d = parseDate(e.eventDate);
              const end = parseDate(e.eventEndDate);
              return (
                <button
                  key={idOf(e)}
                  onClick={() => navigate(`/admin/events/${idOf(e)}`)}
                  className="card card-hover group overflow-hidden text-left"
                >
                  <div className="relative">
                    {e.photoUrl ? (
                      <img src={e.photoUrl} alt="" className="h-36 w-full object-cover" />
                    ) : (
                      <div className="flex h-36 items-center justify-center bg-gradient-to-br from-[#1E3A8A]/60 to-card">
                        <Icon name="event" size={44} color="#60A5FA" />
                      </div>
                    )}
                    <span className="absolute right-3 top-3">
                      <Pill
                        color={e.status === "published" ? "#22C55E" : e.status === "cancelled" ? "#EF4444" : "#F59E0B"}
                      >
                        {cap(e.status ?? "draft")}
                      </Pill>
                    </span>
                  </div>
                  <div className="p-4">
                    <div className="truncate font-semibold group-hover:text-[#93C5FD]">{e.title}</div>
                    <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-muted">
                      <span className="flex items-center gap-1">
                        <Icon name="calendar_today" size={14} outline />
                        {fmtDate(d)}
                        {end ? ` – ${fmtDate(end)}` : ""}
                      </span>
                      <span className="flex items-center gap-1">
                        <Icon name="group" size={14} outline />
                        {e.bookedCount ?? 0} participants
                      </span>
                    </div>
                  </div>
                </button>
              );
            })}
          </div>
        </>
      )}
    </Page>
  );
}

/* =========================================================================
   CREATE / EDIT EVENT
========================================================================= */

export function EventEditor() {
  // Phone width: the mobile app's screen.
  return useAppLayout() ? <EventFormApp /> : <EventEditorWeb />;
}

function EventEditorWeb() {
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
      if (d)
        setEventDate(
          `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`,
        );
      const ed = parseDate(e.eventEndDate);
      if (ed)
        setEventEndDate(
          `${ed.getFullYear()}-${String(ed.getMonth() + 1).padStart(2, "0")}-${String(ed.getDate()).padStart(2, "0")}`,
        );
    });
  }, [eventId]);

  const save = async () => {
    if (!title.trim()) return toast("Enter the event title", "error");
    if (!eventDate) return toast("Select the event date", "error");
    setSaving(true);
    const fd = formData(
      {
        title: title.trim(),
        description: description.trim(),
        venue: venue.trim(),
        eventDate,
        eventEndDate: eventEndDate || null,
        status,
      },
      { photo },
    );
    const res = editing ? await put(`/managed-events/${eventId}`, fd) : await post("/managed-events", fd);
    setSaving(false);
    if (!res.success) return toast(res.error || "Could not save event", "error");
    toast(editing ? "Event updated" : "Event created", "success");
    navigate(-1);
  };

  return (
    <Page title={editing ? "Edit Event" : "New Event"} subtitle="Event details shown to participants" width={1000}>
      <div className="grid gap-5 lg:grid-cols-3">
        <Panel className="lg:col-span-2" title="Details" icon="edit_note">
          <div className="space-y-4">
            <Field label="Title">
              <Input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Event title" />
            </Field>
            <Field label="Description">
              <TextArea
                rows={5}
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="Event description"
              />
            </Field>
            <Field label="Venue">
              <Input icon="location_on" value={venue} onChange={(e) => setVenue(e.target.value)} placeholder="Venue" />
            </Field>
            <div className="grid gap-4 sm:grid-cols-2">
              <Field label="Start Date">
                <Input type="date" value={eventDate} onChange={(e) => setEventDate(e.target.value)} />
              </Field>
              <Field label="End Date">
                <Input type="date" value={eventEndDate} onChange={(e) => setEventEndDate(e.target.value)} />
              </Field>
            </div>
          </div>
        </Panel>
        <div className="space-y-5">
          <Panel title="Event Photo" icon="image" iconColor="#EC4899">
            <PhotoInput
              file={photo}
              url={photoUrl}
              onFile={setPhoto}
              onRemove={() => {
                setPhoto(null);
                setPhotoUrl(null);
              }}
              label="Event Photo"
            />
          </Panel>
          <Panel title="Publishing" icon="public" iconColor="#22C55E">
            <Field label="Status">
              <Select
                value={status}
                onChange={setStatus}
                options={[
                  { value: "draft", label: "Draft" },
                  { value: "published", label: "Published" },
                  { value: "cancelled", label: "Cancelled" },
                  { value: "completed", label: "Completed" },
                ]}
              />
            </Field>
            <Button full icon="check" className="mt-5" loading={saving} onClick={save}>
              {editing ? "Save Changes" : "Create Event"}
            </Button>
          </Panel>
        </div>
      </div>
    </Page>
  );
}

/* =========================================================================
   EVENT DETAIL — overview, packages, participants, schedules
   (mirrors the app's event_management_details_page.dart)
========================================================================= */

export function EventDetail() {
  // Phone width: the mobile app's event screen.
  return useAppLayout() ? <EventDetailApp /> : <EventDetailWeb />;
}

function EventDetailWeb() {
  const { id = "" } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const toast = useToast();
  const confirm = useConfirm();
  const [event, setEvent] = useState<any>(null);
  const [registrations, setRegistrations] = useState<any[] | null>(null);
  const [schedules, setSchedules] = useState<any[] | null>(null);
  const [incStats, setIncStats] = useState<Record<string, any>>({});
  const [tab, setTab] = useState<"info" | "packages" | "regs" | "schedules">("info");
  const [search, setSearch] = useState("");
  const [pkgFilter, setPkgFilter] = useState("");
  const [typeFilter, setTypeFilter] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [claimFilter, setClaimFilter] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [expanded, setExpanded] = useState<Set<string>>(new Set());
  const [pkgEditing, setPkgEditing] = useState<any | null | undefined>(undefined); // undefined = closed, null = new
  const [regEditing, setRegEditing] = useState<any | null | undefined>(undefined);
  const [badgeFor, setBadgeFor] = useState<any | null>(null);
  const [claimsFor, setClaimsFor] = useState<any | null>(null);
  const [importing, setImporting] = useState(false);

  const loadStats = useCallback(async () => {
    const res = await get(`/managed-events/summary${qs({ eventId: id, date: "to-date" })}`);
    if (!res.success) return;
    const rows: any[] = res.summary?.inclusions ?? [];
    setIncStats(Object.fromEntries(rows.map((r) => [`${r.packageName}|${r.name}`, r])));
  }, [id]);

  const loadRegs = useCallback(async () => {
    const regs = await get(`/managed-events/${id}/registrations`);
    // Keep the list on screen if a background refresh fails.
    if (regs.success) setRegistrations(regs.registrations ?? []);
  }, [id]);

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
    loadStats();
  }, [id, loadStats]);
  useEffect(() => {
    load();
  }, [load]);
  // Re-check every few seconds so claims scanned at the counters show up right away.
  useEffect(() => {
    const t = setInterval(() => {
      loadRegs();
      loadStats();
    }, 4000);
    return () => clearInterval(t);
  }, [loadRegs, loadStats]);

  const packages: any[] = event?.packages ?? [];
  const isCancelled = event?.status === "cancelled";

  const deleteEvent = async () => {
    if (
      !(await confirm({
        title: `Delete "${event?.title}" and all its participants permanently?`,
        confirm: "Delete",
        cancel: "No",
        danger: true,
      }))
    )
      return;
    setBusy(true);
    const res = await del(`/managed-events/${id}?permanent=true`);
    setBusy(false);
    if (res.success) {
      toast("Event deleted", "success");
      navigate("/admin/events", { replace: true });
    } else toast(res.error || "Delete failed", "error");
  };

  const savePackages = async (next: any[], okMessage: string) => {
    setBusy(true);
    const res = await put(`/managed-events/${id}`, { packages: next });
    setBusy(false);
    if (!res.success) {
      toast(res.error || "Failed to save package", "error");
      return false;
    }
    if (res.event) setEvent(res.event);
    loadStats();
    toast(okMessage, "success");
    return true;
  };

  const removePackage = async (pkgId: string) => {
    if (!(await confirm({ title: "Remove this package?", confirm: "Remove", cancel: "No", danger: true }))) return;
    await savePackages(
      packages.filter((p) => p.id !== pkgId),
      "Package removed",
    );
  };

  const deleteReg = async (r: any) => {
    if (
      !(await confirm({ title: `Delete registration for "${r.name}"?`, confirm: "Delete", cancel: "No", danger: true }))
    )
      return;
    setBusy(true);
    const res = await del(`/managed-events/${id}/registrations/${idOf(r)}`);
    setBusy(false);
    if (res.success) {
      toast("Participant deleted", "success");
      load();
    } else toast(res.error || "Failed to delete participant", "error");
  };

  const deleteSchedule = async (sId: string) => {
    if (!(await confirm({ title: "Delete schedule?", confirm: "Delete", danger: true }))) return;
    const res = await del(`/managed-events/${id}/schedules/${sId}`);
    if (res.success) {
      setSchedules((l) => (l ?? []).filter((s) => idOf(s) !== sId));
      toast("Schedule deleted", "success");
    } else toast(res.error || "Could not delete", "error");
  };

  // Search every text / number field, like the app.
  const q = search.trim().toLowerCase();
  const filteredRegs = (registrations ?? []).filter(
    (r) =>
      (!q ||
        Object.values(r).some(
          (v) => (typeof v === "string" || typeof v === "number") && String(v).toLowerCase().includes(q),
        )) &&
      (!pkgFilter || (r.packageName ?? "") === pkgFilter) &&
      (!typeFilter || (r.participantType || "Delegate") === typeFilter) &&
      (!statusFilter || (r.status ?? "registered") === statusFilter) &&
      (!claimFilter || (claimFilter === "claimed") === (r.claimedInclusions ?? []).length > 0),
  );
  const regsFiltered = !!(q || pkgFilter || typeFilter || statusFilter || claimFilter);

  const existingIds = (self: any | null) =>
    new Set(
      (registrations ?? [])
        .filter((r) => !self || idOf(r) !== idOf(self))
        .map((r) => String(r.idNumber ?? "").trim())
        .filter(Boolean),
    );

  const toggleExpanded = (regId: string) =>
    setExpanded((s) => {
      const n = new Set(s);
      if (n.has(regId)) n.delete(regId);
      else n.add(regId);
      return n;
    });

  if (error)
    return (
      <Page title="Event">
        <ErrorState message={error} onRetry={load} />
      </Page>
    );
  if (!event)
    return (
      <Page title="Event">
        <Loading />
      </Page>
    );

  const d = parseDate(event.eventDate);
  const end = parseDate(event.eventEndDate);

  const info = (label: string, value: string) =>
    value ? (
      <div>
        <div className="text-xs text-muted">{label}</div>
        <div className="mt-0.5 text-sm">{value}</div>
      </div>
    ) : null;

  return (
    <Page
      title={event.title}
      subtitle={`${fmtDate(d)}${end ? ` – ${fmtDate(end)}` : ""}`}
      actions={
        <>
          <Button
            variant="outline"
            icon="notifications"
            onClick={() => navigate(`/admin/send-notification?event=${id}`)}
          >
            Notify
          </Button>
          <Button variant="outline" icon="edit" disabled={busy} onClick={() => navigate(`/admin/events/new?id=${id}`)}>
            Edit
          </Button>
          <Button variant="danger" icon="delete" disabled={busy} onClick={deleteEvent}>
            Delete
          </Button>
        </>
      }
    >
      <Tabs
        value={tab}
        onChange={setTab}
        tabs={[
          { value: "info", label: "Overview" },
          { value: "packages", label: "Packages", count: packages.length },
          { value: "regs", label: "Participants", count: registrations?.length },
          { value: "schedules", label: "Schedules", count: schedules?.length },
        ]}
      />

      <div className="mt-5">
        {tab === "info" && (
          <div className="grid gap-5 lg:grid-cols-3">
            <div className="card overflow-hidden lg:col-span-2">
              {event.photoUrl && <img src={event.photoUrl} alt="" className="h-56 w-full object-cover" />}
              <div className="p-6">
                <div className="flex flex-wrap items-center gap-3">
                  <div className="flex-1 text-xl font-semibold">{event.title}</div>
                  <Pill color={isCancelled ? "#EF4444" : event.status === "published" ? "#22C55E" : "#F59E0B"}>
                    {cap(event.status ?? "Active")}
                  </Pill>
                </div>
                <div className="mt-3 grid gap-3 sm:grid-cols-3">
                  {[
                    {
                      icon: "calendar_today",
                      label: "Dates",
                      value: `${fmtDate(d)}${end ? ` – ${fmtDate(end)}` : ""}`,
                    },
                    { icon: "location_on", label: "Venue", value: event.venue || "—" },
                    { icon: "group", label: "Registered", value: String(event.bookedCount ?? 0) },
                  ].map((x) => (
                    <div key={x.label} className="rounded-lg border border-line bg-white/[0.02] p-3">
                      <div className="flex items-center gap-1.5 text-xs text-muted">
                        <Icon name={x.icon} outline size={15} />
                        {x.label}
                      </div>
                      <div className="mt-1 text-sm font-semibold">{x.value}</div>
                    </div>
                  ))}
                </div>
                {event.description && (
                  <div className="mt-4 whitespace-pre-wrap text-sm leading-relaxed text-white/80">
                    {event.description}
                  </div>
                )}
              </div>
            </div>
            <div className="space-y-3 self-start">
              <button
                onClick={() => setTab("packages")}
                className="card card-hover flex w-full items-center gap-3 p-4 text-left"
              >
                <span className="flex h-10 w-10 items-center justify-center rounded-lg bg-[#A855F7]/15">
                  <Icon name="inventory_2" color="#A855F7" />
                </span>
                <span className="flex-1">
                  <span className="block font-semibold">Packages</span>
                  <span className="block text-xs text-muted">{packages.length} packages · add or edit</span>
                </span>
                <Icon name="chevron_right" color="#6B7280" />
              </button>
              <button
                onClick={() => setTab("regs")}
                className="card card-hover flex w-full items-center gap-3 p-4 text-left"
              >
                <span className="flex h-10 w-10 items-center justify-center rounded-lg bg-[#10B981]/15">
                  <Icon name="group" color="#10B981" />
                </span>
                <span className="flex-1">
                  <span className="block font-semibold">Participants</span>
                  <span className="block text-xs text-muted">
                    {registrations?.length ?? 0} registered · add or edit
                  </span>
                </span>
                <Icon name="chevron_right" color="#6B7280" />
              </button>
            </div>
          </div>
        )}

        {tab === "packages" && (
          <>
            <div className="mb-4 flex items-center gap-3">
              <div className="flex-1 text-sm text-muted">
                {packages.length} {packages.length === 1 ? "package" : "packages"}
              </div>
              <Button icon="add" disabled={busy} onClick={() => setPkgEditing(null)}>
                Add Package
              </Button>
            </div>
            {packages.length === 0 ? (
              <Empty
                icon="inventory_2"
                title="No packages added yet."
                action={
                  <Button icon="add" onClick={() => setPkgEditing(null)}>
                    Add Package
                  </Button>
                }
              />
            ) : (
              <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
                {packages.map((p) => (
                  <PackageCard
                    key={p.id}
                    event={event}
                    pkg={p}
                    stats={incStats}
                    busy={busy}
                    onEdit={() => setPkgEditing(p)}
                    onRemove={() => removePackage(String(p.id))}
                  />
                ))}
              </div>
            )}
          </>
        )}

        {tab === "regs" && (
          <div className="card overflow-hidden">
            <div className="flex flex-wrap items-center gap-3 border-b border-line px-5 py-4">
              <div className="flex-1 text-sm text-muted">
                {registrations
                  ? regsFiltered
                    ? `Participants (${filteredRegs.length} of ${registrations.length})`
                    : `Participants (${registrations.length})`
                  : ""}
              </div>
              <div className="w-full sm:w-72">
                <SearchBox value={search} onChange={setSearch} placeholder="Search participants…" />
              </div>
              <div className="flex w-full flex-wrap gap-2">
                <FilterSelect
                  label="packages"
                  value={pkgFilter}
                  onChange={setPkgFilter}
                  options={distinct((registrations ?? []).map((r) => r.packageName))}
                />
                <FilterSelect
                  label="participant types"
                  value={typeFilter}
                  onChange={setTypeFilter}
                  options={distinct((registrations ?? []).map((r) => r.participantType || "Delegate"))}
                />
                <FilterSelect
                  label="statuses"
                  value={statusFilter}
                  onChange={setStatusFilter}
                  options={distinct((registrations ?? []).map((r) => r.status ?? "registered")).map((s) => ({
                    value: s,
                    label: cap(s.replace("_", " ")),
                  }))}
                />
                <FilterSelect
                  label="claims"
                  value={claimFilter}
                  onChange={setClaimFilter}
                  options={[
                    { value: "claimed", label: "Claimed something" },
                    { value: "none", label: "Claimed nothing" },
                  ]}
                />
              </div>
              <ExportMenu
                title={`${event?.title || "Event"} - Participants`}
                rows={filteredRegs}
                columns={PARTICIPANT_EXPORT_COLUMNS}
                qr={PARTICIPANT_QR}
              />
              <Button variant="outline" icon="upload_file" disabled={busy} onClick={() => setImporting(true)}>
                Import Excel
              </Button>
              <Button icon="person_add" disabled={busy} onClick={() => setRegEditing(null)}>
                Add Participant
              </Button>
            </div>
            {!registrations ? (
              <Loading />
            ) : filteredRegs.length === 0 ? (
              <div className="p-5">
                <Empty
                  icon="group_off"
                  title={
                    registrations.length === 0
                      ? "No participants registered for this event yet."
                      : "No participants match your search."
                  }
                />
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>Participant</th>
                      <th>ID no.</th>
                      <th>Package</th>
                      <th>Contact</th>
                      <th>Claimed</th>
                      <th className="text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredRegs.map((r) => {
                      const regId = idOf(r);
                      const name = displayName(r) || "Participant";
                      const line = [r.designation, r.institution].filter(Boolean).join(" · ");
                      const claimed = (r.claimedInclusions ?? []).length;
                      const open = expanded.has(regId);
                      return (
                        <Fragment key={regId}>
                          <tr className="cursor-pointer" onClick={() => toggleExpanded(regId)}>
                            <td>
                              <div className="flex items-center gap-3">
                                <Avatar src={r.photoUrl} name={name} size={36} />
                                <div className="min-w-0">
                                  <div className="font-medium">{name}</div>
                                  {line && <div className="max-w-[280px] truncate text-xs text-muted">{line}</div>}
                                </div>
                              </div>
                            </td>
                            <td>
                              <span className="rounded-md bg-field px-2 py-1 font-mono text-xs font-bold">
                                {r.idNumber || "—"}
                              </span>
                            </td>
                            <td>
                              {r.packageName ? (
                                <Pill color="#60A5FA">{r.packageName}</Pill>
                              ) : (
                                <span className="text-muted">—</span>
                              )}
                            </td>
                            <td>
                              <div className="text-white/80">{r.mobileNumber}</div>
                              {r.email && <div className="max-w-[220px] truncate text-xs text-muted">{r.email}</div>}
                            </td>
                            <td onClick={(e) => e.stopPropagation()}>
                              {claimed > 0 ? (
                                <button
                                  onClick={() => setClaimsFor(r)}
                                  className="flex items-center gap-1 rounded-md border border-[#16A34A] px-2 py-1 text-xs font-semibold text-[#22C55E] hover:bg-[#16A34A]/10"
                                >
                                  <Icon name="verified" size={14} />
                                  {claimed} inclusion{claimed === 1 ? "" : "s"}
                                </button>
                              ) : (
                                <span className="text-xs text-muted">None</span>
                              )}
                            </td>
                            <td className="text-right" onClick={(e) => e.stopPropagation()}>
                              <span className="inline-flex items-center">
                                <IconButton
                                  icon="edit"
                                  outline
                                  title="Edit"
                                  size={19}
                                  onClick={() => setRegEditing(r)}
                                />
                                <IconButton icon="qr_code_2" title="QR" size={20} onClick={() => setBadgeFor(r)} />
                                <IconButton
                                  icon="delete"
                                  outline
                                  title="Delete"
                                  color="#EF4444"
                                  size={19}
                                  disabled={busy}
                                  onClick={() => deleteReg(r)}
                                />
                                <IconButton
                                  icon={open ? "expand_less" : "expand_more"}
                                  title="Details"
                                  color="#9CA3AF"
                                  onClick={() => toggleExpanded(regId)}
                                />
                              </span>
                            </td>
                          </tr>
                          {open && (
                            <tr className="bg-white/[0.02] hover:bg-white/[0.02]">
                              <td colSpan={6}>
                                <div className="grid gap-4 py-1 sm:grid-cols-3 lg:grid-cols-4">
                                  {info("Type", r.participantType || "Delegate")}
                                  {info("Package", r.packageName ?? "")}
                                  {info("Gender", cap(r.gender ?? ""))}
                                  {info("Mobile", r.mobileNumber ?? "")}
                                  {info("Email", r.email ?? "")}
                                  {info("ID no.", r.idNumber ?? "")}
                                  {info("Food", r.foodPreference ?? "")}
                                  {info("Payment", [r.paymentMode, r.utrNumber].filter(Boolean).join(" · "))}
                                  {info("Address", r.address ?? "")}
                                </div>
                              </td>
                            </tr>
                          )}
                        </Fragment>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )}

        {tab === "schedules" && (
          <ScheduleTable
            schedules={schedules}
            onAdd={() => navigate(`/admin/schedules/new?event=${id}`)}
            onDelete={(sId) => deleteSchedule(sId)}
            onEdit={(sId) => navigate(`/admin/schedules/new?event=${id}&schedule=${sId}`)}
          />
        )}
      </div>

      {pkgEditing !== undefined && (
        <PackageModal
          event={event}
          existing={pkgEditing}
          onClose={() => setPkgEditing(undefined)}
          onSave={(pkg) =>
            savePackages(
              pkgEditing ? packages.map((p) => (p.id === pkgEditing.id ? pkg : p)) : [...packages, pkg],
              pkgEditing ? "Package updated" : "Package added",
            )
          }
        />
      )}
      {regEditing !== undefined && (
        <ParticipantModal
          eventId={id}
          packages={packages}
          registration={regEditing}
          existingIdNumbers={existingIds(regEditing)}
          onClose={() => setRegEditing(undefined)}
          onSaved={(saved) => {
            const wasNew = !regEditing;
            setRegEditing(undefined);
            load();
            if (!wasNew) toast("Participant updated successfully", "success");
            else if (Object.keys(saved).length) setBadgeFor(saved);
          }}
        />
      )}
      {badgeFor && <BadgeModal registration={badgeFor} onClose={() => setBadgeFor(null)} />}
      {claimsFor && (
        <ClaimsModal eventId={id} registration={claimsFor} onClose={() => setClaimsFor(null)} onChanged={loadRegs} />
      )}
      {importing && (
        <ImportParticipantsModal
          eventId={id}
          packages={packages}
          registrations={registrations ?? []}
          onClose={() => setImporting(false)}
          onDone={load}
        />
      )}
    </Page>
  );
}
