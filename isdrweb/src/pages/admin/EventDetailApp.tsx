/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useRef, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { AppBar } from "@/components/ui";
import { AppBarAction } from "@/components/app/AppChrome";
import { AppSpinner } from "@/components/app/AppControls";
import ExportMenu from "@/components/ExportMenu";
import { Icon, useConfirm, useToast } from "@/components/ui";
import { del, get, put, qs } from "@/lib/api";
import { fullNameOf } from "@/lib/exporter";
import { idOf, parseDate } from "@/lib/format";
import { idPrefixes, inIdRange } from "@/components/ListFilters";
import {
  BadgeModal,
  ClaimsModal,
  PackageModal,
  ParticipantModal,
  eventDays,
  normalizeInclusions,
  paymentModeLabel,
  rateOf,
} from "./EventManage";
import { ImportParticipantsModal } from "./ImportParticipants";
import { PARTICIPANT_EXPORT_COLUMNS, PARTICIPANT_QR } from "./participantExport";

const WEEK = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const MON = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
/** "Wed, 30 Sep 2026 · 9:00 AM" (the app's _dateFmt · _timeFmt). */
function whenText(d: Date) {
  const h = d.getHours();
  return `${WEEK[d.getDay()]}, ${d.getDate()} ${MON[d.getMonth()]} ${d.getFullYear()} · ${h % 12 || 12}:${String(
    d.getMinutes(),
  ).padStart(2, "0")} ${h < 12 ? "AM" : "PM"}`;
}

/** Flutter M3 TextButton.icon (primary colour, 14 / 500). */
function TextBtn({
  icon,
  children,
  onClick,
  disabled,
  color = "#3B82F6",
}: {
  icon: string;
  children: React.ReactNode;
  onClick?: () => void;
  disabled?: boolean;
  color?: string;
}) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className="inline-flex h-10 items-center gap-2 rounded-full px-3 text-sm font-medium active:bg-white/5 disabled:opacity-40"
      style={{ color }}
    >
      <Icon name={icon} size={18} />
      {children}
    </button>
  );
}

/** Flutter M3 OutlinedButton.icon (40px pill, outline border). */
function OutlinedBtn({
  icon,
  children,
  onClick,
  disabled,
  color = "#3B82F6",
  border = "#8E8E98",
  small,
}: {
  icon: string;
  children: React.ReactNode;
  onClick?: () => void;
  disabled?: boolean;
  color?: string;
  border?: string;
  small?: boolean;
}) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className={`inline-flex items-center gap-2 rounded-full border text-sm font-medium active:bg-white/5 disabled:opacity-40 ${
        small ? "px-2.5 py-1.5" : "h-10 px-4"
      }`}
      style={{ color, borderColor: border }}
    >
      <Icon name={icon} size={16} />
      {children}
    </button>
  );
}

/** The app's TickBox (read-only): green tick when offered, red box when not. */
function TickBox({ on }: { on: boolean }) {
  return (
    <span className="flex h-7 w-7 items-center justify-center">
      <span
        className="flex h-[18px] w-[18px] items-center justify-center rounded border-[1.6px]"
        style={{ borderColor: on ? "#16A34A" : "#DC2626", background: on ? "#16A34A" : "rgba(239,68,68,0.15)" }}
      >
        {on && <Icon name="check" size={14} />}
      </span>
    </span>
  );
}

function StatPill({ text, color }: { text: string; color: string }) {
  return (
    <span className="rounded-full px-2 py-0.5 text-[11px] font-bold" style={{ background: `${color}1a`, color }}>
      {text}
    </span>
  );
}

