/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  Avatar,
  Button,
  Chips,
  Empty,
  ErrorState,
  Icon,
  Loading,
  Modal,
  Page,
  Pill,
  TextArea,
  useToast,
} from "@/components/ui";
import { get, post } from "@/lib/api";
import { fmtDate, idOf, parseDate, timeAgo } from "@/lib/format";
import { useAppLayout } from "@/lib/appLayout";
import {
  AskSpeakerApp,
  MyQuestionsApp,
  ParticipantPollsApp,
  ParticipantQaApp,
} from "./ParticipantQaPollsApp";

/* ------------------------------------------------------------------ */
/* Q/A                                                                 */
/* ------------------------------------------------------------------ */

function SessionQuestionCard({ q, onAnswered }: { q: any; onAnswered: (text: string) => void }) {
  const toast = useToast();
  const [text, setText] = useState("");
  const [sending, setSending] = useState(false);
  const myAnswer: string | undefined = q.myAnswer ?? undefined;
  const date = parseDate(q.date);

  const send = async () => {
    const t = text.trim();
    if (!t) return;
    setSending(true);
    const res = await post(`/session-content/${q.scheduleId}/questions/${idOf(q)}/answer`, { text: t });
    setSending(false);
    if (res.success) onAnswered(t);
    else toast(res.error || "Could not send answer", "error");
  };

  return (
    <div className="card p-5">
      <div className="flex items-center gap-2.5">
        <Avatar src={q.speakerPhoto} name={q.speakerName} size={38} />
        <div className="min-w-0 flex-1">
          <div className="truncate text-sm font-bold">{q.speakerName}</div>
          <div className="truncate text-xs text-muted">
            {q.sessionName}
            {date ? ` · ${fmtDate(date)}` : ""}
          </div>
        </div>
        {myAnswer ? (
          <Pill color="#22C55E">Answered</Pill>
        ) : (
          <span className="text-[11px] text-muted">{q.createdAt ? `Asked ${timeAgo(q.createdAt)}` : ""}</span>
        )}
      </div>
      <div className="mt-3 font-semibold">{q.question}</div>
      {myAnswer ? (
        <div className="mt-2.5 rounded-xl bg-accent/10 p-3">
          <div className="text-[10.5px] font-bold tracking-wider text-accent">YOUR ANSWER</div>
          <div className="mt-1 whitespace-pre-wrap text-sm">{myAnswer}</div>
        </div>
      ) : (
        <>
          <TextArea
            className="mt-2.5"
            maxLength={1000}
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder="Type your answer"
          />
          <div className="mt-2 flex justify-end">
            <Button small icon="send" loading={sending} disabled={!text.trim()} onClick={send}>
              Submit Answer
            </Button>
          </div>
        </>
      )}
    </div>
  );
}

/** Q/A hub: speakers' session questions for you, Ask a Speaker, My Questions. */
export function ParticipantQa() {
  return useAppLayout() ? <ParticipantQaApp /> : <ParticipantQaWeb />;
}

