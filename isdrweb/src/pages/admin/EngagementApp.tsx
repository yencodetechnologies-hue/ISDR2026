/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { AppBar, Icon, Spinner, Switch, useConfirm, useToast } from "@/components/ui";
import { AppSpinner } from "@/components/app/AppControls";
import { del, get, put } from "@/lib/api";
import { idOf, parseDate } from "@/lib/format";

const MON = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
/** 'd MMM, h:mm a' (or 'd MMM' with dayOnly). */
function when(raw: any, dayOnly = false) {
  const d = parseDate(raw);
  if (!d) return "";
  const day = `${d.getDate()} ${MON[d.getMonth()]}`;
  if (dayOnly) return day;
  const h = d.getHours();
  return `${day}, ${h % 12 || 12}:${String(d.getMinutes()).padStart(2, "0")} ${h < 12 ? "AM" : "PM"}`;
}

type Kind = "questions" | "polls" | "speaker";
const TABS: { kind: Kind; label: string }[] = [
  { kind: "questions", label: "Session Questions" },
  { kind: "polls", label: "Polls" },
  { kind: "speaker", label: "Asked to Speakers" },
];

/** Q&A & Polls at phone width — the app's EngagementOverviewPage. */
export default function EngagementApp() {
  const [tab, setTab] = useState<Kind>("questions");
  return (
    <div className="min-h-screen bg-bg">
      <div className="sticky top-0 z-30 bg-bg">
        <AppBar title="Q&A & Polls" outfit />
        <div className="flex overflow-x-auto border-b border-white/[0.08] [scrollbar-width:none]">
          {TABS.map((t) => (
            <button
              key={t.kind}
              onClick={() => setTab(t.kind)}
              className="relative shrink-0 px-4 py-3 text-[13.5px] font-semibold"
              style={{ color: tab === t.kind ? "#fff" : "#9CA3AF" }}
            >
              {t.label}
              {tab === t.kind && <span className="absolute inset-x-2 bottom-0 h-[3px] rounded-t bg-accent" />}
            </button>
          ))}
        </div>
      </div>
      {TABS.map((t) => (
        <div key={t.kind} className={tab === t.kind ? "" : "hidden"}>
          <Loader kind={t.kind} />
        </div>
      ))}
    </div>
  );
}

function Loader({ kind }: { kind: Kind }) {
  const [items, setItems] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [query, setQuery] = useState("");

  const load = useCallback(async () => {
    const path =
      kind === "questions"
        ? "/engagement/session-questions"
        : kind === "polls"
          ? "/engagement/session-polls"
          : "/engagement/speaker-questions";
    const r = await get(path);
    setLoading(false);
    if (r.success) {
      setError(null);
      setItems(kind === "polls" ? (r.polls ?? []) : (r.questions ?? []));
    } else setError(r.error || "Could not load");
  }, [kind]);
  useEffect(() => {
    load();
  }, [load]);

  const searchText = (it: any) =>
    [
      it.question,
      it.sessionName,
      it.speakerName,
      it.participantName,
      it.answer,
      ...(it.options ?? []),
      ...((it.answers ?? []) as any[]).flatMap((a) => [a.name, a.text]),
    ]
      .map((v) => String(v ?? ""))
      .join(" ")
      .toLowerCase();
  const q = query.trim().toLowerCase();
  const shown = q ? items.filter((i) => searchText(i).includes(q)) : items;
  const hint =
    kind === "questions"
      ? "Search question, session, speaker, answer…"
      : kind === "polls"
        ? "Search poll, option, session, speaker…"
        : "Search question, participant, speaker…";
  const empty =
    kind === "questions"
      ? "Speakers haven't added any questions yet"
      : kind === "polls"
        ? "Speakers haven't added any polls yet"
        : "Participants haven't asked speakers anything yet";

  if (loading) return <AppSpinner />;
  return (
    <div className="p-4">
      {!error && items.length > 0 && (
        <div className="relative mb-3.5">
          <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2">
            <Icon name="search" color="#9CA3AF" />
          </span>
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={hint}
            className="w-full rounded-xl bg-field py-3 pl-12 pr-10 text-sm outline-none placeholder:text-[13px] placeholder:text-muted"
          />
          {query && (
            <button
              onClick={() => setQuery("")}
              aria-label="Clear"
              className="absolute right-1 top-1/2 flex h-10 w-10 -translate-y-1/2 items-center justify-center"
            >
              <Icon name="clear" color="#9CA3AF" />
            </button>
          )}
        </div>
      )}
      {!error && items.length > 0 && shown.length === 0 ? (
        <div className="py-10 text-center text-[13px] text-muted">No results for &quot;{query.trim()}&quot;</div>
      ) : error || items.length === 0 ? (
        <div className="flex flex-col items-center py-[60px] text-center">
          <Icon name={error ? "error" : "forum"} outline size={40} color="rgba(156,163,175,0.6)" />
          <div className="mt-2.5 text-[13px] text-muted">{error ?? empty}</div>
        </div>
      ) : (
        shown.map((it) =>
          kind === "questions" ? (
            <QuestionCard key={idOf(it)} item={it} onChanged={load} />
          ) : kind === "polls" ? (
            <PollCard key={idOf(it)} item={it} onChanged={load} />
          ) : (
            <SpeakerQuestionCard
              key={idOf(it)}
              item={it}
              onUpdated={(next) =>
                setItems((list) => list.map((x) => (idOf(x) === idOf(next) ? { ...x, ...next } : x)))
              }
            />
          ),
        )
      )}
    </div>
  );
}