/** Event detail at phone width — the app's EventManagementDetailsPage. */
export default function EventDetailApp() {
  const { id = "" } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const toast = useToast();
  const confirm = useConfirm();
  const [event, setEvent] = useState<any>(null);
  const [registrations, setRegistrations] = useState<any[]>([]);
  const [loadingRegs, setLoadingRegs] = useState(true);
  const [incStats, setIncStats] = useState<Record<string, any>>({});
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  // ID code range: 2-letter prefix plus optional from / to numbers.
  const [idPrefix, setIdPrefix] = useState("");
  const [idFrom, setIdFrom] = useState("");
  const [idTo, setIdTo] = useState("");
  const [expanded, setExpanded] = useState<Set<string>>(new Set());
  const [pkgEditing, setPkgEditing] = useState<any | null | undefined>(undefined);
  const [regEditing, setRegEditing] = useState<any | null | undefined>(undefined);
  const [badgeFor, setBadgeFor] = useState<any | null>(null);
  const [claimsFor, setClaimsFor] = useState<any | null>(null);
  const [importing, setImporting] = useState(false);
  const [visibleCount, setVisibleCount] = useState(40);
  const refreshLock = useRef(false);
  const [error, setError] = useState<string | null>(null);

  const show = (msg: string, kind: "success" | "error" = "success") => {
    setMessage(msg);
    toast(msg, kind);
  };

  const loadStats = useCallback(async () => {
    const res = await get(`/managed-events/summary${qs({ eventId: id, date: "to-date" })}`);
    if (!res.success) return;
    const rows: any[] = res.summary?.inclusions ?? [];
    setIncStats(Object.fromEntries(rows.map((r) => [`${r.packageName}|${r.name}`, r])));
  }, [id]);

  const loadRegs = useCallback(
    async (silent = false) => {
      if (refreshLock.current) return;
      refreshLock.current = true;
      if (!silent) setLoadingRegs(true);
      try {
        const res = await get(`/managed-events/${id}/registrations`);
        if (res.success) setRegistrations(res.registrations ?? []);
      } finally {
        if (!silent) setLoadingRegs(false);
        refreshLock.current = false;
      }
    },
    [id],
  );

  const loadAll = useCallback(async () => {
    const ev = await get(`/managed-events/${id}`);
    if (!ev.success) return setError(ev.error || "Could not load event");
    setEvent(ev.event);
    await loadRegs();
    loadStats();
  }, [id, loadRegs, loadStats]);
  useEffect(() => {
    loadAll();
  }, [loadAll]);
  // Refresh claims without stacking another full download on top of one still running.
  useEffect(() => {
    const t = setInterval(async () => {
      if (refreshLock.current) return;
      await loadRegs(true);
    }, 8000);
    return () => clearInterval(t);
  }, [loadRegs]);

  const packages: any[] = event?.packages ?? [];
  const isCancelled = event?.status === "cancelled";

  const deleteEvent = async () => {
    if (
      !(await confirm({
        title: `Delete "${event?.title}" and all its participants permanently?`,
        confirm: "Delete",
        cancel: "No",
      }))
    )
      return;
    setBusy(true);
    const res = await del(`/managed-events/${id}?permanent=true`);
    setBusy(false);
    if (res.success) navigate("/admin/events", { replace: true });
    else show(res.error || "Delete failed", "error");
  };

  const savePackages = async (next: any[], okMessage: string) => {
    setBusy(true);
    const res = await put(`/managed-events/${id}`, { packages: next });
    setBusy(false);
    if (!res.success) {
      show(res.error || "Failed to save package", "error");
      return false;
    }
    if (res.event) setEvent(res.event);
    loadStats();
    show(okMessage);
    return true;
  };

  const removePackage = async (pkgId: string) => {
    if (!(await confirm({ title: "Remove this package?", confirm: "Remove", cancel: "No" }))) return;
    await savePackages(
      packages.filter((p) => p.id !== pkgId),
      "Package removed",
    );
  };

  const deleteParticipant = async (r: any) => {
    if (!(await confirm({ title: `Delete registration for "${r.name}"?`, confirm: "Delete", cancel: "No" }))) return;
    setBusy(true);
    const res = await del(`/managed-events/${id}/registrations/${idOf(r)}`);
    setBusy(false);
    if (res.success) {
      show("Participant deleted");
      loadAll();
    } else show(res.error || "Failed to delete participant", "error");
  };

  const existingIds = (self: any | null) =>
    new Set(
      registrations
        .filter((r) => !self || idOf(r) !== idOf(self))
        .map((r) => String(r.idNumber ?? "").trim())
        .filter(Boolean),
    );

  const q = search.trim().toLowerCase();
  const shown = registrations.filter(
    (r) =>
      inIdRange(r, idPrefix, idFrom, idTo) &&
      (!q ||
        Object.values(r).some(
          (v) => (typeof v === "string" || typeof v === "number") && String(v).toLowerCase().includes(q),
        )),
  );
  const visibleShown = shown.slice(0, visibleCount);
  useEffect(() => {
    setVisibleCount(40);
  }, [q, idPrefix, idFrom, idTo]);

  if (error)
    return (
      <div className="min-h-screen bg-bg">
        <AppBar title="Event" />
        <div className="px-6 pt-20 text-center text-sm text-muted">{error}</div>
      </div>
    );
  if (!event)
    return (
      <div className="min-h-screen bg-bg">
        <AppBar title="Event" />
        <AppSpinner />
      </div>
    );

  const start = parseDate(event.eventDate);
  const end = parseDate(event.eventEndDate);
  const days = eventDays(event);

  return (
    <div className="min-h-screen bg-bg pb-8">
      <AppBar
        title={event.title || "Event"}
        actions={
          <>
            <AppBarAction
              icon="edit"
              title="Edit event"
              onClick={() => !busy && navigate(`/admin/events/new?id=${id}`)}
            />
            <AppBarAction icon="delete" title="Delete event" onClick={() => !busy && deleteEvent()} />
          </>
        }
      />
      <div className="px-4 pt-4">
        {message && <div className="mb-3 font-semibold text-accent">{message}</div>}

        {/* Event card */}
        <div className="overflow-hidden rounded-2xl border border-line bg-card">
          {event.photoUrl && <img src={event.photoUrl} alt="" className="h-[180px] w-full object-cover" />}
          <div className="p-4">
            <div className="flex items-start gap-2">
              <div className="flex-1 text-xl font-extrabold">{event.title || "Event"}</div>
              <span
                className="rounded-full px-2.5 py-[3px] text-[11px] font-extrabold"
                style={
                  isCancelled
                    ? { background: "rgba(239,68,68,0.15)", color: "#FCA5A5" }
                    : { background: "rgba(34,197,94,0.15)", color: "#86EFAC" }
                }
              >
                {event.status ?? "Active"}
              </span>
            </div>
            {event.venue && <div className="mt-1.5 text-muted">📍 {event.venue}</div>}
            {start && <div className="mt-1.5 font-semibold">{whenText(start)}</div>}
            {end && <div className="mt-0.5 font-semibold">to {whenText(end)}</div>}
            <div className="mt-1.5 text-muted">{event.bookedCount ?? 0} registered</div>
            {event.description && <div className="mt-3 whitespace-pre-wrap">{event.description}</div>}
          </div>
        </div>

        {/* Packages */}
        <div className="mt-4 flex items-center">
          <div className="flex-1 text-[17px] font-extrabold">Packages ({packages.length})</div>
          <TextBtn icon="add" disabled={busy} onClick={() => setPkgEditing(null)}>
            Add Package
          </TextBtn>
        </div>
        <div className="mt-1.5">
          {packages.length === 0 ? (
            <div className="py-2 text-muted">No packages added yet.</div>
          ) : (
            packages.map((p) => {
              const rate = rateOf(p);
              const inclusions = normalizeInclusions(p.inclusions);
              const ee: string[] = (p.entryExitDates ?? []).map(String);
              const eeCount = ee.length ? ee.length : days.length;
              return (
                <div key={p.id} className="mb-2.5 rounded-2xl border border-line bg-card p-3.5">
                  <div className="flex items-center gap-2">
                    <div className="flex-1 text-[15px] font-extrabold">{p.name}</div>
                    <span
                      className="rounded-lg px-2.5 py-1 text-[12.5px] font-extrabold"
                      style={
                        rate === 0
                          ? { background: "rgba(34,197,94,0.15)", color: "#86EFAC" }
                          : { background: "rgba(59,130,246,0.15)", color: "#2563EB" }
                      }
                    >
                      {rate === 0 ? "Free" : `₹${rate}${p.paymentMode ? ` · ${paymentModeLabel(p.paymentMode)}` : ""}`}
                    </span>
                  </div>
                  <div className="mt-2 inline-flex items-center gap-1.5 rounded-lg border border-[#22C55E]/30 bg-[#22C55E]/[0.12] px-2.5 py-[5px] text-xs font-bold text-[#86EFAC]">
                    <Icon name="login" size={14} color="#22C55E" />
                    Entry &amp; Exit: {eeCount} of {days.length} {days.length === 1 ? "day" : "days"} authorized
                  </div>
                  <div className="mt-2">
                    {inclusions.length === 0 ? (
                      <div className="text-[12.5px] text-muted">No inclusions added.</div>
                    ) : (
                      inclusions.map((inc) => {
                        const st = incStats[`${p.name}|${inc.name}`] ?? {};
                        return (
                          <div key={inc.name} className="mb-2">
                            <div className="font-bold">{inc.name}</div>
                            <div className="mt-1 flex flex-wrap gap-x-1.5 gap-y-1">
                              <StatPill text={`${st.scanned ?? 0} Scanned`} color="#16A34A" />
                              <StatPill text={`${st.notScanned ?? 0} Not scanned`} color="#D97706" />
                              <StatPill text={`${st.rejected ?? 0} Rejected`} color="#DC2626" />
                            </div>
                            {days.length > 0 && (
                              <div className="mt-1 flex flex-wrap gap-x-3 gap-y-1.5">
                                {days.map((d) => (
                                  <span key={d.iso} className="flex items-center gap-[3px] text-xs">
                                    <TickBox on={inc.dates.includes(d.iso)} />
                                    {d.label}
                                  </span>
                                ))}
                              </div>
                            )}
                          </div>
                        );
                      })
                    )}
                  </div>
                  <div className="mt-1 flex gap-2">
                    <OutlinedBtn icon="edit" disabled={busy} onClick={() => setPkgEditing(p)}>
                      Edit
                    </OutlinedBtn>
                    <OutlinedBtn icon="delete" color="#EF4444" disabled={busy} onClick={() => removePackage(p.id)}>
                      Remove
                    </OutlinedBtn>
                  </div>
                </div>
              );
            })
          )}
        </div>

        {/* Participants */}
        <div className="mt-4 text-[17px] font-extrabold">
          {q ? `Participants (${shown.length} of ${registrations.length})` : `Participants (${registrations.length})`}
        </div>
        {/* Website extras kept on phones: Excel import and list download. */}
        <div className="mb-1.5 mt-1 flex flex-wrap items-center gap-2">
          <OutlinedBtn icon="upload_file" small disabled={busy} onClick={() => setImporting(true)}>
            Import Excel
          </OutlinedBtn>
          <ExportMenu
            small
            title={`${event.title || "Event"} - Participants`}
            rows={shown}
            columns={PARTICIPANT_EXPORT_COLUMNS}
            qr={PARTICIPANT_QR}
          />
        </div>
        <div className="relative">
          <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2">
            <Icon name="search" size={20} color="#9CA3AF" />
          </span>
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search participants…"
            className="w-full rounded-xl border border-[#8E8E98] bg-field py-2.5 pl-10 pr-10 text-sm outline-none placeholder:text-muted focus:border-2 focus:border-accent"
          />
          {search && (
            <button
              onClick={() => setSearch("")}
              aria-label="Clear"
              className="absolute right-1 top-1/2 flex h-9 w-9 -translate-y-1/2 items-center justify-center"
            >
              <Icon name="clear" size={18} color="#9CA3AF" />
            </button>
          )}
        </div>
        <div className="mt-2 flex items-center gap-2">
          <select value={idPrefix} onChange={(e) => setIdPrefix(e.target.value)} className="rounded-xl border border-[#8E8E98] bg-field text-sm outline-none focus:border-accent px-2 py-2">
            <option value="">All ID codes</option>
            {idPrefixes(registrations).map((p) => (
              <option key={p} value={p}>
                {p}
              </option>
            ))}
          </select>
          {idPrefix && (
            <>
              <input
                value={idFrom}
                onChange={(e) => setIdFrom(e.target.value)}
                inputMode="numeric"
                placeholder="From"
                className="w-0 flex-1 rounded-xl border border-[#8E8E98] bg-field text-sm outline-none focus:border-accent px-3 py-2 placeholder:text-muted"
              />
              <span className="text-xs text-muted">to</span>
              <input
                value={idTo}
                onChange={(e) => setIdTo(e.target.value)}
                inputMode="numeric"
                placeholder="To"
                className="w-0 flex-1 rounded-xl border border-[#8E8E98] bg-field text-sm outline-none focus:border-accent px-3 py-2 placeholder:text-muted"
              />
            </>
          )}
        </div>
        <div className="mt-2.5">
          {loadingRegs ? (
            <AppSpinner top={24} />
          ) : shown.length === 0 ? (
            <div className="py-2 text-muted">
              {registrations.length === 0
                ? "No participants registered for this event yet."
                : "No participants match your search."}
            </div>
          ) : (
            visibleShown.map((r) => {
              const regId = idOf(r);
              const open = expanded.has(regId);
              const name = fullNameOf(r) || r.name || r.idNumber || "Participant";
              const line = [r.designation, r.institution].filter(Boolean).join(" · ");
              const claimed = (r.claimedInclusions ?? []).length;
              const info = (label: string, value: any) =>
                value ? (
                  <div className="mt-0.5 text-[12.5px]">
                    <span className="text-muted">{label}: </span>
                    {value}
                  </div>
                ) : null;
              return (
                <div key={regId} className="mb-2.5 overflow-hidden rounded-2xl border border-line bg-card">
                  <div
                    className="cursor-pointer p-3"
                    onClick={() =>
                      setExpanded((s) => {
                        const n = new Set(s);
                        if (n.has(regId)) n.delete(regId);
                        else n.add(regId);
                        return n;
                      })
                    }
                  >
                    <div className="flex items-center">
                      <span className="flex h-11 w-11 shrink-0 items-center justify-center overflow-hidden rounded-full bg-field">
                        {r.photoUrl ? (
                          <img src={r.photoUrl} alt="" className="h-full w-full object-cover" />
                        ) : (
                          <Icon name="person" color="#9CA3AF" />
                        )}
                      </span>
                      <div className="ml-2.5 min-w-0 flex-1">
                        <div className="text-[14.5px] font-extrabold">{name}</div>
                        {line && <div className="text-xs text-muted">{line}</div>}
                      </div>
                      <span className="rounded-md bg-field px-2 py-[3px] font-mono text-[13px] font-extrabold">
                        {r.idNumber}
                      </span>
                      <span
                        className="ml-1 transition-transform duration-200"
                        style={{ transform: open ? "rotate(180deg)" : undefined }}
                      >
                        <Icon name="keyboard_arrow_down" color="#9CA3AF" />
                      </span>
                    </div>
                    {open && (
                      <div className="mt-2.5" onClick={(e) => e.stopPropagation()}>
                        <div className="h-px bg-field" />
                        <div className="mt-2">
                          {info("Type", r.participantType)}
                          {info("Package", r.packageName)}
                          {info("Gender", r.gender)}
                          {info("Mobile", r.mobileNumber)}
                          {info("Email", r.email)}
                          {info("ID no.", r.idNumber)}
                          {info("Food", r.foodPreference)}
                          {info("Payment", [r.paymentMode, r.utrNumber].filter(Boolean).join(" · "))}
                          {info("Address", r.address)}
                        </div>
                        {claimed > 0 && (
                          <div className="mt-1">
                            <OutlinedBtn
                              icon="verified"
                              small
                              color="#16A34A"
                              border="#16A34A"
                              onClick={() => setClaimsFor(r)}
                            >
                              Claimed: {claimed} inclusion{claimed === 1 ? "" : "s"}
                            </OutlinedBtn>
                          </div>
                        )}
                        <div className="mt-1.5 flex justify-end">
                          <button
                            title="Edit"
                            onClick={() => setRegEditing(r)}
                            className="flex h-10 w-10 items-center justify-center rounded-full active:bg-white/10"
                          >
                            <Icon name="edit" outline size={20} />
                          </button>
                          <button
                            title="QR"
                            onClick={() => setBadgeFor(r)}
                            className="flex h-10 w-10 items-center justify-center rounded-full active:bg-white/10"
                          >
                            <Icon name="qr_code_2" size={22} />
                          </button>
                          <button
                            title="Delete"
                            disabled={busy}
                            onClick={() => deleteParticipant(r)}
                            className="flex h-10 w-10 items-center justify-center rounded-full active:bg-white/10 disabled:opacity-40"
                          >
                            <Icon name="delete" outline size={20} color="#EF4444" />
                          </button>
                        </div>
                      </div>
                    )}
                  </div>
                </div>
              );
            })
          )}
          {shown.length > visibleShown.length && (
            <button
              type="button"
              onClick={() => setVisibleCount((n) => n + 40)}
              className="mt-1 w-full rounded-xl border border-line py-2.5 text-sm font-semibold"
            >
              Show more ({shown.length - visibleShown.length} left)
            </button>
          )}
        </div>
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
          optionalFields
          onClose={() => setRegEditing(undefined)}
          onSaved={(saved) => {
            const wasNew = !regEditing;
            setRegEditing(undefined);
            loadAll();
            if (!wasNew) show("Participant updated successfully");
            else if (Object.keys(saved).length) setBadgeFor(saved);
          }}
        />
      )}
      {badgeFor && <BadgeModal registration={badgeFor} onClose={() => setBadgeFor(null)} />}
      {claimsFor && (
        <ClaimsModal
          eventId={id}
          registration={claimsFor}
          onClose={() => setClaimsFor(null)}
          onChanged={() => loadRegs(true)}
        />
      )}
      {importing && (
        <ImportParticipantsModal
          eventId={id}
          packages={packages}
          registrations={registrations}
          onClose={() => setImporting(false)}
          onDone={loadAll}
        />
      )}
    </div>
  );
}