function ParticipantQaWeb() {
  const navigate = useNavigate();
  const [questions, setQuestions] = useState<any[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pendingOnly, setPendingOnly] = useState(false);

  const load = useCallback(async () => {
    const res = await get("/speaker-questions/session-questions");
    if (!res.success) return setError(res.error || "Could not load questions");
    setError(null);
    setQuestions(res.questions ?? []);
  }, []);
  useEffect(() => {
    load();
  }, [load]);

  const pending = (questions ?? []).filter((q) => q.myAnswer == null).length;
  const shown = pendingOnly ? (questions ?? []).filter((q) => q.myAnswer == null) : (questions ?? []);

  return (
    <Page
      title="Q/A"
      subtitle="Your questions make the session more valuable! Be a part of the discussion."
      back={false}
    >
      <div className="grid gap-6 lg:grid-cols-[1fr_320px]">
        <div>
          <div className="mb-4 flex flex-wrap items-center gap-3">
            <h2 className="text-lg font-semibold">Questions for You</h2>
            {pending > 0 && <Pill color="#F59E0B">{pending} TO ANSWER</Pill>}
            <span className="flex-1" />
            <Chips
              value={pendingOnly ? "open" : "all"}
              onChange={(v) => setPendingOnly(v === "open")}
              items={[
                { value: "all", label: "All" },
                { value: "open", label: "Unanswered", icon: "tune" },
              ]}
            />
          </div>
          {error ? (
            <ErrorState message={error} onRetry={load} />
          ) : !questions ? (
            <Loading />
          ) : shown.length === 0 ? (
            <Empty icon="help" title={pendingOnly ? "No questions left to answer" : "No questions from speakers yet"} />
          ) : (
            <div className="space-y-4">
              {shown.map((q) => (
                <SessionQuestionCard
                  key={idOf(q)}
                  q={q}
                  onAnswered={(text) =>
                    setQuestions((l) => (l ?? []).map((x) => (idOf(x) === idOf(q) ? { ...x, myAnswer: text } : x)))
                  }
                />
              ))}
            </div>
          )}
        </div>
        <aside className="space-y-3 lg:sticky lg:top-24 lg:self-start">
          <div className="rounded-xl border border-line bg-gradient-to-br from-[#1E3A8A] to-card p-5">
            <Icon name="record_voice_over" size={30} color="#93C5FD" />
            <div className="mt-3 font-semibold">Have a question for a speaker?</div>
            <div className="mt-1 text-sm text-white/70">Only you and the speaker will see it.</div>
            <Button full icon="send" className="mt-4" onClick={() => navigate("/participant/qa/ask")}>
              Ask a Speaker
            </Button>
          </div>
          <button
            onClick={() => navigate("/participant/qa/mine")}
            className="card card-hover flex w-full items-center gap-3 p-4 text-left"
          >
            <span className="flex h-10 w-10 items-center justify-center rounded-lg bg-[#A78BFA]/15">
              <Icon name="forum" color="#A78BFA" />
            </span>
            <span className="flex-1">
              <span className="block font-semibold">My Questions</span>
              <span className="block text-xs text-muted">View your answers</span>
            </span>
            <Icon name="chevron_right" color="#6B7280" />
          </button>
          <button
            onClick={() => navigate("/participant/polls")}
            className="card card-hover flex w-full items-center gap-3 p-4 text-left"
          >
            <span className="flex h-10 w-10 items-center justify-center rounded-lg bg-[#8B5CF6]/15">
              <Icon name="poll" color="#8B5CF6" />
            </span>
            <span className="flex-1">
              <span className="block font-semibold">View All Polls &amp; Q/A</span>
              <span className="block text-xs text-muted">Vote on session polls</span>
            </span>
            <Icon name="chevron_right" color="#6B7280" />
          </button>
        </aside>
      </div>
    </Page>
  );
}

/** Ask a Speaker: pick a speaker, send a private question. */
export function AskSpeaker() {
  return useAppLayout() ? <AskSpeakerApp /> : <AskSpeakerWeb />;
}