function SessionLine({ item }: { item: any }) {
  const meta = [item.speakerName, when(item.date, true)].filter(Boolean).join(" · ");
  return (
    <div>
      <div className="truncate text-[11.5px] font-semibold text-[#60A5FA]">{item.sessionName}</div>
      {meta && <div className="text-[11.5px] font-medium text-muted">{meta}</div>}
    </div>
  );
}

const QuestionText = ({ text }: { text: string }) => (
  <div className="mt-2 font-outfit text-[15px] font-bold">{text}</div>
);

function AdminActions({ item, isPoll, onChanged }: { item: any; isPoll: boolean; onChanged: () => void }) {
  const toast = useToast();
  const confirm = useConfirm();
  const [editing, setEditing] = useState(false);
  if (!item.scheduleId) return null;
  const remove = async () => {
    if (
      !(await confirm({
        title: isPoll ? "Delete poll?" : "Delete question?",
        message: isPoll
          ? "The poll and all its votes will be removed."
          : "The question and all its answers will be removed.",
        confirm: "Delete",
        danger: true,
      }))
    )
      return;
    const r = await del(`/session-content/${item.scheduleId}/${isPoll ? "polls" : "questions"}/${idOf(item)}`);
    if (r.success) {
      toast(isPoll ? "Poll deleted" : "Question deleted");
      onChanged();
    } else toast(r.error || "Could not delete");
  };
  return (
    <div className="flex justify-end" onClick={(e) => e.stopPropagation()}>
      <button
        onClick={() => setEditing(true)}
        className="inline-flex h-10 items-center gap-2 rounded-full px-3 text-sm font-medium text-[#60A5FA]"
      >
        <Icon name="edit" outline size={16} />
        Edit
      </button>
      <button
        onClick={remove}
        className="inline-flex h-10 items-center gap-2 rounded-full px-3 text-sm font-medium text-[#EF4444]"
      >
        <Icon name="delete" outline size={16} />
        Delete
      </button>
      {editing && (
        <EditDialog
          item={item}
          isPoll={isPoll}
          onClose={() => setEditing(false)}
          onSaved={() => {
            setEditing(false);
            onChanged();
          }}
        />
      )}
    </div>
  );
}

