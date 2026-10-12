/* eslint-disable @typescript-eslint/no-explicit-any */
import { useEffect, useState } from "react";
import { AppBar, Icon, useToast } from "@/components/ui";
import { get, put } from "@/lib/api";
import { consolidatedNames, manualRecipients, recipientsOf, type AwardRecipient } from "@/lib/awards";
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

/** Awards at phone width — the app's AwardsPage (admin types recipients; participant sees the accordion). */
export default function AwardsApp() {
  const { user } = useAuth();
  const admin = user?.userType === "apartment";
  const toast = useToast();
  const [winners, setWinners] = useState<Record<string, any>>({});
  const [open, setOpen] = useState<Set<number>>(new Set());
  const [picking, setPicking] = useState<Award | null>(null);

  useEffect(() => {
    get("/awards").then((r) => {
      if (!r.success || !r.winners || typeof r.winners !== "object") return;
      setWinners(r.winners);
      setOpen(new Set(Object.keys(r.winners).map((k) => Number(k))));
    });
  }, []);

  const choose = async (award: Award, recipients: AwardRecipient[]) => {
    const r = await put(`/awards/${award.number}`, { recipients });
    if (!r.success) return r.error || "Could not save";
    setWinners((w) => {
      const n = { ...w };
      if (r.winner && typeof r.winner === "object") n[String(award.number)] = r.winner;
      else delete n[String(award.number)];
      return n;
    });
    setPicking(null);
    toast(recipients.length ? "Recipients saved" : "Recipients removed");
    return null;
  };

  const names = consolidatedNames(winners);
  const card = (a: Award) => {
    const rows = recipientsOf(winners, a.number);
    const announced = rows.length > 0;
    const border = announced ? "rgba(245,158,11,0.4)" : "rgba(255,255,255,0.1)";
    if (admin)
      return (
        <button
          key={a.number}
          onClick={() => setPicking(a)}
          className="mb-2.5 flex w-full items-start rounded-2xl border bg-card px-4 py-3 text-left active:bg-white/[0.03]"
          style={{ borderColor: border }}
        >
          <NumberBadge n={a.number} />
          <span className="ml-3.5 min-w-0 flex-1">
            <span className="block font-outfit text-[14.5px] font-bold">{a.title}</span>
            {announced ? (
              <span className="mt-1.5 block space-y-1">
                {rows.map((r, i) => (
                  <span key={`${r.rank}-${r.name}-${i}`} className="flex items-center gap-2 text-sm font-bold text-[#FBBF24]">
                    <span className="w-5 font-extrabold">{r.rank}</span>
                    {r.name}
                  </span>
                ))}
              </span>
            ) : (
              <span className="mt-0.5 block text-xs font-semibold text-muted">Tap to enter recipients</span>
            )}
          </span>
          <Icon name={announced ? "edit" : "edit_note"} size={20} color="#93C5FD" />
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
            <div className="rounded-[10px] border border-[#F59E0B]/30 bg-[#F59E0B]/15 px-3 py-2.5">
              {announced ? (
                <div className="space-y-2">
                  {rows.map((r, i) => (
                    <div key={`${r.rank}-${r.name}-${i}`} className="flex items-center gap-2 text-sm font-bold text-[#FBBF24]">
                      <span className="w-5 font-extrabold">{r.rank}</span>
                      <Icon name="emoji_events" size={16} color="#FBBF24" />
                      {r.name}
                    </div>
                  ))}
                </div>
              ) : (
                <div className="flex items-center gap-2 text-[13px] font-semibold text-[#FBBF24]">
                  <Icon name="hourglass_top" size={18} color="#FBBF24" />
                  To be announced
                </div>
              )}
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
        {names.length > 0 && (
          <>
            <div className="h-3.5" />
            {header("AWARD RECIPIENTS")}
            <div className="rounded-2xl border border-[#F59E0B]/40 bg-card px-3.5 py-2">
              {names.map((name, i) => (
                <div key={name} className="flex items-center gap-2 py-1.5">
                  <span className="w-7 font-outfit text-sm font-extrabold text-[#FBBF24]">{i + 1}</span>
                  <span className="text-sm font-semibold">{name}</span>
                </div>
              ))}
            </div>
          </>
        )}
      </div>
      {picking && (
        <RecipientEditor
          award={picking}
          recipients={recipientsOf(winners, picking.number)}
          onClose={() => setPicking(null)}
          onSave={(rows) => choose(picking, rows)}
        />
      )}
    </div>
  );
}

/** The app's recipient sheet: typed rank and name, not a participant list. */
function RecipientEditor({
  award,
  recipients,
  onClose,
  onSave,
}: {
  award: Award;
  recipients: AwardRecipient[];
  onClose: () => void;
  onSave: (recipients: AwardRecipient[]) => Promise<string | null>;
}) {
  const [rows, setRows] = useState(() =>
    recipients.length ? recipients.map((r) => ({ rank: String(r.rank), name: r.name })) : [{ rank: "1", name: "" }],
  );
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const update = (i: number, patch: Partial<{ rank: string; name: string }>) =>
    setRows((list) => list.map((row, idx) => (idx === i ? { ...row, ...patch } : row)));

  const submit = async (next: AwardRecipient[] | null) => {
    let payload = next;
    if (!payload) {
      const parsed = manualRecipients(rows);
      if ("error" in parsed) {
        setError(parsed.error);
        return;
      }
      payload = parsed.recipients;
    }
    setBusy(true);
    setError(null);
    const err = await onSave(payload);
    if (err) {
      setBusy(false);
      setError(err);
    }
  };

  return (
    <div className="animate-fade fixed inset-0 z-[90] flex items-end" onClick={onClose}>
      <div className="absolute inset-0 bg-black/55" />
      <div
        className="animate-sheet relative flex max-h-[75vh] w-full flex-col rounded-t-[20px] bg-card"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mx-auto mt-2.5 h-1 w-10 rounded-sm bg-white/25" />
        <div className="flex items-center px-4 pb-1 pt-3.5">
          <div className="min-w-0 flex-1 truncate font-outfit text-[17px] font-bold">Recipients — {award.title}</div>
          {recipients.length > 0 && (
            <button
              disabled={busy}
              onClick={() => submit([])}
              className="h-10 shrink-0 rounded-full px-3 text-sm font-medium text-[#F87171] disabled:opacity-50"
            >
              Remove
            </button>
          )}
        </div>
        <p className="px-4 pb-2 text-xs text-muted">Type each recipient and rank. The same rank can be shared.</p>
        <div className="min-h-0 flex-1 space-y-2 overflow-y-auto px-4">
          {rows.map((row, i) => (
            <div key={i} className="flex items-center gap-2">
              <input
                value={row.rank}
                onChange={(e) => update(i, { rank: e.target.value.replace(/\D/g, "") })}
                inputMode="numeric"
                aria-label="Rank"
                className="w-14 rounded-xl bg-field px-2 py-3 text-center text-sm outline-none"
              />
              <input
                value={row.name}
                onChange={(e) => update(i, { name: e.target.value })}
                placeholder="Recipient name"
                className="min-w-0 flex-1 rounded-xl bg-field px-3 py-3 text-sm outline-none placeholder:text-muted"
              />
              <button
                type="button"
                aria-label="Remove row"
                onClick={() =>
                  setRows((list) => (list.length === 1 ? [{ rank: "1", name: "" }] : list.filter((_, idx) => idx !== i)))
                }
                className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full"
              >
                <Icon name="close" size={18} color="#F87171" />
              </button>
            </div>
          ))}
          <button
            type="button"
            onClick={() =>
              setRows((list) => {
                const last = Number(list[list.length - 1]?.rank) || list.length;
                return [...list, { rank: String(last + 1), name: "" }];
              })
            }
            className="inline-flex items-center gap-1 py-2 text-sm font-semibold text-[#93C5FD]"
          >
            <Icon name="add" size={18} color="#93C5FD" />
            Add recipient
          </button>
          {error && <p className="text-sm text-[#F87171]">{error}</p>}
        </div>
        <div className="px-4 pb-4 pt-2">
          <button
            type="button"
            disabled={busy}
            onClick={() => submit(null)}
            className="flex h-12 w-full items-center justify-center rounded-xl bg-accent text-sm font-bold disabled:opacity-50"
          >
            {busy ? "Saving…" : "Save"}
          </button>
        </div>
      </div>
    </div>
  );
}
