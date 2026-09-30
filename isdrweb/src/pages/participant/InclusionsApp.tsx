/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { AppBar, Icon } from "@/components/ui";
import { AppSpinner } from "@/components/app/AppControls";
import { get } from "@/lib/api";
import { fmtShortDateTime, parseDate } from "@/lib/format";

export function AvailableInclusionsApp() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [packageName, setPackageName] = useState("");
  const [unclaimed, setUnclaimed] = useState<any[]>([]);

  const load = useCallback(async (silent = false) => {
    if (!silent) {
      setLoading(true);
      setError(null);
    }
    const res = await get("/managed-events/my-registration");
    if (!res.success) {
      if (silent) return;
      setLoading(false);
      return setError(res.error || "Failed to load inclusions");
    }
    const reg = res.registration ?? {};
    const inclusions: any[] = res.availableInclusions ?? [];
    const claims: any[] = reg.claimedInclusions ?? [];
    const claimedKeys = new Set(
      claims.map((c) => String(c.inclusionName ?? "").trim().toLowerCase())
    );

    const left = inclusions.filter(
      (i) => !claimedKeys.has(String(i.name ?? "").trim().toLowerCase())
    );

    setPackageName(String(reg.packageName ?? ""));
    setUnclaimed(left);
    setError(null);
    setLoading(false);
  }, []);

  useEffect(() => {
    load();
    const t = setInterval(() => load(true), 4000);
    return () => clearInterval(t);
  }, [load]);

  return (
    <div className="min-h-screen bg-[#0A0A12] text-white">
      <AppBar title="Available Inclusions" outfit titleClassName="!text-left font-outfit text-[18px] font-bold" />
      <div className="px-4 pb-12 pt-3">
        {loading ? (
          <div className="py-24">
            <AppSpinner />
          </div>
        ) : error ? (
          <div className="flex flex-col items-center justify-center py-28 text-center">
            <Icon name="error_outline" size={40} color="#9CA3AF" />
            <div className="mt-3 font-inter text-sm text-muted">{error}</div>
          </div>
        ) : unclaimed.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-28 text-center">
            <Icon name="inventory_2" size={44} color="#9CA3AF" />
            <div className="mt-3 font-outfit text-[16px] font-bold">All inclusions have been claimed</div>
            <div className="mt-1 font-inter text-xs text-muted">You have claimed all items in your package.</div>
          </div>
        ) : (
          <div>
            {packageName && (
              <div className="mb-4">
                <div className="font-inter text-[11px] font-bold tracking-[0.6px] text-muted">PACKAGE</div>
                <div className="mt-0.5 font-outfit text-[17px] font-bold text-white">{packageName}</div>
              </div>
            )}
            <div className="mb-2 font-inter text-[11px] font-bold tracking-[0.6px] text-muted">
              AVAILABLE ({unclaimed.length})
            </div>
            <div className="space-y-2.5">
              {unclaimed.map((incl, i) => (
                <div
                  key={incl.name || i}
                  className="flex items-center gap-3 rounded-[14px] border border-white/[0.08] bg-[#14141F] p-3.5 shadow-sm"
                >
                  <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[10px] bg-[#3B82F6]/15 text-[#3B82F6]">
                    <Icon name="inventory_2" size={20} />
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="font-outfit text-[14.5px] font-bold text-white">{incl.name}</div>
                  </div>
                  <span className="shrink-0 rounded-lg bg-[#3B82F6]/15 px-2.5 py-1 font-inter text-[10px] font-extrabold text-[#60A5FA]">
                    AVAILABLE
                  </span>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export function ClaimedInclusionsApp() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [packageName, setPackageName] = useState("");
  const [claimed, setClaimed] = useState<any[]>([]);

  const load = useCallback(async (silent = false) => {
    if (!silent) {
      setLoading(true);
      setError(null);
    }
    const res = await get("/managed-events/my-registration");
    if (!res.success) {
      if (silent) return;
      setLoading(false);
      return setError(res.error || "Failed to load inclusions");
    }
    const reg = res.registration ?? {};
    setPackageName(String(reg.packageName ?? ""));
    setClaimed(reg.claimedInclusions ?? []);
    setError(null);
    setLoading(false);
  }, []);

  useEffect(() => {
    load();
    const t = setInterval(() => load(true), 4000);
    return () => clearInterval(t);
  }, [load]);

  return (
    <div className="min-h-screen bg-[#0A0A12] text-white">
      <AppBar title="Claimed Inclusions" outfit titleClassName="!text-left font-outfit text-[18px] font-bold" />
      <div className="px-4 pb-12 pt-3">
        {loading ? (
          <div className="py-24">
            <AppSpinner />
          </div>
        ) : error ? (
          <div className="flex flex-col items-center justify-center py-28 text-center">
            <Icon name="error_outline" size={40} color="#9CA3AF" />
            <div className="mt-3 font-inter text-sm text-muted">{error}</div>
          </div>
        ) : claimed.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-28 text-center">
            <Icon name="inventory_2" size={44} color="#9CA3AF" />
            <div className="mt-3 font-outfit text-[16px] font-bold">No claimed inclusions yet</div>
            <div className="mt-1 font-inter text-xs text-muted">Visit the counters to claim your package items.</div>
          </div>
        ) : (
          <div>
            {packageName && (
              <div className="mb-4">
                <div className="font-inter text-[11px] font-bold tracking-[0.6px] text-muted">PACKAGE</div>
                <div className="mt-0.5 font-outfit text-[17px] font-bold text-white">{packageName}</div>
              </div>
            )}
            <div className="mb-2 font-inter text-[11px] font-bold tracking-[0.6px] text-muted">
              CLAIMED ({claimed.length})
            </div>
            <div className="space-y-2.5">
              {claimed.map((c, i) => {
                const at = parseDate(c.claimedAt);
                return (
                  <div
                    key={c.inclusionName || i}
                    className="flex items-center gap-3 rounded-[14px] border border-green-500/20 bg-[#14141F] p-3.5 shadow-sm"
                  >
                    <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[10px] bg-green-500/15 text-[#22C55E]">
                      <Icon name="check_circle" size={20} />
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="font-outfit text-[14.5px] font-bold text-white">{c.inclusionName}</div>
                      {at && (
                        <div className="mt-0.5 font-inter text-xs text-muted">
                          {c.reclaimedByAdmin ? "Claimed by admin at " : "Claimed at "}
                          {fmtShortDateTime(at)}
                        </div>
                      )}
                    </div>
                    <span className="shrink-0 rounded-lg bg-green-500/15 px-2.5 py-1 font-inter text-[10px] font-extrabold text-[#22C55E]">
                      CLAIMED
                    </span>
                  </div>
                );
              })}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
