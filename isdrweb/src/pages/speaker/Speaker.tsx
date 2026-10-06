/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import LiveShowCard from "@/components/LiveShowCard";
import {
  Avatar,
  Button,
  Empty,
  ErrorState,
  Icon,
  IconButton,
  Input,
  Loading,
  Modal,
  Page,
  Panel,
  Pill,
  Tabs,
  TextArea,
  useConfirm,
  useToast,
} from "@/components/ui";
import { BannerCarousel, LivePhotoButton, ModuleGrid, useHomeBanner } from "@/components/widgets";
import { del, get, post, put } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { fmtTime, idOf, monthShort, sameDay, scheduleTimes, timeAgo, weekday } from "@/lib/format";
import { useLogout } from "../common/Profile";

type Session = { raw: any; id: string; name: string; hall: string; start: Date; end: Date };

async function loadSpeakerSessions(): Promise<{ sessions: Session[]; event: any; error?: string }> {
  const res = await get("/managed-events/my-speaker-sessions");
  if (!res.success) return { sessions: [], event: null, error: res.error || "Could not load your sessions" };
  const sessions: Session[] = [];
  for (const s of (res.sessions as any[]) ?? []) {
    const w = scheduleTimes(s);
    if (w)
      sessions.push({
        raw: s,
        id: idOf(s),
        name: String(s.scheduleName ?? ""),
        hall: String(s.hall ?? ""),
        start: w.start,
        end: w.end,
      });
  }
  sessions.sort((a, b) => a.start.getTime() - b.start.getTime());
  return { sessions, event: res.event ?? null };
}

const when = (s: Session) =>
  `${weekday(s.start)}, ${s.start.getDate()} ${monthShort(s.start)}  ·  ${fmtTime(s.start)} – ${fmtTime(s.end)}`;

