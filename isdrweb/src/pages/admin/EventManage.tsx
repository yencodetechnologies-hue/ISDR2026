/* eslint-disable @typescript-eslint/no-explicit-any, react-refresh/only-export-components */
import { useEffect, useRef, useState } from "react";
import DelegateBadge, {
  DEFAULT_TYPE_COLOR,
  downloadBadgePng,
  normalizeHex,
  type BadgeData,
} from "@/components/DelegateBadge";
import {
  Avatar,
  Button,
  Field,
  Icon,
  IconButton,
  Input,
  Modal,
  Select,
  Spinner,
  Switch,
  TextArea,
  useToast,
} from "@/components/ui";
import { formData, post, put } from "@/lib/api";
import { fmtDMon, fmtShortDateTime, idOf, isoDay, parseDate, startOfDay } from "@/lib/format";

/* ------------------------------------------------------------------ */
/* Helpers (same rules as the app's event_package_sheet.dart)          */
/* ------------------------------------------------------------------ */

export type EventDay = { iso: string; label: string };

/** Calendar days between the event's start and end date. */
export function eventDays(event: any): EventDay[] {
  const start = parseDate(event?.eventDate);
  if (!start) return [];
  const end = parseDate(event?.eventEndDate) ?? start;
  const days: EventDay[] = [];
  let cursor = startOfDay(start);
  const last = startOfDay(end);
  for (let guard = 0; cursor <= last && guard < 60; guard++) {
    days.push({ iso: isoDay(cursor), label: fmtDMon(cursor) });
    cursor = new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate() + 1);
  }
  return days;
}

/** Inclusions as `{name, dates}` (legacy plain strings are upgraded). */
export function normalizeInclusions(raw: any): { name: string; dates: string[] }[] {
  const out: { name: string; dates: string[] }[] = [];
  for (const i of Array.isArray(raw) ? raw : []) {
    if (i && typeof i === "object") {
      const name = String(i.name ?? "").trim();
      if (name) out.push({ name, dates: (Array.isArray(i.dates) ? i.dates : []).map(String) });
    } else {
      const name = String(i ?? "").trim();
      if (name) out.push({ name, dates: [] });
    }
  }
  return out;
}

export const paymentModeLabel = (m: string) => (m === "upi" ? "UPI" : m ? m[0].toUpperCase() + m.slice(1) : "");
export const rateOf = (p: any) => Number(p?.rate) || 0;

/** "Dr Jane A Doe", falling back to the stored name. */
export const displayName = (r: any) =>
  [r?.title, r?.firstName, r?.middleName, r?.lastName]
    .map((s) => String(s ?? "").trim())
    .filter(Boolean)
    .join(" ") || String(r?.name ?? "");

/** Green tick box used in the day pickers. */
function DayTick({ on, label, onClick }: { on: boolean; label: string; onClick?: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={!onClick}
      className="flex h-9 items-center gap-2 rounded-lg border px-2.5 text-left text-[12.5px] font-bold transition disabled:cursor-default"
      style={{
        borderColor: on ? "#22C55E" : "rgba(255,255,255,0.12)",
        background: on ? "rgba(34,197,94,0.15)" : "#0A0A12",
        color: on ? "#86EFAC" : "#E2E8F0",
      }}
    >
      <span
        className="flex h-4 w-4 shrink-0 items-center justify-center rounded"
        style={{ background: on ? "#22C55E" : "transparent", border: on ? "none" : "1.5px solid #6B7280" }}
      >
        {on && <Icon name="check" size={13} color="#fff" />}
      </span>
      <span className="truncate">{label}</span>
    </button>
  );
}

/* ------------------------------------------------------------------ */
/* Add / edit package                                                  */
/* ------------------------------------------------------------------ */