function QuestionCard({ item, onChanged }: { item: any; onChanged: () => void }) {
  const [open, setOpen] = useState(false);
  const answers: any[] = item.answers ?? [];
  return (
    <div className="mb-3 rounded-[14px] border border-line bg-card">
      <div className="flex cursor-pointer items-start pb-1.5 pl-3.5 pr-2.5 pt-1.5" onClick={() => setOpen((o) => !o)}>
        <div className="min-w-0 flex-1 pt-1.5">
          <SessionLine item={item} />
          <QuestionText text={item.question} />
          <div className="mt-1 text-[11.5px] font-semibold text-[#22C55E]">
            {answers.length === 1 ? "1 answer" : `${answers.length} answers`}
          </div>
          <AdminActions item={item} isPoll={false} onChanged={onChanged} />
        </div>
        <span
          className="mt-4 transition-transform duration-200"
          style={{ transform: open ? "rotate(180deg)" : undefined }}
        >
          <Icon name="expand_more" color="#9CA3AF" />
        </span>
      </div>
      {open && (
        <div className="px-3.5 pb-3">
          {answers.length === 0 ? (
            <div className="text-[11.5px] font-medium text-muted">No answers yet</div>
          ) : (
            answers.map((a, i) => (
              <div key={i} className="mt-2 rounded-[10px] bg-field p-2.5">
                <div className="text-[11.5px] font-bold text-[#60A5FA]">{a.name || "Participant"}</div>
                <div className="mt-[3px] text-[13px] leading-[1.4]">{a.text}</div>
              </div>
            ))
          )}
        </div>
      )}
    </div>
  );
}

function PollCard({ item, onChanged }: { item: any; onChanged: () => void }) {
  const options: string[] = item.options ?? [];
  const counts: number[] = (item.counts ?? []).map(Number);
  const total = Number(item.totalVotes) || 0;
  return (
    <div className="mb-3 rounded-[14px] border border-line bg-card p-3.5">
      <SessionLine item={item} />
      <QuestionText text={item.question} />
      <div className="mt-2.5">
        {options.map((o, i) => {
          const c = counts[i] ?? 0;
          const f = total ? c / total : 0;
          return (
            <div key={i} className="mb-2">
              <div className="flex items-center gap-2">
                <span className="flex-1 text-[13px]">{o}</span>
                <span className="text-[11.5px] font-semibold text-[#60A5FA]">
                  {c}
                  {"  ·  "}
                  {Math.round(f * 100)}%
                </span>
              </div>
              <div className="mt-[5px] h-1.5 overflow-hidden rounded bg-white/[0.08]">
                <div className="h-full bg-accent" style={{ width: `${f * 100}%` }} />
              </div>
            </div>
          );
        })}
      </div>
      <div className="text-[11.5px] font-medium text-muted">{total === 1 ? "1 vote" : `${total} votes`}</div>
      <AdminActions item={item} isPoll onChanged={onChanged} />
    </div>
  );
}

function SpeakerQuestionCard({ item, onUpdated }: { item: any; onUpdated: (next: any) => void }) {
  const toast = useToast();
  const answered = item.answered === true;
  const status = answered ? "#22C55E" : "#F59E0B";
  const participant = String(item.participantName ?? "").trim();
  const [answer, setAnswer] = useState(String(item.answer ?? ""));
  const [saving, setSaving] = useState(false);
  const [publishing, setPublishing] = useState(false);

  useEffect(() => {
    setAnswer(String(item.answer ?? ""));
  }, [item.answer]);

  const save = async () => {
    const t = answer.trim();
    if (!t) return toast("Type an answer");
    setSaving(true);
    const r = await put(`/speaker-questions/${idOf(item)}/answer`, { answer: t });
    setSaving(false);
    if (r.success) onUpdated(r.question ?? { ...item, answer: t, answered: true });
    else toast(r.error || "Could not save the answer");
  };

  const togglePublic = async (isPublic: boolean) => {
    setPublishing(true);
    const r = await put(`/speaker-questions/${idOf(item)}/public`, { isPublic });
    setPublishing(false);
    if (r.success) onUpdated(r.question ?? { ...item, isPublic });
    else toast(r.error || "Could not update");
  };

  return (
    <div className="mb-3 rounded-[14px] border border-line bg-card p-3.5">
      <div className="flex items-center gap-2">
        <div className="min-w-0 flex-1 text-[11.5px]">
          <span className="font-bold text-[#60A5FA]">{participant || "Participant"}</span>
          <span className="whitespace-pre font-medium text-muted">{"  →  "}</span>
          <span className="font-bold">{item.speakerName || "Speaker"}</span>
        </div>
        <span
          className="rounded-full px-[9px] py-1 text-[11.5px] font-bold"
          style={{ background: `${status}26`, color: status }}
        >
          {answered ? "Answered" : "Awaiting answer"}
        </span>
      </div>
      <div className="mt-[3px] text-[11.5px] font-medium text-muted">Asked {when(item.createdAt)}</div>
      <QuestionText text={item.question} />
      <textarea
        value={answer}
        rows={3}
        maxLength={1000}
        onChange={(e) => setAnswer(e.target.value)}
        placeholder="Type the answer"
        className="mt-2.5 w-full resize-none rounded-xl bg-field p-3 text-[13.5px] leading-[1.45] outline-none placeholder:text-muted"
      />
      <button
        type="button"
        disabled={saving || !answer.trim()}
        onClick={save}
        className="mt-2 flex h-10 w-full items-center justify-center rounded-xl bg-accent text-[13px] font-bold disabled:opacity-50"
      >
        {saving ? <Spinner size={18} color="#fff" /> : answered ? "Update answer" : "Save answer"}
      </button>
      <div className="mt-3 flex items-center gap-2">
        <Switch checked={item.isPublic === true} disabled={publishing} onChange={togglePublic} />
        <span className="text-[12px] text-muted">Show to all participants</span>
      </div>
    </div>
  );
}