/** Speaker home: greeting, live card, today's sessions timeline, quick actions. */
export function SpeakerHome() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const banner = useHomeBanner();
  const [data, setData] = useState<{ sessions: Session[]; error?: string } | null>(null);
  const [now, setNow] = useState(() => new Date());

  useEffect(() => {
    loadSpeakerSessions().then(setData);
    const t = setInterval(() => setNow(new Date()), 30000);
    return () => clearInterval(t);
  }, []);

  const h = now.getHours();
  const dayPart = h < 12 ? "Morning" : h < 17 ? "Afternoon" : "Evening";
  const today = (data?.sessions ?? []).filter((s) => sameDay(s.start, now));
  const status = (s: Session) => (now >= s.end ? "completed" : now >= s.start ? "live" : "upcoming");

  return (
    <main className="mx-auto w-full max-w-[1264px] px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
      <div className="relative overflow-hidden rounded-2xl border border-line bg-gradient-to-br from-[#0B1739] via-[#0D2A3A] to-card p-6 sm:p-8">
        <div className="absolute -right-16 -top-16 h-64 w-64 rounded-full bg-[#34D399]/15 blur-3xl" />
        <div className="relative flex flex-wrap items-center gap-5">
          <div className="rounded-full bg-gradient-to-r from-[#34D399] to-[#14B8A6] p-0.5">
            <Avatar src={user?.profilePic} name={user?.name} size={64} />
          </div>
          <div className="min-w-0 flex-1">
            <div className="eyebrow tracking-[0.2em]">Connect · Inspire · Impact</div>
            <h1 className="mt-1 text-2xl font-bold tracking-tight sm:text-3xl">
              Good <span className="text-[#34D399]">{dayPart}</span>, {user?.name}
            </h1>
          </div>
          <Button icon="event_note" onClick={() => navigate("/speaker/sessions?feature=sessions")}>
            My Sessions
          </Button>
        </div>
      </div>

      <div className="mt-5 grid gap-5 lg:grid-cols-3">
        <div className="lg:col-span-2">
          {!data ? (
            <div className="card">
              <Loading />
            </div>
          ) : data.error ? (
            <div className="card p-5 text-sm text-muted">{data.error}</div>
          ) : (
            <LiveShowCard />
          )}
        </div>
        <div className="space-y-4">
          <LivePhotoButton />
          <Panel title="Quick Actions" subtitle="Make your session smooth" bodyClass="p-3">
            <div className="space-y-1">
              {[
                {
                  title: "Q&A",
                  sub: "View questions",
                  icon: "forum",
                  color: "#3B82F6",
                  to: "/speaker/sessions?feature=qa",
                },
                {
                  title: "Poll",
                  sub: "Engage your audience",
                  icon: "bar_chart",
                  color: "#10B981",
                  to: "/speaker/sessions?feature=poll",
                },
                {
                  title: "Questions",
                  sub: "Asked by participants",
                  icon: "help",
                  color: "#F59E0B",
                  to: "/speaker/questions",
                },
                {
                  title: "My Sessions",
                  sub: "Your complete schedule",
                  icon: "event_note",
                  color: "#A855F7",
                  to: "/speaker/sessions?feature=sessions",
                },
                { title: "Accommodation", sub: "Stay details", icon: "hotel", color: "#0EA5E9", to: "/accommodation" },
              ].map((a) => (
                <button
                  key={a.title}
                  onClick={() => navigate(a.to)}
                  className="flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-left transition hover:bg-white/5"
                >
                  <span
                    className="flex h-10 w-10 items-center justify-center rounded-lg"
                    style={{ background: `${a.color}26` }}
                  >
                    <Icon name={a.icon} color={a.color} />
                  </span>
                  <span className="flex-1">
                    <span className="block text-sm font-semibold">{a.title}</span>
                    <span className="block text-xs text-muted">{a.sub}</span>
                  </span>
                  <Icon name="chevron_right" size={18} color="#6B7280" />
                </button>
              ))}
            </div>
          </Panel>
        </div>
      </div>

      {banner.length > 0 && (
        <div className="mt-5">
          <BannerCarousel urls={banner} height={260} />
        </div>
      )}

      {data && !data.error && (
        <Panel
          className="mt-5"
          title="Today's Schedule"
          icon="calendar_month"
          iconColor="#60A5FA"
          action={
            <Button small variant="outline" onClick={() => navigate("/sessions")}>
              View Full Schedule <Icon name="arrow_forward" size={14} />
            </Button>
          }
        >
          {today.length === 0 ? (
            <div className="rounded-lg border border-dashed border-white/10 py-8 text-center text-sm text-muted">
              No sessions today
            </div>
          ) : (
            <ol className="relative space-y-3 border-l border-line pl-6">
              {today.map((s) => {
                const st = status(s);
                const [label, bg] =
                  st === "completed"
                    ? ["Completed", "rgba(255,255,255,0.1)"]
                    : st === "live"
                      ? ["Live", "#DC2626"]
                      : ["Upcoming", "#2563EB"];
                return (
                  <li key={s.id} className="relative">
                    <span
                      className="absolute -left-[37px] top-3 flex h-6 w-6 items-center justify-center rounded-full ring-4 ring-card"
                      style={{ background: st === "completed" ? "#16A34A" : bg }}
                    >
                      <Icon name={st === "completed" ? "check" : st === "live" ? "mic" : "schedule"} size={14} />
                    </span>
                    <div className="flex flex-wrap items-center gap-3 rounded-lg border border-line bg-white/[0.02] px-4 py-3">
                      <span className="w-20 shrink-0 text-sm font-semibold text-white/75">{fmtTime(s.start)}</span>
                      <span className="min-w-0 flex-1">
                        <span className="block truncate font-semibold">{s.name}</span>
                        {s.hall && (
                          <span className="flex items-center gap-1 text-xs text-muted">
                            <Icon name="location_on" outline size={13} />
                            {s.hall}
                          </span>
                        )}
                      </span>
                      <span className="rounded-md px-2.5 py-1 text-[11px] font-bold" style={{ background: bg }}>
                        {label}
                      </span>
                    </div>
                  </li>
                );
              })}
            </ol>
          )}
        </Panel>
      )}
    </main>
  );
}

