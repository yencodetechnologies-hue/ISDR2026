/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useParams } from "react-router-dom";
import { Button, Icon, Loading, Page, useToast } from "@/components/ui";
import { get } from "@/lib/api";
import { exportWorkbook, type ExportColumn } from "@/lib/exporter";

const MON = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const PAGE_SIZE = 40;

type IncFact = { name: string; eligible: boolean; claimedAt: string | null };
type DayFact = {
  day: string;
  entryEligible: boolean;
  entryAt: string | null;
  exitEligible: boolean;
  exitAt: string | null;
  inclusions: IncFact[];
};
type ReportRow = {
  id: string;
  idNumber: string;
  name: string;
  packageName: string;
  participantType: string;
  days: DayFact[];
};
type ScanReport = { title: string; days: string[]; inclusions: string[]; rows: ReportRow[] };

type Line = {
  id: string;
  day: string;
  idNumber: string;
  name: string;
  packageName: string;
  participantType: string;
  scanned: boolean;
  at: string | null;
};

const istToday = () => new Date().toLocaleDateString("en-CA", { timeZone: "Asia/Kolkata" });

function dayLabel(day: string, days: string[]) {
  const [, m, d] = day.split("-").map(Number);
  const n = days.indexOf(day);
  const text = `${d} ${MON[(m || 1) - 1] || ""}`.trim();
  return n >= 0 ? `Day ${n + 1} · ${text}` : text;
}

function scanTime(iso: string | null) {
  if (!iso) return "";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  return d.toLocaleString("en-IN", {
    timeZone: "Asia/Kolkata",
    day: "numeric",
    month: "short",
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  });
}

function linesOf(report: ScanReport, section: string, scope: string): Line[] {
  const out: Line[] = [];
  for (const row of report.rows) {
    for (const day of row.days) {
      if (scope !== "all" && day.day !== scope) continue;
      const base = {
        id: row.id,
        day: day.day,
        idNumber: row.idNumber,
        name: row.name,
        packageName: row.packageName,
        participantType: row.participantType,
      };
      if (section === "entry") {
        if (!day.entryEligible) continue;
        out.push({ ...base, scanned: !!day.entryAt, at: day.entryAt });
      } else if (section === "exit") {
        if (!day.exitEligible) continue;
        out.push({ ...base, scanned: !!day.exitAt, at: day.exitAt });
      } else {
        const inc = day.inclusions.find((i) => i.name === section);
        if (!inc?.eligible) continue;
        out.push({ ...base, scanned: !!inc.claimedAt, at: inc.claimedAt });
      }
    }
  }
  out.sort(
    (a, b) =>
      a.day.localeCompare(b.day) ||
      Number(b.scanned) - Number(a.scanned) ||
      String(a.idNumber).localeCompare(String(b.idNumber)) ||
      a.name.localeCompare(b.name),
  );
  return out;
}

function tally(report: ScanReport, section: string, scope: string) {
  const lines = linesOf(report, section, scope);
  const scanned = lines.filter((l) => l.scanned).length;
  const people = new Set(lines.filter((l) => l.scanned).map((l) => l.id)).size;
  return { scanned, eligible: lines.length, notScanned: lines.length - scanned, people };
}

function sectionMeta(section: string) {
  if (section === "entry") return { title: "Entry", done: "Entered", pending: "Not entered", total: "Total entered", time: "Entry time" };
  if (section === "exit") return { title: "Exit", done: "Exited", pending: "Not exited", total: "Total exited", time: "Exit time" };
  return {
    title: section,
    done: "Claimed",
    pending: "Not claimed",
    total: `Total ${section.toLowerCase()}`,
    time: "Claimed at",
  };
}