export function PackageModal({
  event,
  existing,
  onClose,
  onSave,
}: {
  event: any;
  existing: any | null;
  onClose: () => void;
  onSave: (pkg: any) => Promise<boolean>;
}) {
  const days = eventDays(event);
  const allIso = days.map((d) => d.iso);
  const editing = !!existing;
  const [name, setName] = useState<string>(existing?.name ?? "");
  const [isFree, setIsFree] = useState(existing ? rateOf(existing) === 0 : false);
  const [rate, setRate] = useState(existing && rateOf(existing) !== 0 ? String(rateOf(existing)) : "");
  const [entryExit, setEntryExit] = useState<string[]>(() => {
    const saved: string[] = (existing?.entryExitDates ?? []).map(String);
    return saved.length ? saved : allIso;
  });
  const [inclusions, setInclusions] = useState(() => normalizeInclusions(existing?.inclusions));
  const [newInc, setNewInc] = useState("");
  const [renaming, setRenaming] = useState<{ index: number; value: string } | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const addInclusion = () => {
    const v = newInc.trim();
    if (!v) return;
    if (!inclusions.some((i) => i.name.toLowerCase() === v.toLowerCase()))
      setInclusions((l) => [...l, { name: v, dates: [] }]);
    setNewInc("");
  };

  const toggleIncDay = (index: number, iso: string) =>
    setInclusions((l) =>
      l.map((inc, k) =>
        k !== index
          ? inc
          : { ...inc, dates: inc.dates.includes(iso) ? inc.dates.filter((d) => d !== iso) : [...inc.dates, iso] },
      ),
    );

  const toggleEntryDay = (iso: string) =>
    setEntryExit((l) => (l.includes(iso) ? l.filter((d) => d !== iso) : [...l, iso]));

  const submit = async () => {
    const n = name.trim();
    if (!n) return setError("Package name is required");
    let r = 0;
    if (!isFree) {
      if (!rate.trim()) return setError("Enter a rate or turn on Free");
      const parsed = Number(rate.trim());
      if (!Number.isFinite(parsed) || parsed < 0) return setError("Enter a valid rate");
      r = parsed;
    }
    if (days.length && !entryExit.length) return setError("Please select at least one day for Entry & Exit");
    setError(null);
    setSaving(true);
    const ok = await onSave({
      ...(existing?.id ? { id: existing.id } : {}),
      name: n,
      rate: r,
      paymentMode: "",
      entryExitDates: entryExit,
      inclusions,
    });
    setSaving(false);
    if (ok) onClose();
  };

  const entryInvalid = days.length > 0 && entryExit.length === 0;

  return (
    <Modal
      open
      onClose={onClose}
      title={editing ? "Edit Package" : "Add Package"}
      width={720}
      footer={
        <>
          <Button variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button icon="check" loading={saving} onClick={submit}>
            {editing ? "Save Package" : "Add Package"}
          </Button>
        </>
      }
    >
      {error && (
        <div className="mb-4 flex items-center gap-2 rounded-lg border border-red-500/30 bg-red-500/15 px-3 py-2.5 text-sm font-semibold text-[#F87171]">
          <Icon name="error" size={18} outline />
          {error}
        </div>
      )}

      <div className="eyebrow mb-3 flex items-center gap-1.5">
        <Icon name="inventory_2" size={16} color="#3B82F6" outline />
        Details
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="Package name *">
          <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. UG package" />
        </Field>
        <Field label={isFree ? "Rate" : "Rate (₹) *"}>
          <Input
            type="number"
            min={0}
            value={rate}
            disabled={isFree}
            onChange={(e) => setRate(e.target.value)}
            placeholder={isFree ? "Free" : "e.g. 5000"}
          />
        </Field>
      </div>
      <div
        className="mt-3 flex items-center gap-3 rounded-lg border px-4 py-2.5"
        style={{
          borderColor: isFree ? "#BBF7D0" : "rgba(255,255,255,0.1)",
          background: isFree ? "rgba(34,197,94,0.15)" : "transparent",
        }}
      >
        <Icon name="card_giftcard" size={20} color={isFree ? "#22C55E" : "#94A3B8"} />
        <span className="flex-1 text-sm font-semibold">Free package</span>
        <Switch
          checked={isFree}
          color="#22C55E"
          onChange={(v) => {
            setIsFree(v);
            if (v) setRate("");
          }}
        />
      </div>

      <div className="eyebrow mb-3 mt-6 flex items-center gap-1.5">
        <Icon name="login" size={16} color="#3B82F6" />
        Entry &amp; Exit Access *
      </div>
      <div
        className="rounded-xl border p-4"
        style={{ borderColor: entryInvalid ? "rgba(239,68,68,0.4)" : "rgba(255,255,255,0.1)" }}
      >
        <div className="flex items-center gap-3">
          <div className="flex-1">
            <div className="text-sm font-semibold">Authorized Entry &amp; Exit Days</div>
            <div className={`text-xs ${entryInvalid ? "font-semibold text-[#FCA5A5]" : "text-muted"}`}>
              {days.length
                ? `${entryExit.length} of ${days.length} days selected (mandatory)`
                : "No event dates configured"}
            </div>
          </div>
          {days.length > 0 && (
            <button
              type="button"
              onClick={() => setEntryExit(entryExit.length === days.length ? [] : allIso)}
              className="text-xs font-bold text-[#60A5FA] hover:underline"
            >
              {entryExit.length === days.length ? "Deselect All" : "Select All"}
            </button>
          )}
        </div>
        {days.length > 0 && (
          <div className="mt-3 grid grid-cols-3 gap-2 sm:grid-cols-5">
            {days.map((d) => (
              <DayTick
                key={d.iso}
                on={entryExit.includes(d.iso)}
                label={d.label}
                onClick={() => toggleEntryDay(d.iso)}
              />
            ))}
          </div>
        )}
      </div>

      <div className="eyebrow mb-3 mt-6 flex items-center gap-1.5">
        <Icon name="checklist" size={16} color="#3B82F6" />
        Inclusions
      </div>
      <div className="flex gap-2">
        <Input
          value={newInc}
          onChange={(e) => setNewInc(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") {
              e.preventDefault();
              addInclusion();
            }
          }}
          placeholder="Add inclusion, e.g. Lunch"
        />
        <Button icon="add" onClick={addInclusion}>
          Add
        </Button>
      </div>
      <div className="mt-3 space-y-3">
        {inclusions.length === 0 ? (
          <div className="rounded-lg border border-line p-4 text-sm text-[#94A3B8]">
            No inclusions yet. Add one above, then tick the days it applies to.
          </div>
        ) : (
          inclusions.map((inc, i) => (
            <div key={`${inc.name}-${i}`} className="rounded-xl border border-line bg-card p-3.5">
              <div className="flex items-center gap-3">
                <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-accent/15">
                  <Icon name="restaurant" size={17} color="#2563EB" />
                </span>
                <div className="min-w-0 flex-1">
                  {renaming?.index === i ? (
                    <div className="flex gap-2">
                      <Input
                        autoFocus
                        value={renaming.value}
                        onChange={(e) => setRenaming({ index: i, value: e.target.value })}
                        onKeyDown={(e) => {
                          if (e.key === "Enter" && renaming.value.trim()) {
                            setInclusions((l) =>
                              l.map((x, k) => (k === i ? { ...x, name: renaming.value.trim() } : x)),
                            );
                            setRenaming(null);
                          }
                          if (e.key === "Escape") setRenaming(null);
                        }}
                      />
                      <Button
                        small
                        onClick={() => {
                          if (!renaming.value.trim()) return;
                          setInclusions((l) => l.map((x, k) => (k === i ? { ...x, name: renaming.value.trim() } : x)));
                          setRenaming(null);
                        }}
                      >
                        Save
                      </Button>
                    </div>
                  ) : (
                    <>
                      <div className="truncate font-semibold">{inc.name}</div>
                      {days.length > 0 && (
                        <div className="text-xs text-muted">
                          {days.filter((d) => inc.dates.includes(d.iso)).length} of {days.length} days
                        </div>
                      )}
                    </>
                  )}
                </div>
                {renaming?.index !== i && (
                  <IconButton
                    icon="edit"
                    outline
                    title="Edit name"
                    color="#60A5FA"
                    size={19}
                    onClick={() => setRenaming({ index: i, value: inc.name })}
                  />
                )}
                <IconButton
                  icon="delete"
                  outline
                  title="Delete"
                  color="#EF4444"
                  size={19}
                  onClick={() => setInclusions((l) => l.filter((_, k) => k !== i))}
                />
              </div>
              {days.length === 0 ? (
                <div className="mt-2 text-xs text-muted">Set the event dates to pick days.</div>
              ) : (
                <div className="mt-3 grid grid-cols-3 gap-2 sm:grid-cols-5">
                  {days.map((d) => (
                    <DayTick
                      key={d.iso}
                      on={inc.dates.includes(d.iso)}
                      label={d.label}
                      onClick={() => toggleIncDay(i, d.iso)}
                    />
                  ))}
                </div>
              )}
            </div>
          ))
        )}
      </div>
    </Modal>
  );
}

