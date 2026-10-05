/* eslint-disable @typescript-eslint/no-explicit-any */
import { useMemo, useState } from "react";
import { Button, Icon } from "@/components/ui";
import { normalizeInclusions } from "./EventManage";

/** 'YYYY-MM-DD' in India time — the same day key the backend uses for scans. */
const istDay = (d: any) => new Date(d).toLocaleDateString("en-CA", { timeZone: "Asia/Kolkata" });
const istHour = (d: any) => Number(new Date(d).toLocaleString("en-US", { timeZone: "Asia/Kolkata", hour: "numeric", hour12: false })) % 24;
const MON = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const label = (day: string) => {
  const [, m, d] = day.split("-").map(Number);
  return `${d} ${MON[m - 1]}`;
};
const pct = (a: number, b: number) => (b ? Math.round((a / b) * 100) : 0);

/** Event days from eventDate to eventEndDate (India time). */
function eventDays(event: any): string[] {
  if (!event?.eventDate) return [];
  const out: string[] = [];
  let cur = new Date(`${istDay(event.eventDate)}T00:00:00Z`);
  const end = new Date(`${istDay(event.eventEndDate || event.eventDate)}T00:00:00Z`);
  while (cur <= end && out.length < 60) {
    out.push(cur.toISOString().slice(0, 10));
    cur = new Date(cur.getTime() + 86400000);
  }
  return out;
}

type Scope = "today" | "yesterday" | "all" | string; // or a YYYY-MM-DD event day

function Stat({ icon, color, title, value, sub }: { icon: string; color: string; title: string; value: number | string; sub?: string }) {
  return (
    <div className="card p-4">
      <div className="flex items-center gap-2 text-xs font-medium text-muted">
        <span className="flex h-7 w-7 items-center justify-center rounded-lg" style={{ background: `${color}22` }}>
          <Icon name={icon} size={16} color={color} />
        </span>
        {title}
      </div>
      <div className="mt-2 text-2xl font-bold">{value}</div>
      {sub && <div className="mt-0.5 text-xs text-muted">{sub}</div>}
    </div>
  );
}