/** Edit a poll (question + options; options lock once someone voted) or a session question — the app's _EditDialog. */
function EditDialog({
  item,
  isPoll,
  onClose,
  onSaved,
}: {
  item: any;
  isPoll: boolean;
  onClose: () => void;
  onSaved: () => void;
}) {
  const toast = useToast();
  const [question, setQuestion] = useState(String(item.question ?? ""));
  const [options, setOptions] = useState<string[]>((item.options ?? []).map(String));
  const [saving, setSaving] = useState(false);
  const locked = (Number(item.totalVotes) || 0) > 0;

  const save = async () => {
    if (!question.trim()) return;
    let opts: string[] | undefined;
    if (isPoll && !locked) {
      opts = options.map((o) => o.trim()).filter(Boolean);
      if (opts.length < 2) return toast("A poll needs at least 2 options");
    }
    setSaving(true);
    const r = await put(
      `/session-content/${item.scheduleId}/${isPoll ? "polls" : "questions"}/${idOf(item)}`,
      isPoll ? { question: question.trim(), ...(opts ? { options: opts } : {}) } : { question: question.trim() },
    );
    setSaving(false);
    if (r.success) onSaved();
    else toast(r.error || "Could not save");
  };

  const underline =
    "w-full border-b border-white/40 bg-transparent py-2 text-base outline-none focus:border-b-2 focus:border-accent";
  return (
    <div
      className="animate-fade fixed inset-0 z-[95] flex items-center justify-center bg-black/55 px-6"
      onClick={onClose}
    >
      <div
        className="max-h-[85vh] w-full max-w-[400px] overflow-y-auto rounded-[28px] bg-[#1E1E2A] p-6"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="text-2xl">{isPoll ? "Edit poll" : "Edit question"}</div>
        <div className="mt-4">
          <div className="text-xs text-muted">Question</div>
          <textarea
            value={question}
            rows={2}
            onChange={(e) => setQuestion(e.target.value)}
            className={`${underline} resize-none`}
          />
          {isPoll && (
            <div className="mt-3">
              {locked && <div className="text-xs">Options can&apos;t be changed after people have voted.</div>}
              {options.map((o, i) => (
                <div key={i} className="mt-2">
                  <div className="text-xs text-muted">Option {i + 1}</div>
                  <input
                    value={o}
                    disabled={locked}
                    onChange={(e) => setOptions((l) => l.map((x, j) => (j === i ? e.target.value : x)))}
                    className={`${underline} disabled:opacity-50`}
                  />
                </div>
              ))}
              {!locked && (
                <button
                  onClick={() => setOptions((l) => [...l, ""])}
                  className="mt-2 inline-flex h-10 items-center gap-2 rounded-full px-3 text-sm font-medium text-accent"
                >
                  <Icon name="add" size={16} />
                  Add option
                </button>
              )}
            </div>
          )}
        </div>
        <div className="mt-6 flex justify-end gap-2">
          <button onClick={onClose} className="h-10 rounded-full px-3 text-sm font-medium text-accent">
            Cancel
          </button>
          <button
            onClick={saving ? undefined : save}
            className="flex h-10 min-w-[72px] items-center justify-center rounded-full bg-accent px-5 text-sm font-medium"
          >
            {saving ? <Spinner size={16} color="#fff" /> : "Save"}
          </button>
        </div>
      </div>
    </div>
  );
}