/* ------------------------------------------------------------------ */
/* Package card (event page)                                           */
/* ------------------------------------------------------------------ */

function StatPill({ text, color }: { text: string; color: string }) {
  return (
    <span className="rounded-full px-2 py-0.5 text-[11px] font-bold" style={{ background: `${color}1a`, color }}>
      {text}
    </span>
  );
}

export function PackageCard({
  event,
  pkg,
  stats,
  busy,
  onEdit,
  onRemove,
}: {
  event: any;
  pkg: any;
  stats: Record<string, any>;
  busy: boolean;
  onEdit: () => void;
  onRemove: () => void;
}) {
  const days = eventDays(event);
  const inclusions = normalizeInclusions(pkg.inclusions);
  const rate = rateOf(pkg);
  const mode = String(pkg.paymentMode ?? "");
  const ee: string[] = (pkg.entryExitDates ?? []).map(String);
  const eeCount = ee.length ? ee.length : days.length;
  return (
    <div className="card flex flex-col p-5">
      <div className="flex items-start gap-3">
        <div className="min-w-0 flex-1 text-[15px] font-semibold">{pkg.name}</div>
        <span
          className="rounded-md px-2.5 py-1 text-xs font-extrabold"
          style={
            rate === 0
              ? { background: "rgba(34,197,94,0.15)", color: "#86EFAC" }
              : { background: "rgba(59,130,246,0.15)", color: "#60A5FA" }
          }
        >
          {rate === 0 ? "Free" : `₹${rate}${mode ? ` · ${paymentModeLabel(mode)}` : ""}`}
        </span>
      </div>
      <div className="mt-3 inline-flex w-fit items-center gap-1.5 rounded-lg border border-[#22C55E]/30 bg-[#22C55E]/10 px-2.5 py-1 text-xs font-bold text-[#86EFAC]">
        <Icon name="login" size={14} color="#22C55E" />
        Entry &amp; Exit: {eeCount} of {days.length} {days.length === 1 ? "day" : "days"} authorized
      </div>
      <div className="mt-4 flex-1 space-y-3">
        {inclusions.length === 0 ? (
          <div className="text-[13px] text-muted">No inclusions added.</div>
        ) : (
          inclusions.map((inc) => {
            const st = stats[`${pkg.name}|${inc.name}`] ?? {};
            return (
              <div key={inc.name} className="border-t border-line pt-3 first:border-t-0 first:pt-0">
                <div className="text-sm font-semibold">{inc.name}</div>
                <div className="mt-1.5 flex flex-wrap gap-1.5">
                  <StatPill text={`${st.scanned ?? 0} Scanned`} color="#16A34A" />
                  <StatPill text={`${st.notScanned ?? 0} Not scanned`} color="#D97706" />
                  <StatPill text={`${st.rejected ?? 0} Rejected`} color="#DC2626" />
                </div>
                {days.length > 0 && (
                  <div className="mt-2 flex flex-wrap gap-x-3 gap-y-1.5">
                    {days.map((d) => {
                      const on = inc.dates.includes(d.iso);
                      return (
                        <span key={d.iso} className="flex items-center gap-1 text-xs">
                          <span
                            className="flex h-3.5 w-3.5 items-center justify-center rounded-sm"
                            style={{
                              background: on ? "#22C55E" : "transparent",
                              border: on ? "none" : "1.5px solid #6B7280",
                            }}
                          >
                            {on && <Icon name="check" size={11} color="#fff" />}
                          </span>
                          {d.label}
                        </span>
                      );
                    })}
                  </div>
                )}
              </div>
            );
          })
        )}
      </div>
      <div className="mt-4 flex gap-2 border-t border-line pt-4">
        <Button small variant="outline" icon="edit" disabled={busy} onClick={onEdit}>
          Edit
        </Button>
        <Button small variant="outline" icon="delete" disabled={busy} className="!text-[#F87171]" onClick={onRemove}>
          Remove
        </Button>
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Create / edit participant (same fields as event_participant_sheet)  */
/* ------------------------------------------------------------------ */

const TITLES = ["Dr", "Mr", "Ms", "Prof"];

export function ParticipantModal({
  eventId,
  packages,
  registration,
  existingIdNumbers,
  onClose,
  onSaved,
}: {
  eventId: string;
  packages: any[];
  registration: any | null;
  existingIdNumbers: Set<string>;
  onClose: () => void;
  onSaved: (reg: any) => void;
}) {
  const r = registration;
  const editing = !!r;
  const s = (k: string) => String(r?.[k] ?? "");
  const initialPackage = () => {
    const pid = s("packageId");
    if (pid && packages.some((p) => String(p.id) === pid)) return pid;
    const byName = packages.find((p) => String(p.name) === s("packageName"));
    return byName ? String(byName.id) : "";
  };

  const [type, setType] = useState(s("participantType"));
  const [typeColor, setTypeColor] = useState(s("participantTypeColor") || DEFAULT_TYPE_COLOR);
  const [title, setTitle] = useState(s("title"));
  const [first, setFirst] = useState(() => (!s("firstName") && !s("lastName") ? s("name") : s("firstName")));
  const [middle, setMiddle] = useState(s("middleName"));
  const [last, setLast] = useState(s("lastName"));
  const [gender, setGender] = useState(s("gender"));
  const [designation, setDesignation] = useState(s("designation"));
  const [institution, setInstitution] = useState(s("institution"));
  const [idNumber, setIdNumber] = useState(s("idNumber"));
  const [address, setAddress] = useState(s("address"));
  const [mobile, setMobile] = useState(s("mobileNumber"));
  const [email, setEmail] = useState(s("email"));
  const [food, setFood] = useState(s("foodPreference"));
  const [paymentMode, setPaymentMode] = useState(s("paymentMode"));
  const [utr, setUtr] = useState(s("utrNumber"));
  const [packageId, setPackageId] = useState(initialPackage);
  const [photo, setPhoto] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!photo) return setPreview(null);
    const u = URL.createObjectURL(photo);
    setPreview(u);
    return () => URL.revokeObjectURL(u);
  }, [photo]);

  const pkg = packages.find((p) => String(p.id) === packageId) ?? null;
  const free = !!pkg && rateOf(pkg) === 0;
  const paid = !!pkg && !free;
  const idTaken =
    !!idNumber.trim() && [...existingIdNumbers].some((e) => e.toLowerCase() === idNumber.trim().toLowerCase());

  const validate = () => {
    const checks: [string, string][] = [
      ["Participant type", type],
      ["Title", title],
      ["First name", first],
      ["Gender", gender],
      ["Package", packageId],
      ...(editing ? ([["ID no.", idNumber]] as [string, string][]) : []),
      ["Mobile number", mobile],
      ["Email", email],
      ["Food preference", food],
    ];
    for (const [label, value] of checks) if (!value.trim()) return `${label} is required`;
    if (typeColor.trim() && !normalizeHex(typeColor)) return "Enter a valid hex colour, e.g. #167E5D";
    if (paid && !paymentMode) return "Payment mode is required";
    if (!/^\+?\d{10,13}$/.test(mobile.replace(/[\s-]/g, ""))) return "Enter a valid mobile number";
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) return "Enter a valid email address";
    if (idTaken) return "This ID number is already used for this event.";
    return null;
  };

  const submit = async () => {
    const err = validate();
    if (err) return setError(err);
    setError(null);
    setBusy(true);
    const fd = formData(
      {
        participantType: type.trim(),
        participantTypeColor: normalizeHex(typeColor) ?? DEFAULT_TYPE_COLOR,
        title,
        firstName: first.trim(),
        middleName: middle.trim(),
        lastName: last.trim(),
        gender,
        designation: designation.trim(),
        institution: institution.trim(),
        packageId,
        idNumber: idNumber.trim(),
        address: address.trim(),
        mobileNumber: mobile.trim(),
        email: email.trim(),
        foodPreference: food,
        paymentMode: free ? "" : paymentMode,
        utrNumber: utr.trim(),
      },
      { photo },
    );
    const res = editing
      ? await put(`/managed-events/${eventId}/registrations/${idOf(r)}`, fd)
      : await post(`/managed-events/${eventId}/registrations/spot`, fd);
    setBusy(false);
    if (!res.success) return setError(res.error || "Failed to save participant");
    onSaved(res.registration && typeof res.registration === "object" ? res.registration : {});
  };

  const titleOptions = [...TITLES, ...(title && !TITLES.includes(title) ? [title] : [])].map((t) => ({
    value: t,
    label: t,
  }));
  const photoShown = preview ?? (s("photoUrl") || null);

  return (
    <Modal
      open
      onClose={onClose}
      title={editing ? "Edit participant" : "Create participants"}
      width={760}
      footer={
        <>
          <Button variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button icon={editing ? "check" : "qr_code_2"} loading={busy} disabled={idTaken} onClick={submit}>
            {editing ? "Save changes" : "Create participant & QR"}
          </Button>
        </>
      }
    >
      {error && (
        <div className="mb-4 flex items-center gap-2 rounded-lg border border-red-500/30 bg-red-500/15 px-3 py-2.5 text-sm font-semibold text-[#F87171]">
          <Icon name="error" size={18} outline />
          {error}
        </div>
      )}
      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="Participant type *">
          <Input
            value={type}
            maxLength={60}
            onChange={(e) => setType(e.target.value)}
            placeholder="e.g. Delegate, Speaker, Organizer"
          />
        </Field>
        <Field label="Banner colour (hex)">
          <div className="flex items-center gap-2">
            <span
              className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg border border-line"
              style={{ background: typeColor.trim() ? (normalizeHex(typeColor) ?? "transparent") : DEFAULT_TYPE_COLOR }}
              title={typeColor.trim() && !normalizeHex(typeColor) ? "Invalid hex colour" : ""}
            >
              {typeColor.trim() && !normalizeHex(typeColor) && <Icon name="close" size={18} color="#F87171" />}
            </span>
            <Input
              value={typeColor}
              maxLength={7}
              onChange={(e) => setTypeColor(e.target.value.toUpperCase())}
              placeholder={DEFAULT_TYPE_COLOR}
              className="font-mono"
            />
          </div>
        </Field>
        <Field label="Package *">
          <Select
            value={packageId}
            placeholder="Select a package"
            onChange={(v) => {
              setPackageId(v);
              const p = packages.find((x) => String(x.id) === v);
              if (p && rateOf(p) === 0) setPaymentMode("");
            }}
            options={packages.map((p) => ({
              value: String(p.id),
              label: `${p.name} (${rateOf(p) === 0 ? "Free" : `₹${p.rate}`})`,
            }))}
          />
        </Field>
      </div>

      <div className="mt-4 grid gap-4 sm:grid-cols-[120px_1fr_1fr_1fr]">
        <Field label="Title *">
          <Select value={title} placeholder="Title" onChange={setTitle} options={titleOptions} />
        </Field>
        <Field label="First name *">
          <Input value={first} onChange={(e) => setFirst(e.target.value)} />
        </Field>
        <Field label="Middle name">
          <Input value={middle} onChange={(e) => setMiddle(e.target.value)} placeholder="Optional" />
        </Field>
        <Field label="Last name">
          <Input value={last} onChange={(e) => setLast(e.target.value)} placeholder="Optional" />
        </Field>
      </div>

      <div className="mt-4 grid gap-4 sm:grid-cols-3">
        <Field label="Gender *">
          <Select
            value={gender}
            placeholder="Select"
            onChange={setGender}
            options={[
              { value: "male", label: "Male" },
              { value: "female", label: "Female" },
              { value: "other", label: "Other" },
            ]}
          />
        </Field>
        <Field label="Designation">
          <Input value={designation} onChange={(e) => setDesignation(e.target.value)} />
        </Field>
        <Field label="Organization">
          <Input value={institution} onChange={(e) => setInstitution(e.target.value)} placeholder="Optional" />
        </Field>
      </div>

      <div className="mt-4 grid gap-4 sm:grid-cols-3">
        <Field
          label={editing ? "ID no. *" : "ID no."}
          error={idTaken ? "This ID number is already used for this event." : null}
          hint={editing ? undefined : "Leave blank to create automatically"}
        >
          <Input
            value={idNumber}
            onChange={(e) => setIdNumber(e.target.value.toUpperCase())}
            placeholder={editing ? "e.g. UG0001" : "Leave blank to create"}
            className="font-mono"
          />
        </Field>
        <Field label="Mobile no. *">
          <Input type="tel" value={mobile} onChange={(e) => setMobile(e.target.value)} />
        </Field>
        <Field label="Email *">
          <Input type="email" value={email} onChange={(e) => setEmail(e.target.value)} />
        </Field>
      </div>

      <div className="mt-4 grid gap-4 sm:grid-cols-3">
        <Field label="Food preference *">
          <Select
            value={food}
            placeholder="Select"
            onChange={setFood}
            options={[
              { value: "veg", label: "Veg" },
              { value: "non-veg", label: "Non-veg" },
            ]}
          />
        </Field>
        <Field label={paid ? "Payment mode *" : "Payment mode"}>
          <Select
            value={free ? "" : paymentMode}
            placeholder={free ? "Not needed (free)" : "Select"}
            disabled={free}
            onChange={setPaymentMode}
            options={[
              { value: "cash", label: "Cash" },
              { value: "card", label: "Card" },
              { value: "upi", label: "UPI" },
            ]}
          />
        </Field>
        <Field label="UTR no.">
          <Input value={utr} onChange={(e) => setUtr(e.target.value)} placeholder="Optional" />
        </Field>
      </div>

      <div className="mt-4">
        <Field label="Address">
          <TextArea rows={2} value={address} onChange={(e) => setAddress(e.target.value)} placeholder="Optional" />
        </Field>
      </div>

      <div className="mt-4 flex items-center gap-3">
        <Avatar src={photoShown} name={first || "?"} size={56} />
        <Button variant="outline" small icon="photo_camera" onClick={() => fileRef.current?.click()}>
          Photo (optional)
        </Button>
        <input
          ref={fileRef}
          type="file"
          accept="image/*"
          hidden
          onChange={(e) => {
            const f = e.target.files?.[0];
            if (f) setPhoto(f);
            e.target.value = "";
          }}
        />
      </div>
    </Modal>
  );
}