function AskSpeakerWeb() {
  const navigate = useNavigate();
  const toast = useToast();
  const [speakers, setSpeakers] = useState<any[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [asking, setAsking] = useState<any>(null);
  const [text, setText] = useState("");
  const [sending, setSending] = useState(false);

  useEffect(() => {
    get("/speaker-questions/speakers").then((r) => {
      if (r.success) setSpeakers(r.speakers ?? []);
      else setError(r.error || "Could not load speakers");
    });
  }, []);

  const send = async () => {
    const t = text.trim();
    if (!t || !asking) return;
    setSending(true);
    const res = await post("/speaker-questions", { speakerId: idOf(asking), question: t });
    setSending(false);
    if (!res.success) return toast(res.error || "Could not send question", "error");
    setAsking(null);
    setText("");
    toast("Question sent", "success");
    navigate("/participant/qa/mine", { replace: true });
  };

  return (
    <Page title="Ask a Speaker" subtitle="Choose a speaker to send a private question">
      {error ? (
        <ErrorState message={error} />
      ) : !speakers ? (
        <Loading />
      ) : speakers.length === 0 ? (
        <Empty icon="groups" title="No speakers yet" />
      ) : (
        <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
          {speakers.map((s) => (
            <button
              key={idOf(s)}
              onClick={() => setAsking(s)}
              className="card card-hover group flex w-full items-center gap-3.5 p-4 text-left"
            >
              <Avatar src={s.photo} name={s.name} size={50} />
              <div className="min-w-0 flex-1">
                <div className="truncate font-semibold group-hover:text-[#93C5FD]">{s.name}</div>
                {(s.designation || s.institution) && (
                  <div className="truncate text-xs text-muted">
                    {[s.designation, s.institution].filter(Boolean).join(" · ")}
                  </div>
                )}
              </div>
              <Icon name="send" size={18} color="#6B7280" />
            </button>
          ))}
        </div>
      )}
      <Modal
        open={!!asking}
        onClose={() => setAsking(null)}
        title={asking ? `Ask ${asking.name}` : ""}
        footer={
          <>
            <Button variant="outline" onClick={() => setAsking(null)}>
              Cancel
            </Button>
            <Button icon="send" loading={sending} disabled={!text.trim()} onClick={send}>
              Send question
            </Button>
          </>
        }
      >
        <TextArea
          rows={5}
          maxLength={1000}
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder="Type your question"
          autoFocus
        />
        <div className="mt-2 text-xs text-muted">Only you and the speaker will see this question and the answer.</div>
      </Modal>
    </Page>
  );
}

/** My Questions: the participant's questions to speakers and their answers. */
export function MyQuestions() {
  return useAppLayout() ? <MyQuestionsApp /> : <MyQuestionsWeb />;
}

function MyQuestionsWeb() {
  const [questions, setQuestions] = useState<any[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  useEffect(() => {
    get("/speaker-questions/mine").then((r) => {
      if (r.success) setQuestions(r.questions ?? []);
      else setError(r.error || "Could not load your questions");
    });
  }, []);
  return (
    <Page title="My Questions" subtitle="Your questions to speakers and their answers">
      {error ? (
        <ErrorState message={error} />
      ) : !questions ? (
        <Loading />
      ) : questions.length === 0 ? (
        <Empty icon="forum" title="No questions yet" subtitle="Ask a speaker and their answer will show here." />
      ) : (
        <div className="grid gap-4 md:grid-cols-2">
          {questions.map((q) => {
            const answered = q.answered === true;
            return (
              <div key={idOf(q)} className="card p-5">
                <div className="flex items-center gap-2.5">
                  <Avatar src={q.speakerPhoto} name={q.speakerName || "Speaker"} size={34} />
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-sm font-bold">{q.speakerName || "Speaker"}</div>
                    {q.createdAt && <div className="text-[11px] text-muted">{timeAgo(q.createdAt)}</div>}
                  </div>
                  <Pill color={answered ? "#22C55E" : "#F59E0B"}>{answered ? "Answered" : "Awaiting answer"}</Pill>
                </div>
                <div className="mt-3 whitespace-pre-wrap font-semibold">{q.question}</div>
                {answered && (
                  <div className="mt-2.5 rounded-xl bg-[#22C55E]/10 p-3">
                    <div className="text-[10.5px] font-bold tracking-wider text-[#22C55E]">ANSWER</div>
                    <div className="mt-1 whitespace-pre-wrap text-sm">{q.answer}</div>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </Page>
  );
}

/* ------------------------------------------------------------------ */
/* Polls                                                               */
/* ------------------------------------------------------------------ */

function PollCard({ p, number, onVoted }: { p: any; number: number; onVoted: (poll: any) => void }) {
  const toast = useToast();
  const [selected, setSelected] = useState<number | null>(null);
  const [sending, setSending] = useState(false);
  const options: string[] = p.options ?? [];
  const myVote = p.myVote === null || p.myVote === undefined ? null : Number(p.myVote);
  const voted = myVote !== null;
  const session = String(p.sessionName ?? "");
  const date = parseDate(p.date);

  const vote = async () => {
    if (selected === null) return;
    setSending(true);
    const res = await post(`/session-content/${p.scheduleId}/polls/${idOf(p)}/vote`, { option: selected });
    setSending(false);
    if (res.success) onVoted(res.poll ?? { ...p, myVote: selected });
    else toast(res.error || "Could not vote", "error");
  };

  return (
    <div className="card p-5">
      <div className="flex flex-wrap items-center gap-1.5">
        <Pill color="#8B5CF6">#{number}</Pill>
        {session.toLowerCase().includes("keynote") && <Pill color="#F59E0B">Keynote</Pill>}
      </div>
      <div className="mt-2 flex items-center gap-2.5">
        <Avatar src={p.speakerPhoto} name={p.speakerName} size={34} />
        <div className="min-w-0 flex-1">
          <div className="truncate text-sm font-bold">{session}</div>
          <div className="truncate text-xs text-muted">
            {p.speakerName}
            {date ? ` · ${fmtDate(date)}` : ""}
          </div>
        </div>
      </div>
      <div className="mt-3 font-semibold">{p.question}</div>
      <div className="mt-2.5 space-y-1.5">
        {options.map((o, i) => {
          const chosen = voted ? myVote === i : selected === i;
          return (
            <button
              key={i}
              disabled={voted}
              onClick={() => setSelected(i)}
              className="flex w-full items-center gap-2 rounded-lg border px-3 py-2.5 text-left text-sm disabled:cursor-default"
              style={{
                borderColor: chosen ? "#8B5CF6" : "rgba(255,255,255,0.1)",
                background: chosen ? "rgba(139,92,246,0.15)" : undefined,
              }}
            >
              <Icon
                name={chosen ? "radio_button_checked" : "radio_button_unchecked"}
                size={18}
                color={chosen ? "#A78BFA" : "#6B7280"}
              />
              {o}
            </button>
          );
        })}
      </div>
      <div className="mt-3 flex items-center gap-2">
        <span className="flex-1 text-xs font-semibold" style={{ color: voted ? "#22C55E" : "#9CA3AF" }}>
          {voted ? "Your vote is recorded" : "Voting open"}
        </span>
        {!voted && (
          <Button small icon="how_to_vote" loading={sending} disabled={selected === null} onClick={vote}>
            Submit Vote
          </Button>
        )}
      </div>
    </div>
  );
}

/** Polls: every speaker poll on the participant's sessions. */
export function ParticipantPolls() {
  return useAppLayout() ? <ParticipantPollsApp /> : <ParticipantPollsWeb />;
}

function ParticipantPollsWeb() {
  const [polls, setPolls] = useState<any[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pendingOnly, setPendingOnly] = useState(false);
  const load = useCallback(async () => {
    const res = await get("/speaker-questions/session-polls");
    if (!res.success) return setError(res.error || "Could not load polls");
    setError(null);
    setPolls(res.polls ?? []);
  }, []);
  useEffect(() => {
    load();
  }, [load]);

  const pending = (polls ?? []).filter((p) => p.myVote == null).length;
  const shown = pendingOnly ? (polls ?? []).filter((p) => p.myVote == null) : (polls ?? []);

  return (
    <Page title="Polls" back={false}>
      <div className="flex flex-wrap items-center gap-4 rounded-xl border border-line bg-gradient-to-br from-[#4C1D95] to-card px-6 py-5">
        <span className="flex h-12 w-12 items-center justify-center rounded-lg bg-white/10">
          <Icon name="how_to_vote" size={26} />
        </span>
        <div className="min-w-0 flex-1">
          <div className="text-lg font-semibold">Your Voice Matters</div>
          <div className="text-sm text-white/70">Make your voice count!</div>
        </div>
        {pending > 0 && (
          <button
            onClick={() => setPendingOnly((p) => !p)}
            className="rounded-lg border border-[#FBBF24]/40 bg-[#FBBF24]/10 px-4 py-2.5 text-left transition hover:bg-[#FBBF24]/15"
          >
            <span className="block text-sm font-semibold text-[#FBBF24]">
              {pending === 1 ? "1 Poll Waiting for Your Vote" : `${pending} Polls Waiting for Your Vote`}
            </span>
            <span className="block text-xs text-white/70">
              {pendingOnly ? "Showing only these — click to show all" : "Click to show only these"}
            </span>
          </button>
        )}
      </div>
      <div className="mt-6">
        {error ? (
          <ErrorState message={error} onRetry={load} />
        ) : !polls ? (
          <Loading />
        ) : polls.length === 0 ? (
          <Empty icon="poll" title="No polls from speakers yet" />
        ) : shown.length === 0 ? (
          <Empty icon="check_circle" title="You have voted on every poll" />
        ) : (
          <div className="grid gap-4 md:grid-cols-2">
            {shown.map((p, i) => (
              <PollCard
                key={idOf(p)}
                p={p}
                number={i + 1}
                onVoted={(np) =>
                  setPolls((l) =>
                    (l ?? []).map((x) => (idOf(x) === idOf(p) ? { ...x, ...np, myVote: np.myVote ?? x.myVote } : x)),
                  )
                }
              />
            ))}
          </div>
        )}
      </div>
      {pendingOnly && (
        <div className="mt-5 flex justify-center">
          <Button variant="outline" onClick={() => setPendingOnly(false)}>
            View All Polls
          </Button>
        </div>
      )}
    </Page>
  );
}