/** Event → Analytics: entry / exit scans and inclusion claims for today, yesterday, each event day or all days. */
export default function EventAnalytics({
  event,
  registrations,
  onRefresh,
}: {
  event: any;
  registrations: any[] | null;
  onRefresh: () => void;
}) {
  const [scope, setScope] = useState<Scope>("today");
  const today = istDay(new Date());
  const yesterday = istDay(Date.now() - 86400000);
  const days = useMemo(() => eventDays(event), [event]);
  const regs = useMemo(() => (registrations ?? []).filter((r) => r.status !== "cancelled"), [registrations]);
  const packages: any[] = event?.packages ?? [];
  const pkgOf = (r: any) =>
    packages.find((p) => (r.packageId && p.id === r.packageId) || (!r.packageId && r.packageName === p.name));
  const allAccess = (r: any) =>
    ["Admin", "Speaker", "Event Staff"].includes(r.participantType) || r.packageId === "vip-all-access";

  // The selected day ("all" = every day).
  const day = scope === "today" ? today : scope === "yesterday" ? yesterday : scope;
  const inScope = (d: string) => day === "all" || d === day;
  const scopeLabel = scope === "today" ? "today" : scope === "yesterday" ? "yesterday" : scope === "all" ? "all days" : label(day);

  // Days a participant may be scanned in (their package's entry/exit dates, else every event day).
  const allowedDays = (r: any): string[] => {
    const p = pkgOf(r);
    return p && Array.isArray(p.entryExitDates) && p.entryExitDates.length ? p.entryExitDates : days;
  };

  const a = useMemo(() => {
    let entries = 0, exits = 0, inside = 0, claims = 0, reclaimed = 0, eligible = 0;
    const entered = new Set<string>();
    const hourly = new Array(24).fill(0);
    const byInclusion = new Map<string, { claimed: number; eligible: number }>();
    const byPackage = new Map<string, { name: string; registered: number; entered: number; exited: number; claims: number }>();
    const byDay = new Map<string, { entries: number; exits: number; claims: number }>(days.map((d) => [d, { entries: 0, exits: 0, claims: 0 }]));
    let certificates = 0;

    for (const r of regs) {
      const p = pkgOf(r);
      const pkgKey = p ? p.id : "__other";
      if (!byPackage.has(pkgKey)) byPackage.set(pkgKey, { name: p ? p.name : "Other passes", registered: 0, entered: 0, exited: 0, claims: 0 });
      const bp = byPackage.get(pkgKey)!;
      bp.registered++;
      const att: any[] = Array.isArray(r.attendance) ? r.attendance : [];
      const allowed = allowedDays(r);
      if (day === "all" ? allowed.length > 0 : allAccess(r) || allowed.includes(day)) eligible++;
      let didEnter = false, didExit = false;
      for (const x of att) {
        if (!byDay.has(x.day)) byDay.set(x.day, { entries: 0, exits: 0, claims: 0 });
        if (x.entryAt) byDay.get(x.day)!.entries++;
        if (x.exitAt) byDay.get(x.day)!.exits++;
        if (!inScope(x.day)) continue;
        if (x.entryAt) {
          entries++;
          didEnter = true;
          hourly[istHour(x.entryAt)]++;
        }
        if (x.exitAt) {
          exits++;
          didExit = true;
        }
        if (x.entryAt && !x.exitAt) inside++;
      }
      if (didEnter) {
        entered.add(r.id ?? r._id);
        bp.entered++;
      }
      if (didExit) bp.exited++;
      const done = allowed.length > 0 && allowed.every((d) => att.some((x) => x.day === d && x.entryAt && x.exitAt));
      if (done) certificates++;

      // Inclusion claims.
      for (const c of r.claimedInclusions ?? []) {
        const d = istDay(c.claimedAt);
        if (!byDay.has(d)) byDay.set(d, { entries: 0, exits: 0, claims: 0 });
        byDay.get(d)!.claims++;
        if (!inScope(d)) continue;
        claims++;
        bp.claims++;
        if (c.reclaimedByAdmin) reclaimed++;
        const k = String(c.inclusionName).trim();
        if (!byInclusion.has(k)) byInclusion.set(k, { claimed: 0, eligible: 0 });
        byInclusion.get(k)!.claimed++;
      }
      // Who could claim each inclusion in this scope.
      if (p) {
        for (const inc of normalizeInclusions(p.inclusions)) {
          const incDays = inc.dates;
          const n = day === "all" ? incDays.length : incDays.includes(day) ? 1 : 0;
          if (!n) continue;
          if (!byInclusion.has(inc.name)) byInclusion.set(inc.name, { claimed: 0, eligible: 0 });
          byInclusion.get(inc.name)!.eligible += n;
        }
      }
    }
    return {
      entries, exits, inside, claims, reclaimed, eligible, hourly, certificates,
      people: entered.size,
      notEntered: Math.max(0, eligible - entered.size),
      byInclusion: [...byInclusion.entries()].sort((x, y) => y[1].claimed - x[1].claimed),
      byPackage: [...byPackage.values()].sort((x, y) => y.registered - x.registered),
      byDay: [...byDay.entries()].sort(([x], [y]) => x.localeCompare(y)),
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [regs, day, days, packages]);

  // Same numbers for yesterday, to compare against when viewing today.
  const prev = useMemo(() => {
    if (scope !== "today") return null;
    let entries = 0, claims = 0;
    for (const r of regs) {
      for (const x of r.attendance ?? []) if (x.day === yesterday && x.entryAt) entries++;
      for (const c of r.claimedInclusions ?? []) if (istDay(c.claimedAt) === yesterday) claims++;
    }
    return { entries, claims };
  }, [regs, scope, yesterday]);
  const vs = (n: number, was?: number) => (was === undefined ? undefined : `${n - was >= 0 ? "+" : ""}${n - was} vs yesterday (${was})`);

  if (!registrations) return <div className="card p-10 text-center text-muted">Loading…</div>;

  const chip = (value: Scope, text: string) => (
    <button
      key={value}
      onClick={() => setScope(value)}
      className={`rounded-full border px-3.5 py-1.5 text-sm font-medium transition ${
        scope === value ? "border-accent bg-accent text-white" : "border-line text-white/70 hover:bg-white/5"
      }`}
    >
      {text}
    </button>
  );
  const maxHour = Math.max(1, ...a.hourly);
  const firstHour = Math.min(7, ...a.hourly.map((n, h) => (n ? h : 24)));
  const lastHour = Math.max(20, ...a.hourly.map((n, h) => (n ? h : -1)));

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-center gap-2">
        {chip("today", "Today")}
        {chip("yesterday", "Yesterday")}
        {days.map((d, i) => chip(d, `Day ${i + 1} · ${label(d)}`))}
        {chip("all", "All days")}
        <span className="flex-1" />
        <Button variant="outline" icon="refresh" small onClick={onRefresh}>
          Refresh
        </Button>
      </div>

      <div className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-6">
        <Stat icon="groups" color="#3B82F6" title="Registered" value={regs.length} sub={`${a.eligible} allowed ${scopeLabel}`} />
        <Stat icon="login" color="#22C55E" title={`Entries · ${scopeLabel}`} value={a.entries} sub={vs(a.entries, prev?.entries) ?? `${a.people} people`} />
        <Stat icon="logout" color="#EF4444" title={`Exits · ${scopeLabel}`} value={a.exits} />
        <Stat icon="meeting_room" color="#F59E0B" title={day === today ? "Inside now" : "Entered, no exit"} value={a.inside} />
        <Stat icon="person_off" color="#94A3B8" title={`Not entered · ${scopeLabel}`} value={a.notEntered} />
        <Stat icon="redeem" color="#8B5CF6" title={`Inclusion claims · ${scopeLabel}`} value={a.claims} sub={vs(a.claims, prev?.claims) ?? (a.reclaimed ? `${a.reclaimed} re-registered by admin` : undefined)} />
      </div>

      <div className="grid gap-5 lg:grid-cols-2">
        <div className="card p-5">
          <div className="mb-3 flex items-center gap-2 font-semibold">
            <Icon name="redeem" size={19} color="#8B5CF6" /> Inclusion claims · {scopeLabel}
          </div>
          {a.byInclusion.length === 0 ? (
            <div className="py-6 text-center text-sm text-muted">No inclusions on this day</div>
          ) : (
            <div className="space-y-3">
              {a.byInclusion.map(([name, v]) => (
                <div key={name}>
                  <div className="flex text-sm">
                    <span className="flex-1 truncate font-medium">{name}</span>
                    <span className="text-muted">
                      <b className="text-white">{v.claimed}</b>
                      {v.eligible ? ` / ${v.eligible} · ${pct(v.claimed, v.eligible)}%` : ""}
                    </span>
                  </div>
                  <div className="mt-1.5 h-2 overflow-hidden rounded bg-white/[0.07]">
                    <div className="h-full rounded bg-[#8B5CF6]" style={{ width: `${Math.min(100, pct(v.claimed, v.eligible || v.claimed || 1))}%` }} />
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="card p-5">
          <div className="mb-3 flex items-center gap-2 font-semibold">
            <Icon name="schedule" size={19} color="#22C55E" /> Entries by hour · {scopeLabel}
          </div>
          {a.entries === 0 ? (
            <div className="py-6 text-center text-sm text-muted">No entry scans</div>
          ) : (
            <div className="flex h-40 items-end gap-1">
              {a.hourly.slice(firstHour, lastHour + 1).map((n, i) => {
                const h = firstHour + i;
                return (
                  <div key={h} className="flex flex-1 flex-col items-center gap-1" title={`${h}:00 – ${n} entries`}>
                    <span className="text-[10px] text-muted">{n || ""}</span>
                    <div className="w-full rounded-t bg-[#22C55E]" style={{ height: `${(n / maxHour) * 110}px`, minHeight: n ? 3 : 0 }} />
                    <span className="text-[10px] text-muted">{h % 12 || 12}{h < 12 ? "a" : "p"}</span>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>

      <div className="card overflow-hidden">
        <div className="flex items-center gap-2 border-b border-line px-5 py-3.5 font-semibold">
          <Icon name="inventory_2" size={19} color="#3B82F6" /> By package · {scopeLabel}
        </div>
        <table className="w-full text-sm">
          <thead className="text-left text-xs uppercase tracking-wide text-muted">
            <tr className="border-b border-line">
              <th className="px-5 py-2.5 font-semibold">Package</th>
              <th className="px-3 py-2.5 text-right font-semibold">Registered</th>
              <th className="px-3 py-2.5 text-right font-semibold">Entered</th>
              <th className="px-3 py-2.5 text-right font-semibold">Exited</th>
              <th className="px-5 py-2.5 text-right font-semibold">Inclusion claims</th>
            </tr>
          </thead>
          <tbody>
            {a.byPackage.map((p) => (
              <tr key={p.name} className="border-b border-line last:border-0">
                <td className="px-5 py-2.5 font-medium">{p.name}</td>
                <td className="px-3 py-2.5 text-right">{p.registered}</td>
                <td className="px-3 py-2.5 text-right">
                  {p.entered} <span className="text-xs text-muted">({pct(p.entered, p.registered)}%)</span>
                </td>
                <td className="px-3 py-2.5 text-right">{p.exited}</td>
                <td className="px-5 py-2.5 text-right">{p.claims}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="grid gap-5 lg:grid-cols-3">
        <div className="card overflow-hidden lg:col-span-2">
          <div className="flex items-center gap-2 border-b border-line px-5 py-3.5 font-semibold">
            <Icon name="calendar_month" size={19} color="#F59E0B" /> Day by day
          </div>
          {a.byDay.length === 0 ? (
            <div className="py-6 text-center text-sm text-muted">Event dates are not set</div>
          ) : (
            <table className="w-full text-sm">
              <thead className="text-left text-xs uppercase tracking-wide text-muted">
                <tr className="border-b border-line">
                  <th className="px-5 py-2.5 font-semibold">Day</th>
                  <th className="px-3 py-2.5 text-right font-semibold">Entries</th>
                  <th className="px-3 py-2.5 text-right font-semibold">Exits</th>
                  <th className="px-5 py-2.5 text-right font-semibold">Inclusion claims</th>
                </tr>
              </thead>
              <tbody>
                {a.byDay.map(([d, v]) => {
                  const n = days.indexOf(d);
                  return (
                    <tr key={d} className={`border-b border-line last:border-0 ${d === today ? "bg-accent/[0.07]" : ""}`}>
                      <td className="px-5 py-2.5 font-medium">
                        {n >= 0 ? `Day ${n + 1} · ` : ""}
                        {label(d)}
                        {d === today && <span className="ml-2 text-xs text-[#60A5FA]">Today</span>}
                        {n < 0 && <span className="ml-2 text-xs text-muted">outside event dates</span>}
                      </td>
                      <td className="px-3 py-2.5 text-right">{v.entries}</td>
                      <td className="px-3 py-2.5 text-right">{v.exits}</td>
                      <td className="px-5 py-2.5 text-right">{v.claims}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </div>
        <Stat
          icon="workspace_premium"
          color="#14B8A6"
          title="Attendance complete (all days)"
          value={a.certificates}
          sub={`of ${regs.length} · entry and exit on every allowed day`}
        />
      </div>
    </div>
  );
}