function summaryRows(report: ScanReport) {
  const rows = report.days.map((day) => {
    const entry = tally(report, "entry", day);
    const exit = tally(report, "exit", day);
    const inc: Record<string, { scanned: number; eligible: number }> = {};
    for (const name of report.inclusions) {
      const t = tally(report, name, day);
      inc[name] = { scanned: t.scanned, eligible: t.eligible };
    }
    return { label: dayLabel(day, report.days), entries: entry.scanned, entryEligible: entry.eligible, exits: exit.scanned, exitEligible: exit.eligible, inc };
  });
  const total = {
    label: "Total",
    entries: rows.reduce((n, r) => n + r.entries, 0),
    entryEligible: rows.reduce((n, r) => n + r.entryEligible, 0),
    exits: rows.reduce((n, r) => n + r.exits, 0),
    exitEligible: rows.reduce((n, r) => n + r.exitEligible, 0),
    inc: Object.fromEntries(
      report.inclusions.map((name) => [
        name,
        {
          scanned: rows.reduce((n, r) => n + (r.inc[name]?.scanned ?? 0), 0),
          eligible: rows.reduce((n, r) => n + (r.inc[name]?.eligible ?? 0), 0),
        },
      ]),
    ),
  };
  return [...rows, total];
}

async function downloadReport(report: ScanReport) {
  const personCols = (status: string, time: string): ExportColumn<Line>[] => [
    { header: "Day", value: (r) => dayLabel(r.day, report.days), width: 18 },
    { header: "ID no.", value: (r) => r.idNumber, width: 12 },
    { header: "Name", value: (r) => r.name, width: 26 },
    { header: "Package", value: (r) => r.packageName, width: 18 },
    { header: "Participant type", value: (r) => r.participantType, width: 16 },
    { header: status, value: (r) => (r.scanned ? "Yes" : "No"), width: 12 },
    { header: time, value: (r) => scanTime(r.at), width: 20 },
  ];
  const summary = summaryRows(report);
  const summaryCols: ExportColumn<(typeof summary)[number]>[] = [
    { header: "Day", value: (r) => r.label, width: 18 },
    { header: "Entries", value: (r) => r.entries, width: 12 },
    { header: "Eligible for entry", value: (r) => r.entryEligible, width: 18 },
    { header: "Exits", value: (r) => r.exits, width: 12 },
    { header: "Eligible for exit", value: (r) => r.exitEligible, width: 18 },
    ...report.inclusions.flatMap((name) => [
      { header: `${name} claimed`, value: (r: (typeof summary)[number]) => r.inc[name]?.scanned ?? 0, width: 16 },
      { header: `${name} eligible`, value: (r: (typeof summary)[number]) => r.inc[name]?.eligible ?? 0, width: 16 },
    ]),
  ];
  const entry = sectionMeta("entry");
  const exit = sectionMeta("exit");
  await exportWorkbook(`${report.title} - Report`, [
    { name: "Summary", columns: summaryCols, rows: summary },
    { name: "Entry", columns: personCols(entry.done, entry.time), rows: linesOf(report, "entry", "all") },
    { name: "Exit", columns: personCols(exit.done, exit.time), rows: linesOf(report, "exit", "all") },
    ...report.inclusions.map((name) => {
      const meta = sectionMeta(name);
      return { name, columns: personCols(meta.done, meta.time), rows: linesOf(report, name, "all") };
    }),
  ]);
}

function Stat({
  icon,
  color,
  title,
  value,
  sub,
  active,
  onClick,
}: {
  icon: string;
  color: string;
  title: string;
  value: number;
  sub: string;
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`card p-4 text-left transition ${active ? "ring-2 ring-accent" : "hover:bg-white/[0.03]"}`}
    >
      <div className="flex items-center gap-2 text-xs font-medium text-muted">
        <span className="flex h-7 w-7 items-center justify-center rounded-lg" style={{ background: `${color}22` }}>
          <Icon name={icon} size={16} color={color} />
        </span>
        <span className="truncate">{title}</span>
      </div>
      <div className="mt-2 text-2xl font-bold">{value}</div>
      <div className="mt-0.5 text-xs text-muted">{sub}</div>
    </button>
  );
}

