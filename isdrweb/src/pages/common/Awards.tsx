/* eslint-disable @typescript-eslint/no-explicit-any */
import { useEffect, useState } from "react";
import { Avatar, Empty, Icon, Loading, Modal, Page, SearchBox, useToast } from "@/components/ui";
import { get, put } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { idOf } from "@/lib/format";
import { useAppLayout } from "@/lib/appLayout";
import AwardsApp from "./AwardsApp";

type Award = { number: number; title: string };

const PG_AWARDS: Award[] = [
  { number: 1, title: "Best Poster Award" },
  { number: 2, title: "Best Paper Award" },
  { number: 3, title: "Best Patent Award" },
  { number: 4, title: "Best Research Grant Award" },
  { number: 5, title: "Best Research Publication Award" },
  { number: 6, title: "Best Research Centre Award" },
  { number: 7, title: "Best Research Book Award" },
  { number: 8, title: "Best Research Collaboration Award" },
];

const UG_AWARDS: Award[] = [
  { number: 9, title: "Best Poster Award" },
  { number: 10, title: "Best Paper Award" },
  { number: 11, title: "Best Publication Award" },
  { number: 12, title: "Best Grant Award" },
];

/** Conference awards. Participants see each award's winner; the admin (apartment) picks winners. */
export default function Awards() {
  // Phone width: the mobile app's screen.
  return useAppLayout() ? <AwardsApp /> : <AwardsWeb />;
}

function AwardsWeb() {
  const { user } = useAuth();
  const adminMode = user?.userType === "apartment";
  const toast = useToast();
  const [winners, setWinners] = useState<Record<string, any>>({});
  const [open, setOpen] = useState<Set<number>>(new Set());
  const [picking, setPicking] = useState<Award | null>(null);

  useEffect(() => {
    get("/awards").then((r) => r.success && r.winners && typeof r.winners === "object" && setWinners(r.winners));
  }, []);

  const save = async (award: Award, registrationId: string) => {
    setPicking(null);
    const res = await put(`/awards/${award.number}`, { registrationId });
    if (!res.success) return toast(res.error || "Could not save", "error");
    setWinners((w) => {
      const n = { ...w };
      if (res.winner && typeof res.winner === "object") n[String(award.number)] = res.winner;
      else delete n[String(award.number)];
      return n;
    });
    toast(registrationId ? "Winner saved" : "Winner removed", "success");
  };

  const card = (a: Award) => {
    const winner: string | undefined = winners[String(a.number)]?.name;
    const expanded = open.has(a.number);
    return (
      <div
        key={a.number}
        className="card card-hover overflow-hidden"
        style={{ borderColor: winner ? "rgba(245,158,11,0.4)" : undefined }}
      >
        <button
          onClick={() =>
            adminMode
              ? setPicking(a)
              : setOpen((s) => {
                  const n = new Set(s);
                  if (n.has(a.number)) n.delete(a.number);
                  else n.add(a.number);
                  return n;
                })
          }
          className="flex w-full items-center gap-4 px-5 py-4 text-left"
        >
          <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg border border-accent/30 bg-accent/15 font-extrabold text-[#93C5FD]">
            {a.number}
          </span>
          <span className="min-w-0 flex-1">
            <span className="block text-[14.5px] font-bold">{a.title}</span>
            {adminMode && (
              <span className="block text-xs font-semibold" style={{ color: winner ? "#FBBF24" : "#9CA3AF" }}>
                {winner ? `Winner: ${winner}` : "Click to choose the winner"}
              </span>
            )}
          </span>
          <Icon
            name={adminMode ? (winner ? "edit" : "person_add") : expanded ? "expand_less" : "expand_more"}
            size={20}
            color="#93C5FD"
          />
        </button>
        {!adminMode && expanded && (
          <div className="px-4 pb-4">
            <div className="flex items-center gap-2 rounded-xl border border-amber-500/30 bg-amber-500/15 px-3 py-2.5 font-semibold text-[#FBBF24]">
              <Icon name={winner ? "emoji_events" : "hourglass_top"} size={18} />
              {winner ?? "Yet to be announced"}
            </div>
          </div>
        )}
      </div>
    );
  };

  return (
    <Page
      title={adminMode ? "Award Winners" : "Conference Awards"}
      subtitle={adminMode ? "Click an award to choose its winner" : "Click an award to see its winner"}
      back={false}
    >
      <div className="grid gap-6 lg:grid-cols-2">
        <section>
          <div className="mb-3 flex items-center gap-2">
            <Icon name="emoji_events" size={20} color="#F59E0B" />
            <h2 className="font-semibold">Delegates &amp; Post Graduate Awards</h2>
            <span className="text-xs text-muted">(Cat 1 - 8)</span>
          </div>
          <div className="space-y-2.5">{PG_AWARDS.map(card)}</div>
        </section>
        <section>
          <div className="mb-3 flex items-center gap-2">
            <Icon name="school" size={20} color="#60A5FA" />
            <h2 className="font-semibold">Under Graduate Students Awards</h2>
            <span className="text-xs text-muted">(Cat 9 - 12)</span>
          </div>
          <div className="space-y-2.5">{UG_AWARDS.map(card)}</div>
        </section>
      </div>
      {picking && (
        <WinnerPicker
          award={picking}
          currentId={winners[String(picking.number)]?.registrationId ?? null}
          onPick={(id) => save(picking, id)}
          onClose={() => setPicking(null)}
        />
      )}
    </Page>
  );
}

function WinnerPicker({
  award,
  currentId,
  onPick,
  onClose,
}: {
  award: Award;
  currentId: string | null;
  onPick: (id: string) => void;
  onClose: () => void;
}) {
  const [all, setAll] = useState<any[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [q, setQ] = useState("");
  useEffect(() => {
    get("/certificates").then((r) => {
      if (r.success) setAll(r.participants ?? []);
      else setError(r.error || "Could not load participants");
    });
  }, []);
  const query = q.trim().toLowerCase();
  const shown = (all ?? []).filter(
    (p) => !query || `${p.name} ${p.idNumber} ${p.mobileNumber}`.toLowerCase().includes(query),
  );
  return (
    <Modal
      open
      onClose={onClose}
      title={
        <span className="flex items-center gap-2">
          <span className="flex-1 truncate">Winner — {award.title}</span>
          {currentId && (
            <button onClick={() => onPick("")} className="text-sm font-semibold text-[#F87171]">
              Remove
            </button>
          )}
        </span>
      }
    >
      <SearchBox value={q} onChange={setQ} placeholder="Search name, ID or mobile" />
      <div className="mt-3">
        {error ? (
          <div className="py-6 text-center text-sm text-muted">{error}</div>
        ) : !all ? (
          <Loading />
        ) : shown.length === 0 ? (
          <Empty icon="person_search" title="No participants" />
        ) : (
          shown.map((p) => {
            const selected = idOf(p) === currentId;
            return (
              <button
                key={idOf(p)}
                onClick={() => onPick(idOf(p))}
                className="flex w-full items-center gap-3 rounded-xl px-2 py-2.5 text-left hover:bg-white/5"
              >
                <Avatar name={p.name} size={36} />
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-sm font-semibold">{p.name}</span>
                  <span className="block text-xs text-muted">
                    {[p.idNumber, p.mobileNumber].filter(Boolean).join(" · ")}
                  </span>
                </span>
                {selected && <Icon name="check_circle" color="#22C55E" />}
              </button>
            );
          })
        )}
      </div>
    </Modal>
  );
}
