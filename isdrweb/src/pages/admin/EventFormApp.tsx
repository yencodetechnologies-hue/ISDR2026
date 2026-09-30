import { useEffect, useRef, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { AppBar, Icon, Spinner } from "@/components/ui";
import { AppCtaButton, AppTextField } from "@/components/app/AppForm";
import { formData, get, post, put } from "@/lib/api";
import { parseDate } from "@/lib/format";

const DAY = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const MON = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
/** 'EEE, d MMM yyyy · h:mm a'. */
function fmt(d: Date) {
  const h = d.getHours();
  return `${DAY[d.getDay()]}, ${d.getDate()} ${MON[d.getMonth()]} ${d.getFullYear()} · ${h % 12 || 12}:${String(d.getMinutes()).padStart(2, "0")} ${h < 12 ? "AM" : "PM"}`;
}
/** Value for <input type="datetime-local">. */
function local(d: Date) {
  const two = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${two(d.getMonth() + 1)}-${two(d.getDate())}T${two(d.getHours())}:${two(d.getMinutes())}`;
}

/** Date tile from the app's form; the native date-time picker opens on tap. */
function DateTile({
  icon,
  label,
  value,
  onChange,
  onClear,
}: {
  icon: string;
  label: string;
  value: Date | null;
  onChange: (d: Date) => void;
  onClear?: () => void;
}) {
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
    <div
      onClick={open}
      className="relative flex cursor-pointer items-center gap-3 rounded-xl border border-line bg-bg px-3.5 py-3 active:bg-white/[0.03]"
    >
      <span className="flex rounded-[10px] bg-accent/[0.063] p-2">
        <Icon name={icon} size={20} color="#3B82F6" />
      </span>
      <div className="min-w-0 flex-1">
        <div className="text-xs font-medium text-muted">{label}</div>
        <div className="mt-0.5 font-sora text-sm font-semibold">{value ? fmt(value) : "Not set"}</div>
      </div>
      {onClear && value ? (
        <button
          onClick={(e) => {
            e.stopPropagation();
            onClear();
          }}
          className="relative z-10 p-1"
        >
          <Icon name="close" size={18} color="#94A3B8" />
        </button>
      ) : (
        !onClear && <Icon name="arrow_forward_ios" size={14} color="#94A3B8" />
      )}
      <input
        ref={ref}
        type="datetime-local"
        tabIndex={-1}
        value={value ? local(value) : ""}
        onChange={(e) => {
          const d = e.target.value ? new Date(e.target.value) : null;
          if (d && !isNaN(d.getTime())) onChange(d);
        }}
        className="pointer-events-none absolute bottom-0 left-4 h-0 w-0 opacity-0"
      />
    </div>
  );
}

/** Create event / Edit event at phone width — the app's Create/EditManagedEventPage (admin: with end date). */
export default function EventFormApp() {
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const eventId = params.get("id");
  const editing = !!eventId;
  const [title, setTitle] = useState("");
  const [venue, setVenue] = useState("");
  const [description, setDescription] = useState("");
  const [eventDate, setEventDate] = useState<Date>(() => new Date(Date.now() + 86400000));
  const [eventEndDate, setEventEndDate] = useState<Date | null>(null);
  const [existingPhoto, setExistingPhoto] = useState<string | null>(null);
  const [photo, setPhoto] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [removePhoto, setRemovePhoto] = useState(false);
  const [sheet, setSheet] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(editing);
  const gallery = useRef<HTMLInputElement>(null);
  const camera = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!eventId) return;
    get(`/managed-events/${eventId}`).then((r) => {
      setLoading(false);
      if (!r.success || !r.event) return setError(r.error || "Could not load the event");
      const e = r.event;
      setTitle(e.title ?? "");
      setVenue(e.venue ?? "");
      setDescription(e.description ?? "");
      const d = parseDate(e.eventDate);
      if (d) setEventDate(d);
      setEventEndDate(parseDate(e.eventEndDate) ?? null);
      setExistingPhoto(e.photoUrl ? String(e.photoUrl) : null);
    });
  }, [eventId]);
  useEffect(
    () => () => {
      if (preview) URL.revokeObjectURL(preview);
    },
    [preview],
  );

  const pick = (f?: File) => {
    if (!f) return;
    setPhoto(f);
    setPreview(URL.createObjectURL(f));
    setRemovePhoto(false);
  };
  const shownPhoto = preview ?? (existingPhoto && !removePhoto ? existingPhoto : null);

  const save = async () => {
    if (!title.trim()) return setError("Title is required");
    if (eventEndDate && eventEndDate < eventDate) return setError("End date must be after the start date");
    setBusy(true);
    setError(null);
    const fields: Record<string, string> = {
      title: title.trim(),
      description: description.trim(),
      venue: venue.trim(),
      eventDate: eventDate.toISOString(),
    };
    if (eventEndDate) fields.eventEndDate = eventEndDate.toISOString();
    else if (editing) fields.eventEndDate = "";
    if (editing && removePhoto && !photo) fields.clearPhoto = "true";
    const fd = formData(fields, { photo });
    const r = editing ? await put(`/managed-events/${eventId}`, fd) : await post("/managed-events", fd);
    setBusy(false);
    if (!r.success) return setError(r.error || (editing ? "Update failed" : "Create failed"));
    navigate(-1);
  };

  const form = (
    <div className="space-y-3 rounded-[18px] border border-line bg-card p-4 shadow-[0_3px_10px_rgba(0,0,0,0.02)]">
      {shownPhoto ? (
        <div className="relative !mb-4 h-40 overflow-hidden rounded-[14px] border border-white/10">
          <img src={shownPhoto} alt="" className="h-full w-full object-cover" />
          <div className="absolute inset-0 bg-gradient-to-b from-black/[0.27] via-transparent to-black/[0.47]" />
          <span className="absolute left-3 top-2.5 inline-flex items-center gap-1 rounded-md bg-black/55 px-2 py-1 text-[11px] font-semibold">
            <Icon name="image" size={14} />
            Event Photo
          </span>
          <div className="absolute bottom-2.5 right-3 flex gap-2">
            <button
              onClick={() => setSheet(true)}
              className="inline-flex items-center gap-1 rounded-lg bg-card px-2.5 py-1.5 text-xs font-semibold text-accent shadow-[0_2px_4px_rgba(0,0,0,0.26)]"
            >
              <Icon name="edit" size={14} color="#3B82F6" />
              Change
            </button>
            <button
              onClick={() => {
                setPhoto(null);
                setPreview(null);
                setRemovePhoto(true);
              }}
              className="inline-flex items-center gap-1 rounded-lg bg-[#EF4444] px-2 py-1.5 text-xs font-semibold shadow-[0_2px_4px_rgba(0,0,0,0.26)]"
            >
              <Icon name="delete" outline size={14} />
              Remove
            </button>
          </div>
        </div>
      ) : (
        <button
          onClick={() => setSheet(true)}
          className="!mb-4 flex w-full items-center gap-3.5 rounded-[14px] border border-white/20 bg-bg p-4 text-left active:bg-white/[0.03]"
        >
          <span className="flex h-11 w-11 items-center justify-center rounded-[10px] bg-accent/[0.055]">
            <Icon name="add_photo_alternate" outline size={24} color="#3B82F6" />
          </span>
          <span className="min-w-0 flex-1">
            <span className="block text-[13px] font-semibold text-[#E2E8F0]">Add event photo (optional)</span>
            <span className="mt-0.5 block text-xs text-muted">Tap to upload cover / banner image</span>
          </span>
          <Icon name="arrow_forward_ios" size={14} color="#94A3B8" />
        </button>
      )}
      <AppTextField label="Title *" icon="title" value={title} onChange={setTitle} />
      <AppTextField label="Venue" icon="location_on" value={venue} onChange={setVenue} />
      <DateTile icon="calendar_month" label="Date & time" value={eventDate} onChange={setEventDate} />
      <DateTile
        icon="event_available"
        label="End date & time (optional)"
        value={eventEndDate}
        onChange={setEventEndDate}
        onClear={() => setEventEndDate(null)}
      />
      <AppTextField label="Description" icon="description" multiline value={description} onChange={setDescription} />
    </div>
  );

  return (
    <div className="min-h-screen bg-bg">
      {editing ? (
        <AppBar title="Edit event" titleClassName="!text-left text-[22px]" />
      ) : (
        <AppBar title="Create event" bg="#3B82F6" titleClassName="font-sora text-xl font-bold" />
      )}
      {loading ? (
        <div className="flex justify-center pt-40">
          <Spinner size={36} />
        </div>
      ) : (
        <div className="p-4">
          {!editing && (
            <div className="mb-4 flex items-center gap-3 rounded-[14px] border border-line bg-card p-3.5">
              <span className="flex rounded-[10px] bg-accent/[0.063] p-2">
                <Icon name="info" outline size={20} color="#3B82F6" />
              </span>
              <span className="flex-1 text-xs leading-[1.4] text-muted">
                Fill in the event details below. A public register link is generated for sharing where applicable.
              </span>
            </div>
          )}
          {error &&
            (editing ? (
              <div className="mb-3 text-[#EF4444]">{error}</div>
            ) : (
              <div className="mb-3.5 rounded-[10px] border border-[#EF4444]/20 bg-[#EF4444]/[0.06] p-3 text-[13px] font-semibold text-[#EF4444]">
                {error}
              </div>
            ))}
          {form}
          {editing ? (
            <button
              onClick={busy ? undefined : save}
              className="mt-5 flex w-full items-center justify-center rounded-full bg-accent py-3.5 text-sm font-medium shadow-[0_1px_3px_rgba(0,0,0,0.3)]"
            >
              {busy ? <Spinner size={22} color="#fff" /> : "Save changes"}
            </button>
          ) : (
            <div className="mb-6 mt-6">
              <AppCtaButton label="Create event" icon="check_circle" loading={busy} onClick={save} />
            </div>
          )}
        </div>
      )}
      <input ref={gallery} type="file" accept="image/*" hidden onChange={(e) => (pick(e.target.files?.[0]), (e.target.value = ""))} />
      <input
        ref={camera}
        type="file"
        accept="image/*"
        capture="environment"
        hidden
        onChange={(e) => (pick(e.target.files?.[0]), (e.target.value = ""))}
      />
      {sheet && (
        <div className="animate-fade fixed inset-0 z-[90] flex items-end" onClick={() => setSheet(false)}>
          <div className="absolute inset-0 bg-black/55" />
          <div className="animate-sheet relative w-full rounded-t-[20px] bg-card py-4" onClick={(e) => e.stopPropagation()}>
            <div className="mx-auto mb-4 h-1 w-10 rounded-sm bg-white/20" />
            <div className="text-center font-sora text-base font-bold">Select Event Photo</div>
            <div className="mt-3.5">
              {[
                ["photo_library", "#3B82F6", "Choose from Gallery", "Select an image from device gallery", gallery],
                ["photo_camera", "#10B981", "Take Photo", "Use camera to take a new photo", camera],
              ].map(([icon, color, t, sub, ref]) => (
                <button
                  key={t as string}
                  onClick={() => {
                    setSheet(false);
                    (ref as React.RefObject<HTMLInputElement>).current?.click();
                  }}
                  className="flex w-full items-center gap-4 px-4 py-2 text-left active:bg-white/5"
                >
                  <span className="rounded-lg p-2" style={{ background: `${color}14` }}>
                    <Icon name={icon as string} color={color as string} />
                  </span>
                  <span>
                    <span className="block text-sm font-semibold">{t as string}</span>
                    <span className="block text-xs text-muted">{sub as string}</span>
                  </span>
                </button>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