/** Day-wise entry, exit, and inclusion report. Polls so new scans show up on their own. */
export function EventReport({ eventId }: { eventId: string }) {
  const toast = useToast();
  const [report, setReport] = useState<ScanReport | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [scope, setScope] = useState("all");
  const [section, setSection] = useState("entry");
  const [page, setPage] = useState(1);
  const [downloading, setDownloading] = useState(false);
  const gen = useRef(0);
  const choseScope = useRef(false);
  const today = istToday();

  const load = useCallback(
    async (silent = false) => {
      const n = ++gen.current;
      if (!silent) setLoading(true);
      try {
        const res = await get(`/managed-events/${eventId}/scan-report`);
        if (n !== gen.current) return;
        if (!res.success) {
          if (!silent) setError(res.error || "Could not load the report");
          return;
        }
        setError(null);
        setReport(res.report ?? { title: "Event", days: [], inclusions: [], rows: [] });
      } finally {
        if (n === gen.current) setLoading(false);
      }
    },
    [eventId],
  );

  useEffect(() => {
    load();
  }, [load]);
  useEffect(() => {
    const t = setInterval(() => load(true), 8000);
    return () => clearInterval(t);
  }, [load]);

  useEffect(() => {
    if (!report || choseScope.current) return;
    if (report.days.includes(today)) setScope(today);
  }, [report, today]);

  const sections = useMemo(() => ["entry", "exit", ...(report?.inclusions ?? [])], [report]);
  useEffect(() => {
    if (!sections.includes(section)) setSection("entry");
  }, [sections, section]);

  const lines = useMemo(() => (report ? linesOf(report, section, scope) : []), [report, section, scope]);
  const cardStats = useMemo(() => {
    if (!report) return null;
    return {
      entry: tally(report, "entry", scope),
      exit: tally(report, "exit", scope),
      inclusions: report.inclusions.map((name) => ({ name, stat: tally(report, name, scope) })),
    };
  }, [report, scope]);
  const counts =
    section === "entry"
      ? cardStats?.entry ?? null
      : section === "exit"
        ? cardStats?.exit ?? null
        : cardStats?.inclusions.find((i) => i.name === section)?.stat ?? null;
  const pages = Math.max(1, Math.ceil(lines.length / PAGE_SIZE));
  const safePage = Math.min(page, pages);
  const shown = lines.slice((safePage - 1) * PAGE_SIZE, safePage * PAGE_SIZE);
  const meta = sectionMeta(section);
  const scopeLabel = scope === "all" ? "all days" : report ? dayLabel(scope, report.days) : scope;

  const pickScope = (value: string) => {
    choseScope.current = true;
    setScope(value);
    setPage(1);
  };
  const pickSection = (value: string) => {
    setSection(value);
    setPage(1);
  };

  const download = async () => {
    if (!report) return;
    setDownloading(true);
    try {
      await downloadReport(report);
    } catch (e) {
      toast(e instanceof Error ? e.message : "Could not download the report", "error");
    } finally {
      setDownloading(false);
    }
  };

  if (loading && !report) return <Loading label="Loading report…" />;
  if (error && !report) {
    return (
      <div className="card p-8 text-center">
        <div className="text-sm text-white/80">{error}</div>
        <Button className="mt-4" variant="outline" icon="refresh" onClick={() => load()}>
          Retry
        </Button>
      </div>
    );
  }
  if (!report) return null;

  const chip = (value: string, text: string, on: boolean, pick: () => void) => (
    <button
      key={value}
      type="button"
      onClick={pick}
      className={`rounded-full border px-3.5 py-1.5 text-sm font-medium transition ${
        on ? "border-accent bg-accent text-white" : "border-line text-white/70 hover:bg-white/5"
      }`}
    >
      {text}
    </button>
  );

  const cardSub = (t: { scanned: number; eligible: number; notScanned: number; people: number }) =>
    scope === "all" && t.people !== t.scanned ? `${t.people} people · ${t.notScanned} not scanned` : `${t.notScanned} not scanned of ${t.eligible}`;

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-center gap-2">
        {report.days.map((d) => chip(d, dayLabel(d, report.days), scope === d, () => pickScope(d)))}
        {chip("all", "All days", scope === "all", () => pickScope("all"))}
        <span className="flex-1" />
        <Button variant="outline" icon="refresh" small onClick={() => load()}>
          Refresh
        </Button>
        <Button variant="outline" icon="download" small loading={downloading} disabled={!report} onClick={download}>
          Download Excel
        </Button>
      </div>

      <div className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-4">
        {cardStats && (
          <Stat
            icon="login"
            color="#22C55E"
            title="Total entered"
            value={cardStats.entry.scanned}
            sub={cardSub(cardStats.entry)}
            active={section === "entry"}
            onClick={() => pickSection("entry")}
          />
        )}
        {cardStats && (
          <Stat
            icon="logout"
            color="#EF4444"
            title="Total exited"
            value={cardStats.exit.scanned}
            sub={cardSub(cardStats.exit)}
            active={section === "exit"}
            onClick={() => pickSection("exit")}
          />
        )}
        {cardStats?.inclusions.map(({ name, stat }) => (
          <Stat
            key={name}
            icon="redeem"
            color="#8B5CF6"
            title={sectionMeta(name).total}
            value={stat.scanned}
            sub={cardSub(stat)}
            active={section === name}
            onClick={() => pickSection(name)}
          />
        ))}
      </div>

      <div className="flex flex-wrap gap-2">
        {chip("entry", "Entry", section === "entry", () => pickSection("entry"))}
        {chip("exit", "Exit", section === "exit", () => pickSection("exit"))}
        {report.inclusions.map((name) => chip(name, name, section === name, () => pickSection(name)))}
      </div>

      <div className="card overflow-hidden">
        <div className="flex flex-wrap items-center gap-2 border-b border-line px-5 py-3.5">
          <div className="font-semibold">
            {meta.title} · {scopeLabel}
          </div>
          <span className="text-sm text-muted">
            {counts?.scanned ?? 0} scanned · {counts?.eligible ?? 0} eligible · {counts?.notScanned ?? 0} not scanned
          </span>
        </div>
        {report.days.length === 0 ? (
          <div className="py-8 text-center text-sm text-muted">Event dates are not set</div>
        ) : lines.length === 0 ? (
          <div className="py-8 text-center text-sm text-muted">No one is eligible for this report on {scopeLabel}</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="text-left text-xs uppercase tracking-wide text-muted">
                <tr className="border-b border-line">
                  {scope === "all" && <th className="px-5 py-2.5 font-semibold">Day</th>}
                  <th className="px-5 py-2.5 font-semibold">ID no.</th>
                  <th className="px-3 py-2.5 font-semibold">Name</th>
                  <th className="px-3 py-2.5 font-semibold">Package</th>
                  <th className="px-3 py-2.5 font-semibold">Type</th>
                  <th className="px-3 py-2.5 font-semibold">Status</th>
                  <th className="px-5 py-2.5 font-semibold">Time</th>
                </tr>
              </thead>
              <tbody>
                {shown.map((line) => (
                  <tr key={`${line.id}|${line.day}`} className="border-b border-line last:border-0">
                    {scope === "all" && <td className="px-5 py-2.5 font-medium">{dayLabel(line.day, report.days)}</td>}
                    <td className="px-5 py-2.5">{line.idNumber || "—"}</td>
                    <td className="px-3 py-2.5 font-medium">{line.name || "—"}</td>
                    <td className="px-3 py-2.5">{line.packageName || "—"}</td>
                    <td className="px-3 py-2.5">{line.participantType || "—"}</td>
                    <td className="px-3 py-2.5" style={{ color: line.scanned ? "#86EFAC" : "#FCD34D" }}>
                      {line.scanned ? meta.done : meta.pending}
                    </td>
                    <td className="px-5 py-2.5 text-muted">{scanTime(line.at) || "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        <div className="flex flex-wrap items-center gap-3 border-t border-line px-5 py-3 text-sm">
          <span className="font-semibold">{meta.total}</span>
          <span className="text-muted">
            {counts?.scanned ?? 0} scanned · {counts?.eligible ?? 0} eligible · {counts?.notScanned ?? 0} not scanned
            {scope === "all" && counts && counts.people !== counts.scanned ? ` · ${counts.people} people` : ""}
          </span>
          <span className="flex-1" />
          {lines.length > PAGE_SIZE && (
            <span className="flex items-center gap-2">
              <span className="text-muted">
                {(safePage - 1) * PAGE_SIZE + 1}–{Math.min(safePage * PAGE_SIZE, lines.length)} of {lines.length}
              </span>
              <Button variant="outline" small disabled={safePage <= 1} onClick={() => setPage(safePage - 1)}>
                Prev
              </Button>
              <Button variant="outline" small disabled={safePage >= pages} onClick={() => setPage(safePage + 1)}>
                Next
              </Button>
            </span>
          )}
        </div>
      </div>
    </div>
  );
}

export default function EventReportPage() {
  const { id = "" } = useParams<{ id: string }>();
  return (
    <Page title="Report" subtitle="Day-wise entry, exit and inclusion scans" width={1200}>
      <EventReport eventId={id} />
    </Page>
  );
}
