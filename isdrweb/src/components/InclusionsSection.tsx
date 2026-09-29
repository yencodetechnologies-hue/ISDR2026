/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { get } from "@/lib/api";
import { fmtShortDateTime, isoDay, monthShort, parseDate, weekdayLong } from "@/lib/format";
import { daysOfEvent } from "@/lib/schedules";
import { Icon, Spinner } from "./ui";

type DayInclusion = { name: string; claimedAt: Date | null; byAdmin: boolean };

/** Calendar day (YYYY-MM-DD) of an instant in India time. */
export function istDay(d: Date) {
  const ist = new Date(d.getTime() + 330 * 60000);
  return `${ist.getUTCFullYear()}-${String(ist.getUTCMonth() + 1).padStart(2, "0")}-${String(ist.getUTCDate()).padStart(2, "0")}`;
}

/** The participant's package inclusions per event day, with what they've claimed. */
export default function InclusionsSection({ showHeader = true }: { showHeader?: boolean }) {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [pkg, setPkg] = useState("");
  const [days, setDays] = useState<{ iso: string | null; items: DayInclusion[] }[]>([]);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    const res = await get("/managed-events/my-registration");
    if (!res.success) {
      setLoading(false);
      return setError(res.error || "Failed to load inclusions");
    }
    const reg = res.registration ?? {};
    const inclusions: any[] = res.availableInclusions ?? [];
    const claims: any[] = reg.claimedInclusions ?? [];
    const ev = reg.eventId ? await get(`/managed-events/${reg.eventId}`) : { success: false };
    const event = ev.success ? (ev as any).event : {};
    const key = (s: any) =>
      String(s ?? "")
        .trim()
        .toLowerCase();
    const claimOn = (name: string, iso: string | null): DayInclusion => {
      for (const c of claims) {
        if (key(c.inclusionName) !== key(name)) continue;
        const at = parseDate(c.claimedAt);
        if (!at) continue;
        if (iso === null || istDay(at) === iso) return { name, claimedAt: at, byAdmin: c.reclaimedByAdmin === true };
      }
      return { name, claimedAt: null, byAdmin: false };
    };
    const evDays = daysOfEvent(event).map(isoDay);
    const out: { iso: string | null; items: DayInclusion[] }[] = [];
    if (!evDays.length) out.push({ iso: null, items: inclusions.map((i) => claimOn(String(i.name ?? ""), null)) });
    else
      for (const iso of evDays) {
        const items = inclusions
          .filter((i) => {
            const dates: string[] = (i.dates ?? []).map(String);
            return !dates.length || dates.includes(iso);
          })
          .map((i) => claimOn(String(i.name ?? ""), iso));
        if (items.length) out.push({ iso, items });
      }
    setPkg(String(reg.packageName ?? ""));
    setDays(out);
    setLoading(false);
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const today = isoDay(new Date());
  const heading = (iso: string) => {
    const [y, m, d] = iso.split("-").map(Number);
    const dt = new Date(y, m - 1, d);
    return `${weekdayLong(dt)}, ${d} ${monthShort(dt)}${iso === today ? "  ·  Today" : ""}`;
  };
  const empty = !days.length || days.every((d) => !d.items.length);

  return (
    <div>
      {showHeader && (
        <div className="mb-5 flex items-center gap-2.5">
          <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-accent/15">
            <Icon name="card_giftcard" size={19} color="#3B82F6" />
          </span>
          <span className="flex-1 text-lg font-semibold">Package Inclusions</span>
          {pkg && (
            <span className="rounded-full border border-accent/30 bg-accent/10 px-2.5 py-1 text-[11px] font-bold text-accent">
              {pkg}
            </span>
          )}
        </div>
      )}
      {loading ? (
        <div className="flex justify-center py-9">
          <Spinner />
        </div>
      ) : error || empty ? (
        <div className="flex flex-col items-center rounded-lg border border-dashed border-white/10 px-4 py-8 text-center">
          <Icon name="card_giftcard" size={32} color="#6B7280" />
          <div className="mt-2 text-sm font-semibold text-white/70">{error ?? "No inclusions in your package"}</div>
          {error && (
            <button onClick={load} className="mt-2 flex items-center gap-1 text-xs font-semibold text-accent">
              <Icon name="refresh" size={15} />
              Tap to retry
            </button>
          )}
        </div>
      ) : (
        days.map((d, i) => (
          <div key={d.iso ?? i}>
            {d.iso && <div className={`eyebrow mb-2.5 ${i ? "mt-5" : ""}`}>{heading(d.iso)}</div>}
            <div className="grid gap-2.5 sm:grid-cols-2">
              {d.items.map((it) => (
                <div
                  key={it.name}
                  className="flex items-center gap-3 rounded-lg border p-3"
                  style={{
                    borderColor: it.claimedAt ? "rgba(34,197,94,0.3)" : "rgba(255,255,255,0.08)",
                    background: it.claimedAt ? "rgba(34,197,94,0.06)" : "rgba(255,255,255,0.02)",
                  }}
                >
                  <span
                    className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg"
                    style={{ background: it.claimedAt ? "rgba(34,197,94,0.15)" : "rgba(59,130,246,0.15)" }}
                  >
                    <Icon
                      name={it.claimedAt ? "check_circle" : "redeem"}
                      size={20}
                      color={it.claimedAt ? "#22C55E" : "#60A5FA"}
                    />
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block text-sm font-bold">{it.name}</span>
                    <span className="block text-xs text-muted">
                      {it.claimedAt
                        ? `${it.byAdmin ? "Claimed by admin" : "Claimed"} at ${fmtShortDateTime(it.claimedAt)}`
                        : "Not claimed yet"}
                    </span>
                  </span>
                  <span
                    className="whitespace-pre rounded-lg px-2 py-1 text-center text-[10px] font-extrabold"
                    style={
                      it.claimedAt
                        ? { background: "rgba(34,197,94,0.15)", color: "#22C55E" }
                        : { background: "rgba(59,130,246,0.15)", color: "#60A5FA" }
                    }
                  >
                    {it.claimedAt ? (it.byAdmin ? "CLAIMED\nBY ADMIN" : "CLAIMED") : "Available"}
                  </span>
                </div>
              ))}
            </div>
          </div>
        ))
      )}
    </div>
  );
}
