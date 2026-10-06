/* eslint-disable @typescript-eslint/no-explicit-any */
import { useEffect, useState } from "react";
import { Avatar, Chips, Empty, Icon, Loading, Modal, SearchBox } from "@/components/ui";
import { get } from "@/lib/api";
import { fmtShortDateTime, idOf, parseDate } from "@/lib/format";

type Claim = {
  participantName: string;
  idNumber: string;
  packageName: string;
  institution: string;
  eventTitle: string;
  inclusionName: string;
  claimedAt: Date | null;
};

/** Every inclusion claimed across the events, newest first, with search + per-inclusion filter (app's UserClaimHistoryPage). */
export function ClaimHistoryPanel() {
  const [claims, setClaims] = useState<Claim[] | null>(null);
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState("__all");

  useEffect(() => {
    (async () => {
      const list = await get("/managed-events");
      const out: Claim[] = [];
      for (const ev of list.success ? (list.events ?? []) : []) {
        const res = await get(`/managed-events/${idOf(ev)}/registrations`);
        if (!res.success) continue;
        for (const reg of res.registrations ?? []) {
          for (const c of reg.claimedInclusions ?? []) {
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
        }
      }
      out.sort((a, b) => (b.claimedAt?.getTime() ?? 0) - (a.claimedAt?.getTime() ?? 0));
      setClaims(out);
    })();
  }, []);

  const names = [...new Set((claims ?? []).map((c) => c.inclusionName).filter(Boolean))];
  const term = search.trim().toLowerCase();
  const shown = (claims ?? []).filter(
    (c) =>
      (filter === "__all" || c.inclusionName.toLowerCase() === filter.toLowerCase()) &&
      (!term ||
        [c.participantName, c.idNumber, c.inclusionName, c.packageName].some((v) => v.toLowerCase().includes(term))),
  );

  return (
    <>
      <SearchBox value={search} onChange={setSearch} placeholder="Search participant, ID number, inclusion…" />
      {claims && claims.length > 0 && (
        <div className="mt-3">
          <Chips
            value={filter}
            onChange={setFilter}
            items={[
              { value: "__all", label: `All Inclusions (${claims.length})` },
              ...names.map((n) => ({
                value: n,
                label: `${n} (${claims.filter((c) => c.inclusionName === n).length})`,
              })),
            ]}
          />
        </div>
      )}
      <div className="mt-4">
        {!claims ? (
          <Loading />
        ) : shown.length === 0 ? (
          <Empty
            icon="history"
            title={claims.length === 0 ? "No inclusions claimed yet" : "No matching claim history found"}
          />
        ) : (
          <div className="divide-y divide-line rounded-lg border border-line">
            {shown.map((c, i) => (
              <div key={i} className="flex items-center gap-3 px-4 py-3">
                <Avatar name={c.participantName || "?"} size={38} />
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="font-semibold">{c.participantName || "Participant"}</span>
                    <span className="rounded bg-field px-1.5 py-0.5 font-mono text-[11px] font-bold">
                      #{c.idNumber || "SPOT"}
                    </span>
                  </div>
                  <div className="truncate text-xs text-muted">
                    {[c.eventTitle, c.institution].filter(Boolean).join(" · ")}
                  </div>
                  <div className="mt-1 flex flex-wrap items-center gap-2 text-xs">
                    <span className="flex items-center gap-1 rounded bg-[#22C55E]/15 px-1.5 py-0.5 font-semibold text-[#86EFAC]">
                      <Icon name="redeem" size={13} />
                      {c.inclusionName}
                    </span>
                    {c.packageName && <span className="text-muted">{c.packageName}</span>}
                  </div>
                </div>
                <div className="shrink-0 text-right text-xs text-muted">{fmtShortDateTime(c.claimedAt)}</div>
              </div>
            ))}
          </div>
        )}
      </div>
    </>
  );
}

export function ClaimHistoryModal({ onClose }: { onClose: () => void }) {
  return (
    <Modal open onClose={onClose} title="Scan & Claim History" width={760}>
      <ClaimHistoryPanel />
    </Modal>
  );
}