/* ------------------------------------------------------------------ */
/* Participant badge (QR) with download                                */
/* ------------------------------------------------------------------ */

export function BadgeModal({ registration, onClose }: { registration: any; onClose: () => void }) {
  const toast = useToast();
  const box = useRef<HTMLDivElement>(null);
  const [busy, setBusy] = useState(false);
  const data: BadgeData = {
    name: registration.name,
    title: registration.title,
    participantType: registration.participantType,
    participantTypeColor: registration.participantTypeColor,
    idNumber: registration.idNumber,
    designation: registration.designation,
    institution: registration.institution,
    qrCode: registration.qrCode,
  };
  const download = async () => {
    setBusy(true);
    try {
      const ok = await downloadBadgePng(box.current, data);
      if (!ok) toast("Could not create the badge image", "error");
    } catch (e) {
      toast(`Error saving QR code: ${e}`, "error");
    }
    setBusy(false);
  };
  return (
    <Modal open onClose={onClose} title={displayName(registration) || "Participant badge"} width={440}>
      <div ref={box}>
        <DelegateBadge data={data} />
      </div>
      {/* Speakers' badges can't be downloaded. */}
      {String(registration.participantType ?? "")
        .trim()
        .toLowerCase() !== "speaker" && (
        <Button
          full
          icon="download"
          className="mt-4"
          loading={busy}
          disabled={!String(registration.qrCode ?? "")}
          onClick={download}
        >
          Download badge
        </Button>
      )}
    </Modal>
  );
}

