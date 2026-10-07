/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useRef, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { AppBar, Icon, useToast } from "@/components/ui";
import { AppBarAction } from "@/components/app/AppChrome";
import { AppSpinner } from "@/components/app/AppControls";
import { istDay } from "@/components/InclusionsSection";
import { get, post } from "@/lib/api";
import { idOf, parseDate } from "@/lib/format";
import { startQrCamera } from "./startQrCamera";

const MON = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const hm = (d: Date) => {
  const h = d.getHours();
  return `${h % 12 || 12}:${String(d.getMinutes()).padStart(2, "0")} ${h < 12 ? "AM" : "PM"}`;
};

/* ------------------------------------------------------------------ */
/* Events — the app's UserEventsListPage                               */
/* ------------------------------------------------------------------ */

export function StaffEventsApp() {
  const navigate = useNavigate();
  const [events, setEvents] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    get("/managed-events").then((r) => {
      setLoading(false);
      if (r.success) setEvents(r.events ?? []);
      else setError(r.error || "Failed to load events");
    });
  }, []);

  return (
    <div className="min-h-screen bg-bg">
      <AppBar title="Events" />
      {loading ? (
        <AppSpinner />
      ) : error ? (
        <div className="pt-[120px] text-center text-[#EF4444]">{error}</div>
      ) : events.length === 0 ? (
        <div className="pt-[140px] text-center text-black/55">No events created yet for this property.</div>
      ) : (
        <div className="space-y-3 p-4">
          {events.map((ev) => {
            const d = parseDate(ev.eventDate);
            const published = ev.status === "published";
            return (
              <button
                key={idOf(ev)}
                onClick={() => navigate(`/staff/events/${idOf(ev)}`)}
                className="block w-full overflow-hidden rounded-[18px] bg-card text-left shadow-[0_1px_3px_rgba(0,0,0,0.3)] active:brightness-110"
              >
                {ev.photoUrl && <img src={ev.photoUrl} alt="" className="h-[140px] w-full object-cover" />}
                <div className="p-4">
                  <div className="flex items-center justify-between">
                    <span
                      className="rounded-full px-2.5 py-[3px] text-[11px] font-extrabold"
                      style={
                        published
                          ? { background: "rgba(34,197,94,0.15)", color: "#86EFAC" }
                          : { background: "#1E1E2A", color: "#CBD5E1" }
                      }
                    >
                      {String(ev.status ?? "active").toUpperCase()}
                    </span>
                    <span className="text-xs font-bold text-[#2563EB]">{ev.bookedCount ?? 0} registered</span>
                  </div>
                  <div className="mt-2 text-[17px] font-extrabold">{ev.title}</div>
                  {ev.venue && <div className="mt-1 text-[13px] text-[#CBD5E1]">📍 {ev.venue}</div>}
                  <div className="mt-1 text-[13px] text-muted">
                    {d ? `📅 ${d.getDate()}/${d.getMonth() + 1}/${d.getFullYear()} · ${hm(d)}` : "—"}
                  </div>
                </div>
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Event — the app's UserEventDetailsPage                              */
/* ------------------------------------------------------------------ */

type Scan = {
  kind: "claim" | "entry" | "exit";
  name: string;
  packageId?: string;
};

/** One tile per inclusion name. Available when today is ticked on any package. */
export function collapsedInclusions(packages: any[], today: string) {
  const merged = new Map<string, { name: string; dates: string[]; available: boolean }>();
  const order: string[] = [];
  for (const pkg of packages ?? []) {
    for (const e of (pkg?.inclusions ?? []) as any[]) {
      const name = String(e && typeof e === "object" ? e.name : e).trim();
      if (!name) continue;
      const key = name.toLowerCase();
      const list: unknown[] = Array.isArray(e?.dates) ? e.dates : [];
      const dates = list.map((d) => String(d));
      const hit = dates.includes(today);
      const existing = merged.get(key);
      if (!existing) {
        order.push(key);
        merged.set(key, { name, dates: [...new Set(dates)], available: hit });
      } else {
        existing.dates = [...new Set([...existing.dates, ...dates])];
        if (hit) existing.available = true;
      }
    }
  }
  return order.map((key) => merged.get(key)!);
}

export function StaffEventDetailApp() {
  const { id = "" } = useParams<{ id: string }>();
  const toast = useToast();
  const [event, setEvent] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [scan, setScan] = useState<Scan | null>(null);
  const [history, setHistory] = useState(false);

  const load = useCallback(async () => {
    const r = await get(`/managed-events/${id}`);
    setLoading(false);
    if (r.success) setEvent(r.event);
    else setError(r.error || "Failed to load event");
  }, [id]);
  useEffect(() => {
    load();
  }, [load]);

  if (scan)
    return (
      <ScannerApp
        heading={scan.kind === "claim" ? "Claim Benefit" : "Attendance"}
        name={scan.name}
        itemLabel={scan.kind === "claim" ? "Benefit" : "Scan"}
        successText={
          scan.kind === "claim"
            ? "Participant is eligible. Benefit claim registered."
            : `${scan.kind === "entry" ? "Entry" : "Exit"} recorded for today.`
        }
        event={event ?? {}}
        submit={(c) =>
          scan.kind === "claim"
            ? post("/managed-events/claim-inclusion", {
                inclusionName: scan.name,
                ...(scan.packageId ? { packageId: scan.packageId } : {}),
                ...c,
              })
            : post("/certificates/scan", { type: scan.kind, ...c })
        }
        onClaimed={scan.kind === "claim" ? load : undefined}
        onClose={() => setScan(null)}
      />
    );
  if (history) return <ClaimHistoryApp eventId={id} onClose={() => setHistory(false)} />;

  const fmtDay = (raw: any) => {
    const d = parseDate(raw);
    return d ? `${d.getDate()} ${MON[d.getMonth()]} ${d.getFullYear()}` : "";
  };
  const start = fmtDay(event?.eventDate);
  const end = fmtDay(event?.eventEndDate);
  const dateText = end && end !== start ? `${start} - ${end}` : start;
  const today = istDay(new Date());
  const inclusions = collapsedInclusions(event?.packages ?? [], today);
  const scheduleDates = (dates: string[]) =>
    [...dates]
      .sort()
      .map((d) => {
        const [, m, day] = d.split("-");
        return `${Number(day)} ${MON[Number(m) - 1] ?? m}`;
      })
      .join(", ");

  const attendanceButton = (kind: "entry" | "exit", title: string, icon: string, color: string) => (
    <button
      onClick={() => setScan({ kind, name: `${title.split(" ")[0]} Scan` })}
      className="flex flex-1 items-center rounded-2xl border px-3 py-3.5 text-left"
      style={{ background: `${color}1f`, borderColor: `${color}80` }}
    >
      <span
        className="flex h-[38px] w-[38px] shrink-0 items-center justify-center rounded-[11px]"
        style={{ background: color }}
      >
        <Icon name={icon} size={20} />
      </span>
      <span className="ml-2.5">
        <span className="block text-[14.5px] font-extrabold">{title}</span>
        <span className="block text-[11.5px] text-muted">Tap to scan</span>
      </span>
    </button>
  );

  return (
    <div className="min-h-screen bg-bg">
      <AppBar
        title={event?.title || "Event"}
        actions={<AppBarAction icon="history" title="Scan & Claim History" onClick={() => setHistory(true)} />}
      />
      {loading ? (
        <AppSpinner />
      ) : error || !event ? (
        <div className="pt-40 text-center text-[#EF4444]">{error ?? "Event not found"}</div>
      ) : (
        <div className="p-4">
          <div className="overflow-hidden rounded-2xl bg-card shadow-[0_4px_12px_rgba(255,255,255,0.05)]">
            {event.photoUrl && <img src={event.photoUrl} alt="" className="h-40 w-full object-cover" />}
            <div className="p-4">
              {event.venue && (
                <div className="mb-1.5 flex items-center gap-2 text-[13.5px] font-semibold text-[#CBD5E1]">
                  <Icon name="location_on" outline size={16} color="#2563EB" />
                  {event.venue}
                </div>
              )}
              {dateText && (
                <div className="mb-1.5 flex items-center gap-2 text-[13.5px] font-semibold text-[#CBD5E1]">
                  <Icon name="calendar_today" outline size={16} color="#2563EB" />
                  {dateText}
                </div>
              )}
              {event.description && (
                <div className="mt-1 text-[13px] leading-[1.4] text-muted">{event.description}</div>
              )}
            </div>
          </div>

          <div className="mt-[18px] text-base font-bold">Entry &amp; Exit</div>
          <div className="mt-1 text-xs text-muted">
            Once per participant per day — both are needed for the certificate.
          </div>
          <div className="mt-2.5 flex gap-2.5">
            {attendanceButton("entry", "Entry Scan", "login", "#22C55E")}
            {attendanceButton("exit", "Exit Scan", "logout", "#EF4444")}
          </div>

          <div className="mt-[22px] text-base font-bold">Inclusions</div>
          <div className="mt-3">
            {inclusions.length === 0 ? (
              <div className="rounded-2xl border border-[#CBD5E1] bg-bg p-5 text-muted">
                No inclusions configured for this event.
              </div>
            ) : (
              <div className="rounded-2xl bg-card p-4 shadow-[0_4px_12px_rgba(255,255,255,0.05)]">
                <div className="grid grid-cols-3 gap-2">
                  {inclusions.map((inc) => (
                    <button
                      key={inc.name}
                      onClick={() =>
                        inc.available
                          ? setScan({ kind: "claim", name: inc.name })
                          : toast(
                              inc.dates.length
                                ? `"${inc.name}" is not available today. Scheduled for: ${scheduleDates(inc.dates)}.`
                                : `"${inc.name}" is not available today. No days selected.`,
                              "error",
                            )
                      }
                      className="flex flex-col items-center justify-center rounded-[10px] px-2 py-3 text-center"
                      style={{ background: inc.available ? "#1E1E2A" : "#0A0A12" }}
                    >
                      <Icon
                        name={inc.available ? "check" : "lock"}
                        outline={!inc.available}
                        size={20}
                        color={inc.available ? "#22C55E" : "#CBD5E1"}
                      />
                      <span
                        className="mt-1.5 line-clamp-2 text-[13px] font-semibold"
                        style={{ color: inc.available ? "#fff" : "#9CA3AF" }}
                      >
                        {inc.name}
                      </span>
                    </button>
                  ))}
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Scanner — the app's ClaimInclusionScannerPage (full screen)          */
/* ------------------------------------------------------------------ */

const AUTO_NEXT = 3;

function ScannerApp({
  heading,
  name,
  itemLabel,
  successText,
  event,
  submit,
  onClaimed,
  onClose,
}: {
  heading: string;
  name: string;
  itemLabel: string;
  successText: string;
  event: any;
  submit: (c: { qrData?: string; idNumber?: string }) => Promise<any>;
  onClaimed?: () => void;
  onClose: () => void;
}) {
  const [qrMode, setQrMode] = useState(true);
  const [code, setCode] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [result, setResult] = useState<any | null>(null);
  const [left, setLeft] = useState(0);
  const [camDenied, setCamDenied] = useState(false);
  const [camReady, setCamReady] = useState(false);
  const [torch, setTorch] = useState(false);
  const scanner = useRef<any>(null);
  const handled = useRef(false);
  const regionId = "app-qr-region";

  const run = useCallback(
    async (c: { qrData?: string; idNumber?: string }) => {
      if (handled.current) return;
      handled.current = true;
      setSubmitting(true);
      const res = await submit(c);
      setSubmitting(false);
      setResult(res);
      if (res.success) onClaimed?.();
      setLeft(AUTO_NEXT);
    },
    [submit, onClaimed],
  );

  useEffect(() => {
    if (!qrMode || result) return;
    let cancelled = false;
    handled.current = false;
    setCamDenied(false);
    setCamReady(false);
    (async () => {
      try {
        const cam = await startQrCamera(regionId, (text) => run({ qrData: text }), () => cancelled);
        if (!cam || cancelled) {
          await cam?.stop();
          return;
        }
        scanner.current = cam;
        setCamReady(true);
      } catch {
        if (!cancelled) setCamDenied(true);
      }
    })();
    return () => {
      cancelled = true;
      const cam = scanner.current;
      scanner.current = null;
      setTorch(false);
      cam?.stop();
    };
  }, [qrMode, result, run]);

  useEffect(() => {
    if (!result) return;
    if (left <= 0) {
      setResult(null);
      setCode("");
      setQrMode(true);
      return;
    }
    const t = setTimeout(() => setLeft((s) => s - 1), 1000);
    return () => clearTimeout(t);
  }, [result, left]);

  const reset = () => {
    setLeft(0);
    setResult(null);
    setCode("");
    setQrMode(true);
  };

  const toggleTorch = async () => {
    try {
      await scanner.current?.applyVideoConstraints({ advanced: [{ torch: !torch }] });
      setTorch((t) => !t);
    } catch {
      /* torch not supported */
    }
  };

  return (
    <div className="fixed inset-0 z-[80] flex flex-col bg-[#0F172A]">
      <div className="flex h-14 shrink-0 items-center px-1">
        <button
          onClick={onClose}
          aria-label="Back"
          className="flex h-12 w-12 items-center justify-center rounded-full active:bg-white/10"
        >
          <Icon name="arrow_back" size={24} />
        </button>
        <div className="ml-1 min-w-0 flex-1">
          <div className="text-[13px] font-semibold text-white/60">{heading}</div>
          <div className="truncate text-lg font-extrabold">{name}</div>
        </div>
        {qrMode && camReady && !result && (
          <button
            onClick={toggleTorch}
            aria-label="Torch"
            className="flex h-12 w-12 items-center justify-center rounded-full active:bg-white/10"
          >
            <Icon name={torch ? "flash_on" : "flash_off"} size={24} />
          </button>
        )}
      </div>
      <div className="px-5 py-3">
        <div className="flex rounded-2xl bg-white/10 p-1">
          {[
            { on: qrMode, label: "📷 Scan QR", click: () => setQrMode(true) },
            { on: !qrMode, label: "🎟️ Manual Code", click: () => setQrMode(false) },
          ].map((t) => (
            <button
              key={t.label}
              onClick={t.click}
              className="flex-1 rounded-xl py-2.5 text-[13px] font-extrabold transition-colors"
              style={{ background: t.on ? "#2563EB" : "transparent", color: t.on ? "#fff" : "rgba(255,255,255,0.6)" }}
            >
              {t.label}
            </button>
          ))}
        </div>
      </div>
      <div className="relative min-h-0 flex-1 overflow-y-auto">
        {result ? (
          <ResultView
            result={result}
            event={event}
            name={name}
            itemLabel={itemLabel}
            successText={successText}
            left={left}
            onNext={reset}
            onDone={onClose}
          />
        ) : qrMode ? (
          camDenied ? (
            <div className="flex h-full flex-col items-center justify-center p-8 text-center">
              <Icon name="photo_camera" outline size={56} color="rgba(255,255,255,0.38)" />
              <div className="mt-4 text-lg font-bold">Camera Access Denied</div>
              <div className="mt-2 text-[13px] text-white/70">
                Please grant camera permissions in app settings to scan badges, or switch to Manual Code.
              </div>
            </div>
          ) : (
            <div className="absolute inset-0 overflow-hidden bg-black">
              <div
                id={regionId}
                className="absolute inset-0"
              />
              {/* Dark overlay with a 300×300 cut-out, corner markers and a moving scan line */}
              <div className="pointer-events-none absolute left-1/2 top-1/2 h-[300px] w-[300px] -translate-x-1/2 -translate-y-1/2 rounded-[20px] shadow-[0_0_0_9999px_rgba(0,0,0,0.55)]">
                {[
                  "left-0 top-0 rounded-tl-2xl border-l-4 border-t-4",
                  "right-0 top-0 rounded-tr-2xl border-r-4 border-t-4",
                  "bottom-0 left-0 rounded-bl-2xl border-b-4 border-l-4",
                  "bottom-0 right-0 rounded-br-2xl border-b-4 border-r-4",
                ].map((c) => (
                  <span key={c} className={`absolute h-9 w-9 border-[#38BDF8] ${c}`} />
                ))}
                <span className="scan-line absolute left-2.5 h-[3px] w-[280px] bg-gradient-to-r from-transparent via-[#38BDF8] to-transparent shadow-[0_0_10px_2px_rgba(56,189,248,0.8)]" />
              </div>
              {!camReady && (
                <div className="absolute inset-0 flex items-center justify-center">
                  <AppSpinner top={0} />
                </div>
              )}
              <div className="absolute inset-x-5 bottom-[30px] flex items-center justify-center gap-2.5 rounded-3xl border border-[#38BDF8]/40 bg-black/75 px-[18px] py-3 shadow-[0_0_12px_2px_rgba(0,0,0,0.4)]">
                <Icon name="qr_code_scanner" size={20} color="#38BDF8" />
                <span className="text-center text-[13px] font-semibold">Align QR code inside frame to claim</span>
              </div>
              {submitting && (
                <div className="absolute inset-0 flex items-center justify-center bg-black/55">
                  <span className="h-9 w-9 animate-spin rounded-full border-4 border-[#38BDF8] border-t-transparent" />
                </div>
              )}
            </div>
          )
        ) : (
          <div className="p-6">
            <div className="rounded-[20px] bg-card p-5">
              <div className="text-xs font-extrabold tracking-[1px] text-muted">ENTER ID NUMBER</div>
              <input
                autoFocus
                value={code}
                maxLength={25}
                onChange={(e) => setCode(e.target.value.toUpperCase())}
                onKeyDown={(e) =>
                  e.key === "Enter" &&
                  code.trim() &&
                  !submitting &&
                  ((handled.current = false), run({ idNumber: code.trim() }))
                }
                placeholder="e.g. 1001"
                className="mt-2.5 w-full rounded-[14px] border border-[#CBD5E1] bg-bg px-3 py-3.5 text-center text-2xl font-black tracking-[3px] outline-none placeholder:font-normal placeholder:tracking-normal placeholder:text-white/35 focus:border-2 focus:border-accent"
              />
              <button
                disabled={submitting || !code.trim()}
                onClick={() => {
                  handled.current = false;
                  run({ idNumber: code.trim() });
                }}
                className="mt-4 h-[50px] w-full rounded-[14px] bg-[#2563EB] text-[15px] font-extrabold disabled:bg-white/10 disabled:text-white/40"
              >
                {submitting ? "Verifying..." : `Verify & Claim ${name}`}
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

function ResultView({
  result,
  event,
  name,
  itemLabel,
  successText,
  left,
  onNext,
  onDone,
}: {
  result: any;
  event: any;
  name: string;
  itemLabel: string;
  successText: string;
  left: number;
  onNext: () => void;
  onDone: () => void;
}) {
  const success = result?.success === true;
  const reg: any = result?.registration && typeof result.registration === "object" ? result.registration : null;
  const used = !success && result?.alreadyClaimed === true && !!reg;
  const denied = !success && !used;
  const r = reg ?? {};
  const pkg = (event?.packages ?? []).find(
    (p: any) => String(p.id) === String(r.packageId) || p.name === r.packageName,
  );
  const rate = Number(pkg?.rate) || 0;
  const packageText = r.packageName
    ? pkg
      ? `${r.packageName} — ${rate === 0 ? "Free" : `₹${rate}`}`
      : r.packageName
    : "";
  const now = new Date();
  const today = `${now.getDate()} ${MON[now.getMonth()]} ${now.getFullYear()}`;
  const tone = denied ? "#FCA5A5" : used ? "#FCD34D" : "#86EFAC";
  const bg = denied ? "rgba(239,68,68,0.15)" : used ? "rgba(245,158,11,0.15)" : "rgba(34,197,94,0.15)";
  const message = String(result?.error ?? result?.message ?? "");
  const line = (label: string, value: string) =>
    value ? (
      <div className="flex py-[3px]">
        <span className="w-[110px] shrink-0 text-[13px] font-semibold text-muted">{label}</span>
        <span className="text-sm font-bold">{value}</span>
      </div>
    ) : null;
  return (
    <div className="p-5">
      <div className="rounded-[20px] border-2 p-5" style={{ background: bg, borderColor: tone }}>
        <div className="flex items-center gap-2.5 text-lg font-black" style={{ color: tone }}>
          <Icon name={denied ? "cancel" : used ? "schedule" : "check_circle"} size={28} color={tone} />
          {denied ? "ACCESS DENIED" : used ? "ALREADY CLAIMED" : "ACCESS GRANTED"}
        </div>
        <div className="my-3 h-px bg-black/10" />
        {r.name && (
          <div className="mb-2 text-xl font-black" style={{ color: tone }}>
            {String(r.name).toUpperCase()}
          </div>
        )}
        {line("ID Number", String(r.idNumber ?? (reg ? "Spot" : "")))}
        {line("Type", reg && !/^spot register$/i.test(String(r.packageName || "")) ? String(r.participantType || "") : "")}
        {line("Package", packageText)}
        {line("Date", today)}
        {line("Venue", String(event?.venue ?? ""))}
        {line(itemLabel, name)}
        <div className="mt-2.5 rounded-[10px] bg-black/35 p-2.5 text-[13px] font-bold" style={{ color: tone }}>
          {denied
            ? message || "This participant is not eligible for this benefit."
            : used
              ? "This entitlement has already been redeemed."
              : successText}
        </div>
      </div>
      <button
        onClick={onNext}
        className="mt-5 flex h-[50px] w-full items-center justify-center gap-2 rounded-[14px] bg-[#2563EB] text-base font-bold"
      >
        <Icon name="qr_code_scanner" size={20} />
        {left > 0 ? `Scan Next Participant (${left})` : "Scan Next Participant"}
      </button>
      <button onClick={onDone} className="mx-auto mt-2.5 block h-10 rounded-full px-4 text-sm text-white/70">
        Done &amp; Go Back
      </button>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Scan & Claim History — the app's UserClaimHistoryPage                */
/* ------------------------------------------------------------------ */

type Claim = {
  participantName: string;
  idNumber: string;
  packageName: string;
  institution: string;
  eventTitle: string;
  inclusionName: string;
  claimedAt: Date | null;
};

export function ClaimHistoryApp({ eventId, onClose }: { eventId?: string; onClose: () => void }) {
  const [claims, setClaims] = useState<Claim[] | null>(null);
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState("ALL");

  useEffect(() => {
    (async () => {
      const events: any[] = [];
      if (eventId) events.push({ id: eventId, title: "" });
      else {
        const list = await get("/managed-events");
        if (list.success) events.push(...(list.events ?? []));
      }
      const out: Claim[] = [];
      for (const ev of events) {
        const res = await get(`/managed-events/${idOf(ev)}/registrations`);
        if (!res.success) continue;
        for (const reg of res.registrations ?? [])
          for (const c of reg.claimedInclusions ?? [])
            out.push({
              participantName: String(reg.name ?? ""),
              idNumber: String(reg.idNumber ?? ""),
              packageName: String(reg.packageName ?? ""),
              institution: String(reg.institution ?? ""),
              eventTitle: String(ev.title ?? ""),
              inclusionName: String(c.inclusionName ?? ""),
              claimedAt: parseDate(c.claimedAt),
            });
      }
      out.sort((a, b) => (b.claimedAt?.getTime() ?? 0) - (a.claimedAt?.getTime() ?? 0));
      setClaims(out);
    })();
  }, [eventId]);

  const names = [...new Set((claims ?? []).map((c) => c.inclusionName).filter(Boolean))];
  const term = search.trim().toLowerCase();
  const shown = (claims ?? []).filter(
    (c) =>
      (!term ||
        [c.participantName, c.idNumber, c.inclusionName, c.packageName].some((v) => v.toLowerCase().includes(term))) &&
      (filter === "ALL" || c.inclusionName.toLowerCase() === filter.toLowerCase()),
  );

  return (
    <div className="fixed inset-0 z-[80] flex flex-col bg-bg">
      <AppBar title="Scan & Claim History" onBack={onClose} />
      <div className="bg-card px-5 py-4">
        <div className="relative">
          <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2">
            <Icon name="search" size={20} color="#94A3B8" />
          </span>
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search participant, ID number, inclusion…"
            className="w-full rounded-xl bg-field py-3 pl-11 pr-3 text-sm outline-none placeholder:text-[13px] placeholder:text-[#94A3B8]"
          />
        </div>
        <div className="mt-2.5 flex items-center gap-1.5">
          <Icon name="filter_list" size={16} color="#9CA3AF" />
          <div className="relative flex-1">
            <select
              value={filter}
              onChange={(e) => setFilter(e.target.value)}
              className="w-full appearance-none rounded-[10px] bg-field py-2 pl-3 pr-8 text-[13px] font-bold outline-none"
            >
              <option value="ALL">All Inclusions ({(claims ?? []).length})</option>
              {names.map((n) => (
                <option key={n} value={n}>
                  {n}
                </option>
              ))}
            </select>
            <span className="pointer-events-none absolute right-2 top-1/2 -translate-y-1/2">
              <Icon name="keyboard_arrow_down" size={20} />
            </span>
          </div>
        </div>
      </div>
      <div className="min-h-0 flex-1 overflow-y-auto">
        {!claims ? (
          <AppSpinner />
        ) : shown.length === 0 ? (
          <div className="flex flex-col items-center p-8 pt-32 text-center">
            <div className="text-[40px]">📭</div>
            <div className="mt-2.5 font-extrabold">
              {claims.length === 0 ? "No inclusions claimed yet" : "No matching claim history found"}
            </div>
          </div>
        ) : (
          <div className="space-y-2.5 px-4 pb-6 pt-4">
            {shown.map((c, i) => (
              <div
                key={i}
                className="flex items-start rounded-2xl border border-white/10 bg-card p-3.5 shadow-[0_2px_8px_rgba(0,0,0,0.03)]"
              >
                <span className="flex h-[38px] w-[38px] shrink-0 items-center justify-center rounded-xl bg-accent/15 text-[15px] font-extrabold text-[#93C5FD]">
                  {c.participantName ? c.participantName[0].toUpperCase() : "?"}
                </span>
                <div className="ml-3 min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <span className="min-w-0 flex-1 truncate text-sm font-extrabold">{c.participantName || "?"}</span>
                    <span className="rounded-lg bg-accent/15 px-2 py-[3px] text-[11px] font-extrabold text-[#2563EB]">
                      #{c.idNumber || "SPOT"}
                    </span>
                  </div>
                  {!eventId && c.eventTitle && (
                    <div className="mt-0.5 truncate text-xs font-bold text-[#2563EB]">{c.eventTitle}</div>
                  )}
                  {c.institution && <div className="mt-0.5 truncate text-xs text-[#94A3B8]">{c.institution}</div>}
                  <div className="mt-2 flex flex-wrap items-center gap-x-1.5 gap-y-1">
                    <span className="rounded-[5px] border border-[#93C5FD] bg-accent/15 px-[9px] py-1 text-[11.5px] font-extrabold text-[#93C5FD]">
                      ✨ {c.inclusionName}
                    </span>
                    {c.packageName && <span className="text-xs font-bold text-[#CBD5E1]">{c.packageName}</span>}
                  </div>
                  <div className="mt-2 flex items-center gap-1 text-[11.5px] font-semibold text-[#94A3B8]">
                    <Icon name="schedule" size={13} color="#94A3B8" />
                    {c.claimedAt
                      ? `${c.claimedAt.getDate()}/${c.claimedAt.getMonth() + 1}/${c.claimedAt.getFullYear()} · ${hm(c.claimedAt)}`
                      : "—"}
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
