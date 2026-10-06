/* eslint-disable @typescript-eslint/no-explicit-any */
import { useEffect, useState } from "react";
import { AppBar, Icon, useToast } from "@/components/ui";
import { AppSpinner } from "@/components/app/AppControls";
import { get, put } from "@/lib/api";
import { useAuth } from "@/lib/auth";

type Award = { number: number; title: string };
const PG: Award[] = [
  { number: 1, title: "Best Poster Award" },
  { number: 2, title: "Best Paper Award" },
  { number: 3, title: "Best Patent Award" },
  { number: 4, title: "Best Research Grant Award" },
  { number: 5, title: "Best Research Publication Award" },
  { number: 6, title: "Best Research Centre Award" },
  { number: 7, title: "Best Research Book Award" },
  { number: 8, title: "Best Research Collaboration Award" },
];
const UG: Award[] = [
  { number: 9, title: "Best Poster Award" },
  { number: 10, title: "Best Paper Award" },
  { number: 11, title: "Best Publication Award" },
  { number: 12, title: "Best Grant Award" },
];

const NumberBadge = ({ n }: { n: number }) => (
  <span className="flex h-[38px] w-[38px] shrink-0 items-center justify-center rounded-[10px] border border-accent/30 bg-accent/15 font-outfit text-[15px] font-extrabold text-[#93C5FD]">
    {n}
  </span>
);

/** Awards at phone width — the app's AwardsPage (admin: "Award Winners" picker; participant: accordion). */
export default function AwardsApp() {
  const { user } = useAuth();
  const admin = user?.userType === "apartment";
  const toast = useToast();
  const [winners, setWinners] = useState<Record<string, any>>({});
  const [open, setOpen] = useState<Set<number>>(new Set());
  const [picking, setPicking] = useState<Award | null>(null);

  useEffect(() => {
    get("/awards").then((r) => r.success && r.winners && typeof r.winners === "object" && setWinners(r.winners));
  }, []);

  const choose = async (award: Award, registrationId: string) => {
    setPicking(null);
    const r = await put(`/awards/${award.number}`, { registrationId });
    if (r.success) {
      setWinners((w) => {
        const n = { ...w };
        if (r.winner && typeof r.winner === "object") n[String(award.number)] = r.winner;
        else delete n[String(award.number)];
        return n;
      });
      toast(registrationId ? "Winner saved" : "Winner removed");
    } else toast(r.error || "Could not save");
  };

  const card = (a: Award) => {
    const winner: string | undefined = winners[String(a.number)]?.name;
    const border = winner ? "rgba(245,158,11,0.4)" : "rgba(255,255,255,0.1)";
    if (admin)
      return (
        <button
          key={a.number}
          onClick={() => setPicking(a)}
          className="mb-2.5 flex w-full items-center rounded-2xl border bg-card px-4 py-3 text-left active:bg-white/[0.03]"
          style={{ borderColor: border }}
        >
          <NumberBadge n={a.number} />
          <span className="ml-3.5 min-w-0 flex-1">
            <span className="block font-outfit text-[14.5px] font-bold">{a.title}</span>
            <span className="mt-0.5 block text-xs font-semibold" style={{ color: winner ? "#FBBF24" : "#9CA3AF" }}>
              {winner ? `Winner: ${winner}` : "Tap to choose the winner"}
            </span>
          </span>
          <Icon name={winner ? "edit" : "person_add"} size={20} color="#93C5FD" />
        </button>
      );
    const expanded = open.has(a.number);
    return (
      <div key={a.number} className="mb-2.5 overflow-hidden rounded-2xl border bg-card" style={{ borderColor: border }}>
        <button
          onClick={() =>
            setOpen((s) => {
              const n = new Set(s);
              if (n.has(a.number)) n.delete(a.number);
              else n.add(a.number);
              return n;
            })
          }
          className="flex w-full items-center px-4 py-[14px] text-left"
        >
          <NumberBadge n={a.number} />
          <span className="ml-4 flex-1 font-outfit text-[14.5px] font-bold">{a.title}</span>
          <span
            className="transition-transform duration-200"
            style={{ transform: expanded ? "rotate(180deg)" : undefined }}
          >
            <Icon name="expand_more" color={expanded ? "#93C5FD" : "#9CA3AF"} />
          </span>
        </button>
        {expanded && (
          <div className="px-4 pb-4">
            <div className="flex items-center gap-2 rounded-[10px] border border-[#F59E0B]/30 bg-[#F59E0B]/15 px-3 py-2.5">
              <Icon name={winner ? "emoji_events" : "hourglass_top"} size={18} color="#FBBF24" />
              <span className={`text-[#FBBF24] ${winner ? "text-sm font-bold" : "text-[13px] font-semibold"}`}>
                {winner ?? "To be announced"}
              </span>
            </div>
          </div>
        )}
      </div>
    );
  };

  const header = (t: string) => <div className="mb-2.5 text-[11.5px] font-bold tracking-[0.6px] text-muted">{t}</div>;
  return (
    <div className="min-h-screen bg-bg">
      <AppBar title={admin ? "Award Winners" : "Conference Awards"} outfit />
      <div className="px-4 pb-6 pt-3.5">
        {header("DELEGATES & POST GRADUATE AWARDS (CAT 1 - 8)")}
        {PG.map(card)}
        <div className="h-3.5" />
        {header("UNDER GRADUATE STUDENTS AWARDS (CAT 9 - 12)")}
        {UG.map(card)}
      </div>
      {picking && (
        <WinnerPicker
          award={picking}
          currentId={winners[String(picking.number)]?.registrationId}
          onClose={() => setPicking(null)}
          onPick={(id) => choose(picking, id)}
        />
      )}
    </div>
  );
}