/** Every one of the speaker's sessions by date; tapping one opens the chosen feature. */
export function SpeakerSessionPicker() {
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const feature = params.get("feature") ?? "sessions";
  const title = feature === "qa" ? "Q&A" : feature === "poll" ? "Poll" : "My Sessions";
  const [data, setData] = useState<{ sessions: Session[]; event: any; error?: string } | null>(null);
  useEffect(() => {
    loadSpeakerSessions().then(setData);
  }, []);

  const open = (s: Session) => {
    if (feature === "qa") navigate(`/speaker/qa?id=${s.id}`);
    else if (feature === "poll") navigate(`/speaker/polls?id=${s.id}`);
    else navigate(`/schedule?e=${encodeURIComponent(idOf(data?.event) || String(s.raw.eventId ?? ""))}&s=${s.id}`);
  };

  const groups: { day: Date; list: Session[] }[] = [];
  for (const s of data?.sessions ?? []) {
    const g = groups[groups.length - 1];
    if (g && sameDay(g.day, s.start)) g.list.push(s);
    else groups.push({ day: s.start, list: [s] });
  }

  return (
    <Page
      title={title}
      subtitle={
        feature === "qa"
          ? "Choose a session to manage its questions"
          : feature === "poll"
            ? "Choose a session to manage its polls"
            : "Your complete schedule"
      }
    >
      {!data ? (
        <Loading />
      ) : data.error ? (
        <ErrorState message={data.error} />
      ) : !data.sessions.length ? (
        <Empty icon="event_busy" title="You have no sessions yet" />
      ) : (
        groups.map((g) => (
          <div key={g.day.getTime()} className="mb-6">
            <div className="eyebrow mb-3">
              {weekday(g.day)}, {g.day.getDate()} {monthShort(g.day)}
            </div>
            <div className="grid gap-3 md:grid-cols-2">
              {g.list.map((s) => (
                <button
                  key={s.id}
                  onClick={() => open(s)}
                  className="card card-hover group flex w-full items-center gap-4 p-4 text-left"
                >
                  <span className="flex h-12 w-12 shrink-0 flex-col items-center justify-center rounded-lg bg-[#A855F7]/15 text-[#C4B5FD]">
                    <Icon
                      name={feature === "qa" ? "forum" : feature === "poll" ? "bar_chart" : "event_note"}
                      size={22}
                    />
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate font-semibold group-hover:text-[#93C5FD]">{s.name}</span>
                    <span className="mt-0.5 block text-xs text-muted">
                      {fmtTime(s.start)} – {fmtTime(s.end)}
                      {s.hall ? ` · ${s.hall}` : ""}
                    </span>
                  </span>
                  <Icon name="arrow_forward" size={18} color="#6B7280" />
                </button>
              ))}
            </div>
          </div>
        ))
      )}
    </Page>
  );
}

/** The session named by ?id= among the speaker's sessions. */
function useSpeakerSession() {
  const [params] = useSearchParams();
  const id = params.get("id") ?? "";
  const [session, setSession] = useState<Session | null>(null);
  useEffect(() => {
    loadSpeakerSessions().then((r) => setSession(r.sessions.find((s) => s.id === id) ?? null));
  }, [id]);
  return { id, session };
}

function SessionHeader({ session }: { session: Session | null }) {
  if (!session) return null;
  return (
    <div className="card mb-5 flex items-center gap-4 p-5">
      <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-lg bg-[#A855F7]/15">
        <Icon name="event_note" color="#C4B5FD" />
      </span>
      <div className="min-w-0">
        <div className="eyebrow">Session</div>
        <div className="truncate font-semibold">{session.name}</div>
        <div className="mt-0.5 text-xs text-muted">{when(session)}</div>
      </div>
    </div>
  );
}

/** Speaker Q&A for one session: add / edit / delete questions, see participants' answers. */
export function SpeakerSessionQuestions() {
  const { id, session } = useSpeakerSession();
  const toast = useToast();
  const confirm = useConfirm();
  const [questions, setQuestions] = useState<any[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [editing, setEditing] = useState<any | null>(null); // {} = new
  const [text, setText] = useState("");
  const [saving, setSaving] = useState(false);
  const [open, setOpen] = useState<Set<string>>(new Set());

  const load = useCallback(async () => {
    const res = await get(`/session-content/${id}`);
    if (!res.success) return setError(res.error || "Could not load questions");
    setError(null);
    setQuestions(res.questions ?? []);
  }, [id]);
  useEffect(() => {
    load();
  }, [load]);

  const save = async () => {
    const t = text.trim();
    if (!t) return;
    setSaving(true);
    const isNew = !idOf(editing);
    const res = isNew
      ? await post(`/session-content/${id}/questions`, { question: t })
      : await put(`/session-content/${id}/questions/${idOf(editing)}`, { question: t });
    setSaving(false);
    if (!res.success)
      return toast(res.error || (isNew ? "Could not add the question" : "Could not update the question"), "error");
    setEditing(null);
    load();
  };

  const remove = async (q: any) => {
    if (
      !(await confirm({
        title: "Delete this question?",
        message: "Participants will no longer see it.",
        confirm: "Delete",
        danger: true,
      }))
    )
      return;
    const res = await del(`/session-content/${id}/questions/${idOf(q)}`);
    if (res.success) setQuestions((l) => (l ?? []).filter((x) => idOf(x) !== idOf(q)));
    else toast(res.error || "Could not delete", "error");
  };

  return (
    <Page
      title="Q&A"
      width={960}
      actions={
        <Button
          icon="add"
          onClick={() => {
            setEditing({});
            setText("");
          }}
        >
          Add Question
        </Button>
      }
    >
      <SessionHeader session={session} />
      {error ? (
        <ErrorState message={error} onRetry={load} />
      ) : !questions ? (
        <Loading />
      ) : questions.length === 0 ? (
        <Empty icon="help" title="No questions yet" subtitle="Add a question for participants to answer." />
      ) : (
        <div className="space-y-3">
          {questions.map((q) => {
            const answers: any[] = q.answers ?? [];
            const isOpen = open.has(idOf(q));
            return (
              <div key={idOf(q)} className="card overflow-hidden">
                <div className="flex items-start gap-2 p-3.5">
                  <button
                    className="min-w-0 flex-1 text-left"
                    onClick={() =>
                      setOpen((s) => {
                        const n = new Set(s);
                        if (n.has(idOf(q))) n.delete(idOf(q));
                        else n.add(idOf(q));
                        return n;
                      })
                    }
                  >
                    <div className="font-semibold">{q.question}</div>
                    <div className="mt-1 text-xs text-muted">
                      {answers.length === 1 ? "1 answer" : `${answers.length} answers`}
                    </div>
                  </button>
                  <IconButton
                    icon="edit"
                    outline
                    title="Edit"
                    size={20}
                    onClick={() => {
                      setEditing(q);
                      setText(String(q.question ?? ""));
                    }}
                  />
                  <IconButton
                    icon="delete"
                    outline
                    title="Delete"
                    size={20}
                    color="#EF4444"
                    onClick={() => remove(q)}
                  />
                </div>
                {isOpen && (
                  <div className="space-y-2 border-t border-line p-3.5">
                    {answers.length === 0 ? (
                      <div className="text-sm text-muted">No answers yet</div>
                    ) : (
                      answers.map((a, i) => (
                        <div key={i} className="rounded-lg bg-field p-2.5">
                          <div className="text-xs font-bold text-[#60A5FA]">{a.name || "Participant"}</div>
                          <div className="mt-0.5 whitespace-pre-wrap text-sm">{a.text}</div>
                        </div>
                      ))
                    )}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
      <Modal open={!!editing} onClose={() => setEditing(null)} title={idOf(editing) ? "Edit question" : "Add question"}>
        <TextArea
          rows={4}
          maxLength={500}
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder="Type the question participants should answer"
          autoFocus
        />
        <div className="mt-4 flex justify-end gap-2">
          <Button variant="outline" onClick={() => setEditing(null)}>
            Cancel
          </Button>
          <Button loading={saving} disabled={!text.trim()} onClick={save}>
            {idOf(editing) ? "Save" : "Add"}
          </Button>
        </div>
      </Modal>
    </Page>
  );
}

/** Speaker polls for one session with live results; create / edit / delete. */
export function SpeakerSessionPolls() {
  const { id, session } = useSpeakerSession();
  const navigate = useNavigate();
  const toast = useToast();
  const confirm = useConfirm();
  const [polls, setPolls] = useState<any[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    const res = await get(`/session-content/${id}`);
    if (!res.success) return setError(res.error || "Could not load polls");
    setError(null);
    setPolls(res.polls ?? []);
  }, [id]);
  useEffect(() => {
    load();
  }, [load]);

  const remove = async (p: any) => {
    if (
      !(await confirm({
        title: "Delete this poll?",
        message: "Participants will no longer see it.",
        confirm: "Delete",
        danger: true,
      }))
    )
      return;
    const res = await del(`/session-content/${id}/polls/${idOf(p)}`);
    if (res.success) setPolls((l) => (l ?? []).filter((x) => idOf(x) !== idOf(p)));
    else toast(res.error || "Could not delete", "error");
  };

  const edit = (p?: any) => {
    if (p) sessionStorage.setItem("edit_poll", JSON.stringify(p));
    else sessionStorage.removeItem("edit_poll");
    navigate(`/speaker/polls/edit?id=${id}${p ? `&poll=${idOf(p)}` : ""}`);
  };

  return (
    <Page
      title="Poll"
      actions={
        <Button icon="add" onClick={() => edit()}>
          Create Poll
        </Button>
      }
    >
      <SessionHeader session={session} />
      {error ? (
        <ErrorState message={error} onRetry={load} />
      ) : !polls ? (
        <Loading />
      ) : polls.length === 0 ? (
        <Empty icon="bar_chart" title="No polls yet" subtitle="Create a poll for participants to vote on." />
      ) : (
        <div className="grid gap-4 md:grid-cols-2">
          {polls.map((p) => {
            const options: string[] = p.options ?? [];
            const counts: number[] = (p.counts ?? []).map((c: any) => Number(c) || 0);
            const total = Number(p.totalVotes) || 0;
            return (
              <div key={idOf(p)} className="card p-5">
                <div className="flex items-start gap-2">
                  <div className="flex-1 font-semibold">{p.question}</div>
                  <IconButton icon="edit" outline title="Edit" size={20} onClick={() => edit(p)} />
                  <IconButton
                    icon="delete"
                    outline
                    title="Delete"
                    size={20}
                    color="#EF4444"
                    onClick={() => remove(p)}
                  />
                </div>
                <div className="mt-2 space-y-2">
                  {options.map((o, i) => {
                    const c = counts[i] ?? 0;
                    const pct = total ? Math.round((c / total) * 100) : 0;
                    return (
                      <div key={i}>
                        <div className="flex justify-between text-sm">
                          <span>{o}</span>
                          <span className="text-muted">
                            {c} · {pct}%
                          </span>
                        </div>
                        <div className="mt-1 h-2 overflow-hidden rounded-full bg-white/10">
                          <div className="h-full rounded-full bg-[#10B981]" style={{ width: `${pct}%` }} />
                        </div>
                      </div>
                    );
                  })}
                </div>
                <div className="mt-2 text-xs text-muted">{total === 1 ? "1 vote" : `${total} votes`}</div>
              </div>
            );
          })}
        </div>
      )}
    </Page>
  );
}

const MAX_OPTIONS = 6;

/** Create / edit a poll (options lock once anyone has voted). */
export function SpeakerPollEditor() {
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const toast = useToast();
  const id = params.get("id") ?? "";
  const pollId = params.get("poll");
  const [poll] = useState<any>(() => {
    if (!pollId) return null;
    try {
      const p = JSON.parse(sessionStorage.getItem("edit_poll") ?? "null");
      return p && idOf(p) === pollId ? p : null;
    } catch {
      return null;
    }
  });
  const editing = !!pollId;
  const locked = (Number(poll?.totalVotes) || 0) > 0;
  const [question, setQuestion] = useState<string>(poll?.question ?? "");
  const [options, setOptions] = useState<string[]>(() => (poll?.options?.length ? poll.options.map(String) : ["", ""]));
  const [saving, setSaving] = useState(false);

  const save = async () => {
    const q = question.trim();
    const opts = options.map((o) => o.trim()).filter(Boolean);
    if (!q) return toast("Enter the poll question", "error");
    if (opts.length < 2) return toast("Add at least 2 options", "error");
    setSaving(true);
    const res = editing
      ? await put(`/session-content/${id}/polls/${pollId}`, { question: q, ...(locked ? {} : { options: opts }) })
      : await post(`/session-content/${id}/polls`, { question: q, options: opts });
    setSaving(false);
    if (!res.success)
      return toast(res.error || (editing ? "Could not update the poll" : "Could not create the poll"), "error");
    navigate(-1);
  };

  return (
    <Page title={editing ? "Edit Poll" : "Create Poll"} width={720}>
      <div className="card p-6">
        <div className="label">Question</div>
        <TextArea
          rows={3}
          value={question}
          onChange={(e) => setQuestion(e.target.value)}
          placeholder="e.g. Which technique do you use most?"
        />
        <div className="label mt-5">Options</div>
        {locked && (
          <div className="mb-3 flex items-start gap-2 rounded-xl border border-amber-500/30 bg-amber-500/10 p-3 text-sm text-amber-200">
            <Icon name="lock" size={18} />
            Participants have voted, so the options can’t be changed. You can still edit the question.
          </div>
        )}
        <div className="space-y-2">
          {options.map((o, i) => (
            <div key={i} className="flex items-center gap-2">
              <Input
                value={o}
                disabled={locked}
                onChange={(e) => setOptions((l) => l.map((x, k) => (k === i ? e.target.value : x)))}
                placeholder={`Option ${i + 1}`}
              />
              {options.length > 2 && !locked && (
                <IconButton
                  icon="close"
                  title="Remove"
                  color="#9CA3AF"
                  onClick={() => setOptions((l) => l.filter((_, k) => k !== i))}
                />
              )}
            </div>
          ))}
        </div>
        {options.length < MAX_OPTIONS && !locked && (
          <Button variant="ghost" icon="add" className="mt-2" onClick={() => setOptions((l) => [...l, ""])}>
            Add option
          </Button>
        )}
        <div className="mt-6 flex justify-end gap-2 border-t border-line pt-5">
          <Button variant="outline" onClick={() => navigate(-1)}>
            Cancel
          </Button>
          <Button icon="check" loading={saving} onClick={save}>
            Save Poll
          </Button>
        </div>
      </div>
    </Page>
  );
}

/** Participants' private questions to this speaker: Unanswered / Answered tabs; answer once. */
export function SpeakerParticipantQuestions() {
  const toast = useToast();
  const [questions, setQuestions] = useState<any[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [tab, setTab] = useState<"open" | "done">("open");
  const [drafts, setDrafts] = useState<Record<string, string>>({});
  const [sending, setSending] = useState<string | null>(null);

  const load = useCallback(async () => {
    const res = await get("/speaker-questions/inbox");
    if (!res.success) return setError(res.error || "Could not load questions");
    setError(null);
    setQuestions(res.questions ?? []);
  }, []);
  useEffect(() => {
    load();
  }, [load]);

  const answer = async (q: any) => {
    const t = (drafts[idOf(q)] ?? "").trim();
    if (!t) return;
    setSending(idOf(q));
    const res = await post(`/speaker-questions/${idOf(q)}/answer`, { answer: t });
    setSending(null);
    if (res.success && res.question) {
      setQuestions((l) => (l ?? []).map((x) => (idOf(x) === idOf(q) ? res.question : x)));
      toast("Answer sent", "success");
    } else toast(res.error || "Could not send answer", "error");
  };

  const unanswered = (questions ?? []).filter((q) => q.answered !== true);
  const answered = (questions ?? []).filter((q) => q.answered === true);
  const list = tab === "open" ? unanswered : answered;

  return (
    <Page title="Participant Questions" subtitle="Private questions participants asked you" width={960}>
      <Tabs
        value={tab}
        onChange={setTab}
        tabs={[
          { value: "open", label: `Unanswered (${unanswered.length})` },
          { value: "done", label: `Answered (${answered.length})` },
        ]}
      />
      <div className="mt-4">
        {error ? (
          <ErrorState message={error} onRetry={load} />
        ) : !questions ? (
          <Loading />
        ) : list.length === 0 ? (
          <Empty icon="forum" title={tab === "open" ? "No new questions" : "No answered questions yet"} />
        ) : (
          <div className="space-y-3">
            {list.map((q) => {
              const name = String(q.participantName ?? "").trim() || "Participant";
              return (
                <div key={idOf(q)} className="card p-5">
                  <div className="flex items-center gap-2.5">
                    <Avatar name={name} size={34} />
                    <div className="min-w-0 flex-1">
                      <div className="truncate text-sm font-bold">{name}</div>
                      {q.createdAt && <div className="text-[11px] text-muted">{timeAgo(q.createdAt)}</div>}
                    </div>
                    {q.answered && <Pill color="#22C55E">Answered</Pill>}
                  </div>
                  <div className="mt-3 whitespace-pre-wrap font-semibold">{q.question}</div>
                  {q.answered ? (
                    <div className="mt-2.5 rounded-xl bg-accent/10 p-3">
                      <div className="text-[10.5px] font-bold tracking-wider text-accent">YOUR ANSWER</div>
                      <div className="mt-1 whitespace-pre-wrap text-sm">{q.answer}</div>
                    </div>
                  ) : (
                    <>
                      <TextArea
                        className="mt-2.5"
                        maxLength={1000}
                        value={drafts[idOf(q)] ?? ""}
                        onChange={(e) => setDrafts((d) => ({ ...d, [idOf(q)]: e.target.value }))}
                        placeholder="Type your answer"
                      />
                      <div className="mt-2 flex justify-end">
                        <Button
                          small
                          icon="send"
                          loading={sending === idOf(q)}
                          disabled={!(drafts[idOf(q)] ?? "").trim()}
                          onClick={() => answer(q)}
                        >
                          Send answer
                        </Button>
                      </div>
                    </>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>
    </Page>
  );
}

/** Speaker "More": Change Password and Logout. */
export function SpeakerMore() {
  const doLogout = useLogout();
  return (
    <Page title="More">
      <ModuleGrid
        items={[
          { label: "Change Password", icon: "lock", color: "#3B82F6", to: "/change-password" },
          { label: "Logout", icon: "logout", color: "#EF4444", onClick: doLogout },
        ]}
      />
    </Page>
  );
}
