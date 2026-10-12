/* eslint-disable @typescript-eslint/no-explicit-any */
import { useEffect, useState } from "react";
import { Button, Icon, Modal, Page, useToast } from "@/components/ui";
import { get, put } from "@/lib/api";
import { consolidatedNames, manualRecipients, recipientsOf, type AwardRecipient } from "@/lib/awards";
import { useAuth } from "@/lib/auth";
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

/** Conference awards. Participants see each award's recipients; the admin types them. */
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
    get("/awards").then((r) => {
      if (!r.success || !r.winners || typeof r.winners !== "object") return;
      setWinners(r.winners);
      setOpen(new Set(Object.keys(r.winners).map((k) => Number(k))));
    });
  }, []);

  const save = async (award: Award, recipients: AwardRecipient[]) => {
    const res = await put(`/awards/${award.number}`, { recipients });
    if (!res.success) return res.error || "Could not save";
    setWinners((w) => {
      const n = { ...w };
      if (res.winner && typeof res.winner === "object") n[String(award.number)] = res.winner;
      else delete n[String(award.number)];
      return n;
    });
    setPicking(null);
    toast(recipients.length ? "Recipients saved" : "Recipients removed", "success");
    return null;
  };

  const names = consolidatedNames(winners);
  const card = (a: Award) => {
    const rows = recipientsOf(winners, a.number);
    const announced = rows.length > 0;
    const expanded = open.has(a.number);
    return (
      <div
        key={a.number}
        className="card card-hover overflow-hidden"
        style={{ borderColor: announced ? "rgba(245,158,11,0.4)" : undefined }}
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
          className="flex w-full items-start gap-4 px-5 py-4 text-left"
        >
          <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg border border-accent/30 bg-accent/15 font-extrabold text-[#93C5FD]">
            {a.number}
          </span>
          <span className="min-w-0 flex-1">
            <span className="block text-[14.5px] font-bold">{a.title}</span>
            {adminMode &&
              (announced ? (
                <span className="mt-2 block space-y-1.5">
                  {rows.map((r, i) => (
                    <span key={`${r.rank}-${r.name}-${i}`} className="flex items-center gap-2 text-sm font-bold text-[#FBBF24]">
                      <span className="w-5 font-extrabold">{r.rank}</span>
                      {r.name}
                    </span>
                  ))}
                </span>
              ) : (
                <span className="mt-0.5 block text-xs font-semibold text-muted">Click to enter recipients</span>
              ))}
          </span>
          <Icon
            name={adminMode ? (announced ? "edit" : "edit_note") : expanded ? "expand_less" : "expand_more"}
            size={20}
            color="#93C5FD"
          />
        </button>
        {!adminMode && expanded && (
          <div className="px-4 pb-4">
            <div className="rounded-xl border border-amber-500/30 bg-amber-500/15 px-3 py-2.5 text-[#FBBF24]">
              {announced ? (
                <div className="space-y-2">
                  {rows.map((r, i) => (
                    <div key={`${r.rank}-${r.name}-${i}`} className="flex items-center gap-2 text-sm font-bold">
                      <span className="w-5 font-extrabold">{r.rank}</span>
                      <Icon name="emoji_events" size={16} />
                      {r.name}
                    </div>
                  ))}
                </div>
              ) : (
                <div className="flex items-center gap-2 text-[13px] font-semibold">
                  <Icon name="hourglass_top" size={18} />
                  To be announced
                </div>
              )}
            </div>
          </div>
        )}
      </div>
    );
  };

  return (
    <Page
      title={adminMode ? "Award Winners" : "Conference Awards"}
      subtitle={adminMode ? "Click an award to enter its recipients" : "Click an award to see its recipients"}
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
        {names.length > 0 && (
          <section className="lg:col-span-2">
            <div className="mb-3 flex items-center gap-2">
              <Icon name="groups" size={20} color="#F59E0B" />
              <h2 className="font-semibold">Award recipients</h2>
            </div>
            <div className="card divide-y divide-white/10 px-4">
              {names.map((name, i) => (
                <div key={name} className="flex items-center gap-3 py-2.5">
                  <span className="w-7 font-outfit font-extrabold text-[#FBBF24]">{i + 1}</span>
                  <span className="font-semibold">{name}</span>
                </div>
              ))}
            </div>
          </section>
        )}
      </div>
      {picking && (
        <RecipientEditor
          award={picking}
          recipients={recipientsOf(winners, picking.number)}
          onSave={(rows) => save(picking, rows)}
          onClose={() => setPicking(null)}
        />
      )}
    </Page>
  );
}

function RecipientEditor({
  award,
  recipients,
  onSave,
  onClose,
}: {
  award: Award;
  recipients: AwardRecipient[];
  onSave: (recipients: AwardRecipient[]) => Promise<string | null>;
  onClose: () => void;
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
    <Modal
      open
      onClose={onClose}
      title={`Recipients — ${award.title}`}
      footer={
        <>
          {recipients.length > 0 && (
            <Button variant="danger" disabled={busy} onClick={() => submit([])}>
              Remove
            </Button>
          )}
          <Button loading={busy} onClick={() => submit(null)}>
            Save
          </Button>
        </>
      }
    >
      <p className="mb-3 text-sm text-muted">Type each recipient and rank. The same rank can be shared.</p>
      <div className="space-y-2">
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
                setRows((list) =>
                  list.length === 1 ? [{ rank: "1", name: "" }] : list.filter((_, idx) => idx !== i),
                )
              }
              className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-[#F87171]"
            >
              <Icon name="close" size={18} color="#F87171" />
            </button>
          </div>
        ))}
      </div>
      <button
        type="button"
        onClick={() =>
          setRows((list) => {
            const last = Number(list[list.length - 1]?.rank) || list.length;
            return [...list, { rank: String(last + 1), name: "" }];
          })
        }
        className="mt-3 inline-flex items-center gap-1 text-sm font-semibold text-[#93C5FD]"
      >
        <Icon name="add" size={18} color="#93C5FD" />
        Add recipient
      </button>
      {error && <p className="mt-3 text-sm text-[#F87171]">{error}</p>}
    </Modal>
  );
}