/* ------------------------------------------------------------------ */
/* Claimed inclusions with Reclaim                                     */
/* ------------------------------------------------------------------ */

export function ClaimsModal({
  eventId,
  registration,
  onClose,
  onChanged,
}: {
  eventId: string;
  registration: any;
  onClose: () => void;
  onChanged: () => void;
}) {
  const toast = useToast();
  const [claims, setClaims] = useState<any[]>(registration.claimedInclusions ?? []);
  const [busyId, setBusyId] = useState<string | null>(null);

  const reclaim = async (c: any) => {
    const claimId = String(c.id ?? "");
    if (!claimId) return;
    setBusyId(claimId);
    const res = await post(`/managed-events/${eventId}/registrations/${idOf(registration)}/claims/${claimId}/reclaim`);
    setBusyId(null);
    if (res.success) {
      setClaims(res.registration?.claimedInclusions ?? []);
      onChanged();
    } else toast(res.error || "Failed to reclaim", "error");
  };

  return (
    <Modal open onClose={onClose} title="Claimed Inclusions" width={520}>
      <div className="-mt-2 mb-4 text-sm text-muted">{displayName(registration)}</div>
      {claims.length === 0 ? (
        <div className="py-6 text-center text-sm text-muted">No inclusions claimed yet</div>
      ) : (
        <div className="divide-y divide-line">
          {claims.map((c, i) => {
            const at = parseDate(c.claimedAt);
            const id = String(c.id ?? i);
            return (
              <div key={id} className="flex items-center gap-3 py-3">
                <Icon name="check_circle" size={20} color="#16A34A" />
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <span className="truncate text-sm font-semibold">{c.inclusionName}</span>
                    {c.reclaimedByAdmin === true && (
                      <span className="rounded-full bg-accent/10 px-1.5 py-0.5 text-[9.5px] font-extrabold text-accent">
                        By Admin
                      </span>
                    )}
                  </div>
                  {at && <div className="text-xs text-muted">{fmtShortDateTime(at)}</div>}
                </div>
                <Button
                  small
                  variant="ghost"
                  className="!text-[#F87171]"
                  disabled={busyId === id}
                  onClick={() => reclaim(c)}
                >
                  {busyId === id ? <Spinner size={14} /> : <Icon name="replay" size={16} />}
                  Reclaim
                </Button>
              </div>
            );
          })}
        </div>
      )}
    </Modal>
  );
}