/** The app's _WinnerPickerSheet: participants list (from certificates) with search. */
function WinnerPicker({
  award,
  currentId,
  onClose,
  onPick,
}: {
  award: Award;
  currentId?: string;
  onClose: () => void;
  onPick: (id: string) => void;
}) {
  const [all, setAll] = useState<any[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [query, setQuery] = useState("");
  useEffect(() => {
    get("/certificates").then((r) => {
      if (r.success) setAll(r.participants ?? []);
      else {
        setAll([]);
        setError(r.error || "Could not load participants");
      }
    });
  }, []);
  const q = query.trim().toLowerCase();
  const shown = (all ?? []).filter((p) => !q || `${p.name} ${p.idNumber} ${p.mobileNumber}`.toLowerCase().includes(q));
  return (
    <div className="animate-fade fixed inset-0 z-[90] flex items-end" onClick={onClose}>
      <div className="absolute inset-0 bg-black/55" />
      <div
        className="animate-sheet relative flex h-[75vh] w-full flex-col rounded-t-[20px] bg-card"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mx-auto mt-2.5 h-1 w-10 rounded-sm bg-white/25" />
        <div className="flex items-center px-4 pb-1 pt-3.5">
          <div className="flex-1 font-outfit text-[17px] font-bold">Winner — {award.title}</div>
          {currentId && (
            <button onClick={() => onPick("")} className="h-10 rounded-full px-3 text-sm font-medium text-[#F87171]">
              Remove
            </button>
          )}
        </div>
        <div className="px-4 pb-2 pt-1.5">
          <div className="relative">
            <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2">
              <Icon name="search" color="#9CA3AF" />
            </span>
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search name, ID or mobile"
              className="w-full rounded-[14px] bg-field py-4 pl-12 pr-3 text-base outline-none placeholder:text-muted"
            />
          </div>
        </div>
        <div className="min-h-0 flex-1 overflow-y-auto">
          {all === null ? (
            <AppSpinner top={40} />
          ) : error ? (
            <div className="pt-16 text-center text-white/60">{error}</div>
          ) : shown.length === 0 ? (
            <div className="pt-16 text-center text-white/60">No participants</div>
          ) : (
            shown.map((p) => (
              <button
                key={p.id}
                onClick={() => onPick(String(p.id))}
                className="flex w-full items-center px-4 py-2 text-left active:bg-white/5"
              >
                <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-accent/15 font-bold text-[#93C5FD]">
                  {String(p.name ?? "?")
                    .trim()[0]
                    ?.toUpperCase() ?? "?"}
                </span>
                <span className="ml-4 min-w-0 flex-1">
                  <span className="block truncate font-semibold">{p.name}</span>
                  <span className="block truncate text-xs text-muted">
                    {[p.idNumber, p.mobileNumber].filter(Boolean).join("  •  ")}
                  </span>
                </span>
                {String(p.id) === currentId && <Icon name="emoji_events" color="#FBBF24" />}
              </button>
            ))
          )}
        </div>
      </div>
    </div>
  );
}
