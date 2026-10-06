/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { AppBar, Avatar, Icon, Spinner, useToast } from "@/components/ui";
import { AppSpinner } from "@/components/app/AppControls";
import { get, post } from "@/lib/api";
import { fmtDate, idOf, parseDate, timeAgo } from "@/lib/format";

/* ------------------------------------------------------------------ */
/* 1. Participant Q/A Hub (Screen 15A)                                */
/* ------------------------------------------------------------------ */

export function ParticipantQaApp() {
  const navigate = useNavigate();
  const toast = useToast();
  const [questions, setQuestions] = useState<any[] | null>(null);
  const [published, setPublished] = useState<any[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [pendingOnly, setPendingOnly] = useState(false);
  const [answeringId, setAnsweringId] = useState<string | null>(null);
  const [answerText, setAnswerText] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const load = useCallback(async () => {
    const [res, pub] = await Promise.all([
      get("/speaker-questions/session-questions"),
      get("/speaker-questions/public"),
    ]);
    if (!res.success) return setError(res.error || "Could not load questions");
    setError(null);
    setQuestions(res.questions ?? []);
    setPublished(pub.success ? (pub.questions ?? []) : []);
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const submitAnswer = async (q: any) => {
    const t = answerText.trim();
    if (!t) return;
    setSubmitting(true);
    const res = await post(`/session-content/${q.scheduleId}/questions/${idOf(q)}/answer`, { text: t });
    setSubmitting(false);
    if (res.success) {
      toast("Answer submitted successfully", "success");
      setAnsweringId(null);
      setAnswerText("");
      setQuestions((l) => (l ?? []).map((x) => (idOf(x) === idOf(q) ? { ...x, myAnswer: t } : x)));
    } else {
      toast(res.error || "Could not submit answer", "error");
    }
  };

  const pendingCount = (questions ?? []).filter((q) => q.myAnswer == null).length;
  const shown = pendingOnly
    ? (questions ?? []).filter((q) => q.myAnswer == null)
    : (questions ?? []);

  return (
    <div className="min-h-screen bg-[#070B1F] text-white pb-20">
      <AppBar title="Q/A" outfit titleClassName="!text-left font-outfit text-[18px] font-bold" />

      <div className="px-4 pt-3 pb-8 space-y-4">
        {/* Action Cards (Ask a Speaker & My Questions) */}
        <div className="grid grid-cols-2 gap-2.5">
          <div
            onClick={() => navigate("/participant/qa/ask")}
            className="cursor-pointer rounded-[18px] border border-[#8B5CF6]/50 bg-gradient-to-br from-[#3B1780] to-[#1E1B6B] p-3.5 shadow-md active:scale-[0.98]"
          >
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br from-[#A855F7] to-[#7C3AED] text-white">
              <Icon name="mic" size={22} />
            </div>
            <div className="mt-3 font-outfit text-[15px] font-bold text-white">Ask a Speaker</div>
            <div className="text-[11px] text-white/70">Send your question</div>
          </div>

          <div
            onClick={() => navigate("/participant/qa/mine")}
            className="cursor-pointer rounded-[18px] border border-[#22D3EE]/50 bg-gradient-to-br from-[#0E3B66] to-[#12235E] p-3.5 shadow-md active:scale-[0.98]"
          >
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br from-[#06B6D4] to-[#2563EB] text-white">
              <Icon name="mark_chat_read" size={22} />
            </div>
            <div className="mt-3 font-outfit text-[15px] font-bold text-white">My Questions</div>
            <div className="text-[11px] text-white/70">View your answers</div>
          </div>
        </div>

        {published.length > 0 && (
          <div className="space-y-2.5">
            <div className="font-outfit text-base font-bold text-white">Speaker Q&A</div>
            {published.map((q) => (
              <div key={idOf(q)} className="rounded-[16px] border border-white/[0.08] bg-[#14141F] p-4">
                <div className="flex items-center gap-2.5">
                  <Avatar src={q.speakerPhoto} name={q.speakerName || "Speaker"} size={34} />
                  <div className="truncate font-outfit text-sm font-bold">{q.speakerName || "Speaker"}</div>
                </div>
                <div className="mt-3 whitespace-pre-wrap font-inter text-[13.5px] font-semibold">{q.question}</div>
                <div className="mt-3 rounded-xl border border-green-500/20 bg-green-500/[0.08] p-3.5">
                  <div className="font-inter text-[10px] font-extrabold tracking-wider text-[#22C55E]">ANSWER</div>
                  <div className="mt-1 whitespace-pre-wrap font-inter text-xs">{q.answer}</div>
                </div>
              </div>
            ))}
          </div>
        )}

        {/* Section Title & Filter Chips */}
        <div className="flex items-center justify-between pt-1">
          <div className="flex items-center gap-2">
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-gradient-to-br from-[#3B82F6] to-[#7C3AED]">
              <Icon name="forum" size={16} />
            </div>
            <span className="font-outfit text-base font-bold text-white">Questions for You</span>
            {pendingCount > 0 && (
              <span className="rounded-full bg-[#F59E0B]/20 px-2 py-0.5 font-inter text-[10px] font-extrabold text-[#FBBF24]">
                {pendingCount} TO ANSWER
              </span>
            )}
          </div>

          <div className="flex gap-1.5">
            <button
              onClick={() => setPendingOnly(false)}
              className={`rounded-full px-3 py-1 font-inter text-xs font-bold transition ${
                !pendingOnly ? "bg-[#3B82F6] text-white" : "bg-white/[0.06] text-muted hover:text-white"
              }`}
            >
              All
            </button>
            <button
              onClick={() => setPendingOnly(true)}
              className={`rounded-full px-3 py-1 font-inter text-xs font-bold transition ${
                pendingOnly ? "bg-[#3B82F6] text-white" : "bg-white/[0.06] text-muted hover:text-white"
              }`}
            >
              Pending
            </button>
          </div>
        </div>

        {/* Question Cards List */}
        {!questions && !error ? (
          <div className="py-20">
            <AppSpinner />
          </div>
        ) : error || shown.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-20 text-center">
            <Icon name="question_answer" size={40} color="#9CA3AF" />
            <div className="mt-3 font-outfit text-base font-bold">
              {error || (pendingOnly ? "No pending questions" : "No questions from speakers yet")}
            </div>
          </div>
        ) : (
          <div className="space-y-3">
            {shown.map((q) => {
              const myAnswer: string | undefined = q.myAnswer ?? undefined;
              const date = parseDate(q.date);
              const isAnswering = answeringId === idOf(q);

              return (
                <div
                  key={idOf(q)}
                  className="rounded-[16px] border border-white/[0.08] bg-[#14141F] p-4 shadow-sm"
                >
                  <div className="flex items-center gap-2.5">
                    <Avatar src={q.speakerPhoto} name={q.speakerName || "Speaker"} size={36} />
                    <div className="min-w-0 flex-1">
                      <div className="truncate font-outfit text-sm font-bold text-white">{q.speakerName || "Speaker"}</div>
                      <div className="truncate font-inter text-xs text-muted">
                        {q.sessionName}
                        {date ? ` · ${fmtDate(date)}` : ""}
                      </div>
                    </div>
                    {myAnswer ? (
                      <span className="shrink-0 rounded-full bg-green-500/15 px-2 py-0.5 font-inter text-[10px] font-extrabold text-[#22C55E]">
                        Answered
                      </span>
                    ) : (
                      <span className="shrink-0 font-inter text-[10.5px] text-muted">
                        {q.createdAt ? `Asked ${timeAgo(q.createdAt)}` : ""}
                      </span>
                    )}
                  </div>

                  <div className="mt-3 font-inter text-[13.5px] font-semibold text-white/90">
                    {q.question}
                  </div>

                  {myAnswer ? (
                    <div className="mt-3 rounded-xl border border-green-500/20 bg-green-500/[0.06] p-3">
                      <div className="font-inter text-[10px] font-extrabold tracking-wider text-[#22C55E]">
                        YOUR ANSWER
                      </div>
                      <div className="mt-1 whitespace-pre-wrap font-inter text-xs text-white/90">{myAnswer}</div>
                    </div>
                  ) : isAnswering ? (
                    <div className="mt-3 space-y-2">
                      <textarea
                        rows={3}
                        value={answerText}
                        onChange={(e) => setAnswerText(e.target.value)}
                        placeholder="Type your answer here..."
                        className="w-full rounded-xl border border-white/10 bg-[#0A0A12] p-3 font-inter text-xs text-white placeholder:text-muted focus:border-[#3B82F6] focus:outline-none"
                      />
                      <div className="flex justify-end gap-2">
                        <button
                          onClick={() => {
                            setAnsweringId(null);
                            setAnswerText("");
                          }}
                          className="rounded-lg px-3 py-1.5 font-inter text-xs text-muted hover:text-white"
                        >
                          Cancel
                        </button>
                        <button
                          onClick={() => submitAnswer(q)}
                          disabled={submitting || !answerText.trim()}
                          className="flex items-center gap-1.5 rounded-lg bg-[#3B82F6] px-3.5 py-1.5 font-inter text-xs font-bold text-white disabled:opacity-50"
                        >
                          {submitting ? <Spinner size={14} color="#fff" /> : "Submit"}
                        </button>
                      </div>
                    </div>
                  ) : (
                    <button
                      onClick={() => {
                        setAnsweringId(idOf(q));
                        setAnswerText("");
                      }}
                      className="mt-3 flex w-full items-center justify-center gap-1.5 rounded-xl border border-[#3B82F6]/30 bg-[#3B82F6]/10 py-2 font-inter text-xs font-bold text-[#60A5FA] active:bg-[#3B82F6]/20"
                    >
                      <Icon name="edit" size={16} />
                      Write Answer
                    </button>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Bottom Bar: View All Polls & Q/A */}
      <div className="fixed inset-x-0 bottom-0 z-30 border-t border-white/[0.08] bg-[#070B1F] p-3 pb-[env(safe-area-inset-bottom)]">
        <button
          onClick={() => navigate("/participant/polls")}
          className="flex h-11 w-full items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-[#2563EB] to-[#7C3AED] font-outfit text-sm font-bold text-white shadow-lg active:scale-[0.99]"
        >
          <Icon name="poll" size={20} />
          View All Polls &amp; Q/A
        </button>
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* 2. Ask a Speaker (Screen 15B)                                      */
/* ------------------------------------------------------------------ */

export function AskSpeakerApp() {
  const navigate = useNavigate();
  const toast = useToast();
  const [speakers, setSpeakers] = useState<any[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [selectedSpeaker, setSelectedSpeaker] = useState<any>(null);
  const [question, setQuestion] = useState("");
  const [sending, setSending] = useState(false);

  useEffect(() => {
    get("/speaker-questions/speakers").then((r) => {
      if (r.success) setSpeakers(r.speakers ?? []);
      else setError(r.error || "Could not load speakers");
    });
  }, []);

  const submitQuestion = async () => {
    const q = question.trim();
    if (!q || !selectedSpeaker) return;
    setSending(true);
    const res = await post("/speaker-questions", {
      speakerId: idOf(selectedSpeaker),
      question: q,
    });
    setSending(false);
    if (!res.success) return toast(res.error || "Could not send question", "error");
    setSelectedSpeaker(null);
    setQuestion("");
    toast("Question sent to speaker", "success");
    navigate("/participant/qa/mine", { replace: true });
  };

  return (
    <div className="min-h-screen bg-[#070B1F] text-white">
      <AppBar title="Ask a Speaker" outfit titleClassName="!text-left font-outfit text-[18px] font-bold" />
      <div className="px-4 pb-12 pt-2">
        <div className="mb-3 text-xs text-muted">
          Choose a speaker the admin has opened for questions.
        </div>

        {!speakers && !error ? (
          <div className="py-24">
            <AppSpinner />
          </div>
        ) : error || !speakers || speakers.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-28 text-center">
            <Icon name="groups" size={44} color="#9CA3AF" />
            <div className="mt-3 font-outfit text-base font-bold">{error || "No speakers are open for questions"}</div>
          </div>
        ) : (
          <div className="space-y-2.5">
            {speakers.map((s) => (
              <div
                key={idOf(s)}
                onClick={() => setSelectedSpeaker(s)}
                className="group flex cursor-pointer items-center gap-3.5 rounded-[16px] border border-white/[0.08] bg-[#14141F] p-3.5 transition hover:bg-white/[0.04] active:scale-[0.99]"
              >
                <Avatar src={s.photo} name={s.name} size={48} />
                <div className="min-w-0 flex-1">
                  <div className="truncate font-outfit text-[15px] font-bold text-white group-hover:text-[#60A5FA]">
                    {s.name}
                  </div>
                  {(s.designation || s.institution) && (
                    <div className="mt-0.5 truncate font-inter text-xs text-muted">
                      {[s.designation, s.institution].filter(Boolean).join(" · ")}
                    </div>
                  )}
                </div>
                <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-[#3B82F6]/15 text-[#3B82F6]">
                  <Icon name="send" size={18} />
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Ask Question Sheet / Modal */}
      {selectedSpeaker && (
        <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/70 p-0 sm:items-center sm:p-4">
          <div className="w-full max-w-lg rounded-t-[24px] border border-white/10 bg-[#14141F] p-5 sm:rounded-[24px]">
            <div className="flex items-center justify-between pb-3">
              <div className="flex items-center gap-3">
                <Avatar src={selectedSpeaker.photo} name={selectedSpeaker.name} size={36} />
                <div>
                  <div className="font-outfit text-base font-bold text-white">Ask {selectedSpeaker.name}</div>
                  <div className="font-inter text-xs text-muted">
                    It goes to the admin. Everyone sees it only after it is published.
                  </div>
                </div>
              </div>
              <button
                onClick={() => setSelectedSpeaker(null)}
                className="flex h-8 w-8 items-center justify-center rounded-full bg-white/10 text-white"
              >
                <Icon name="close" size={18} />
              </button>
            </div>

            <textarea
              rows={4}
              value={question}
              onChange={(e) => setQuestion(e.target.value)}
              placeholder="What would you like to ask this speaker?"
              className="mt-2 w-full rounded-xl border border-white/10 bg-[#0A0A12] p-3.5 font-inter text-sm text-white placeholder:text-muted focus:border-[#3B82F6] focus:outline-none"
            />

            <div className="mt-4 flex gap-2">
              <button
                onClick={() => setSelectedSpeaker(null)}
                className="flex-1 rounded-xl border border-white/10 py-3 font-inter text-xs font-bold text-muted hover:text-white"
              >
                Cancel
              </button>
              <button
                onClick={submitQuestion}
                disabled={sending || !question.trim()}
                className="flex flex-1 items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-[#2563EB] to-[#7C3AED] py-3 font-inter text-xs font-bold text-white disabled:opacity-50"
              >
                {sending ? <Spinner size={16} color="#fff" /> : "Send Question"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* 3. My Questions (Screen 15C)                                       */
/* ------------------------------------------------------------------ */

export function MyQuestionsApp() {
  const [questions, setQuestions] = useState<any[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    get("/speaker-questions/mine").then((r) => {
      if (r.success) setQuestions(r.questions ?? []);
      else setError(r.error || "Could not load questions");
    });
  }, []);

  return (
    <div className="min-h-screen bg-[#070B1F] text-white">
      <AppBar title="My Questions" outfit titleClassName="!text-left font-outfit text-[18px] font-bold" />
      <div className="px-4 pb-12 pt-2">
        {!questions && !error ? (
          <div className="py-24">
            <AppSpinner />
          </div>
        ) : error || !questions || questions.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-28 text-center">
            <Icon name="mark_chat_read" size={44} color="#9CA3AF" />
            <div className="mt-3 font-outfit text-base font-bold">{error || "No questions asked yet"}</div>
            <div className="mt-1 font-inter text-xs text-muted">
              Questions you send to speakers will appear here with their replies.
            </div>
          </div>
        ) : (
          <div className="space-y-3">
            {questions.map((q) => {
              const answered = !!q.answer;
              return (
                <div
                  key={idOf(q)}
                  className="rounded-[16px] border border-white/[0.08] bg-[#14141F] p-4 shadow-sm"
                >
                  <div className="flex items-center gap-2.5">
                    <Avatar src={q.speakerPhoto} name={q.speakerName || "Speaker"} size={34} />
                    <div className="min-w-0 flex-1">
                      <div className="truncate font-outfit text-sm font-bold text-white">{q.speakerName || "Speaker"}</div>
                      {q.createdAt && (
                        <div className="font-inter text-[11px] text-muted">{timeAgo(q.createdAt)}</div>
                      )}
                    </div>
                    <span
                      className="shrink-0 rounded-full px-2.5 py-0.5 font-inter text-[10px] font-extrabold"
                      style={{
                        background: answered ? "rgba(34,197,94,0.18)" : "rgba(245,158,11,0.18)",
                        color: answered ? "#22C55E" : "#F59E0B",
                      }}
                    >
                      {answered ? "Answered" : "Awaiting reply"}
                    </span>
                  </div>

                  <div className="mt-3 font-inter text-[13.5px] font-semibold text-white/90 whitespace-pre-wrap">
                    {q.question}
                  </div>

                  {answered && (
                    <div className="mt-3 rounded-xl border border-green-500/20 bg-green-500/[0.08] p-3.5">
                      <div className="font-inter text-[10px] font-extrabold tracking-wider text-[#22C55E]">
                        SPEAKER'S ANSWER
                      </div>
                      <div className="mt-1 font-inter text-xs text-white/95 whitespace-pre-wrap">
                        {q.answer}
                      </div>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* 4. Polls (Screen 16)                                               */
/* ------------------------------------------------------------------ */

export function ParticipantPollsApp() {
  const toast = useToast();
  const [polls, setPolls] = useState<any[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pendingOnly, setPendingOnly] = useState(false);
  const [votingId, setVotingId] = useState<string | null>(null);
  const [selectedOption, setSelectedOption] = useState<Record<string, number>>({});

  const load = useCallback(async () => {
    const res = await get("/speaker-questions/session-polls");
    if (!res.success) return setError(res.error || "Could not load polls");
    setError(null);
    setPolls(res.polls ?? []);
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const vote = async (p: any) => {
    const pollId = idOf(p);
    const optIndex = selectedOption[pollId];
    if (optIndex === undefined || optIndex === null) return;
    setVotingId(pollId);
    const res = await post(`/session-content/${p.scheduleId}/polls/${pollId}/vote`, { option: optIndex });
    setVotingId(null);
    if (res.success) {
      toast("Vote recorded!", "success");
      setPolls((l) =>
        (l ?? []).map((x) => (idOf(x) === pollId ? res.poll ?? { ...x, myVote: optIndex } : x))
      );
    } else {
      toast(res.error || "Could not vote", "error");
    }
  };

  const pendingCount = (polls ?? []).filter((p) => p.myVote == null).length;
  const shown = pendingOnly
    ? (polls ?? []).filter((p) => p.myVote == null)
    : (polls ?? []);

  return (
    <div className="min-h-screen bg-[#070B1F] text-white">
      <AppBar title="Polls" outfit titleClassName="!text-left font-outfit text-[18px] font-bold" />
      <div className="px-4 pb-12 pt-3 space-y-4">
        {/* Waiting for Vote Banner matching Flutter */}
        {pendingCount > 0 && (
          <div
            onClick={() => setPendingOnly((prev) => !prev)}
            className="flex cursor-pointer items-center gap-3.5 rounded-[18px] border border-[#60A5FA]/70 bg-gradient-to-r from-[#6D28D9] to-[#1D4ED8] p-3.5 shadow-lg active:scale-[0.99]"
          >
            <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-white/10 text-[#7DD3FC]">
              <Icon name="how_to_vote" size={26} />
            </div>
            <div className="min-w-0 flex-1">
              <div className="font-outfit text-base font-bold text-white">
                {pendingCount === 1 ? "1 Poll Waiting for Your Vote" : `${pendingCount} Polls Waiting for Your Vote`}
              </div>
              <div className="font-inter text-xs text-white/85">
                {pendingOnly ? "Showing only these — tap to show all" : "Make your voice count!"}
              </div>
            </div>
            <Icon name={pendingOnly ? "close" : "chevron_right"} size={22} color="#ffffff" />
          </div>
        )}

        {/* Polls List */}
        {!polls && !error ? (
          <div className="py-24">
            <AppSpinner />
          </div>
        ) : error || shown.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-28 text-center">
            <Icon name="poll" size={44} color="#9CA3AF" />
            <div className="mt-3 font-outfit text-base font-bold">
              {error || (pendingOnly ? "No pending polls left" : "No polls available")}
            </div>
          </div>
        ) : (
          <div className="space-y-4">
            {shown.map((p, idx) => {
              const pollId = idOf(p);
              const options: string[] = p.options ?? [];
              const myVote = p.myVote === null || p.myVote === undefined ? null : Number(p.myVote);
              const voted = myVote !== null;
              const curSelected = selectedOption[pollId];
              const isVoting = votingId === pollId;

              return (
                <div
                  key={pollId}
                  className="rounded-[18px] border border-white/[0.08] bg-[#14141F] p-4 shadow-sm"
                >
                  <div className="flex items-center justify-between">
                    <span className="rounded-md bg-[#8B5CF6]/20 px-2 py-0.5 font-inter text-[11px] font-extrabold text-[#A78BFA]">
                      #{idx + 1}
                    </span>
                    <span
                      className="font-inter text-[11px] font-bold"
                      style={{ color: voted ? "#22C55E" : "#60A5FA" }}
                    >
                      {voted ? "Voted" : "Open for voting"}
                    </span>
                  </div>

                  <div className="mt-2.5 font-outfit text-[15px] font-bold text-white">{p.question}</div>

                  {p.sessionName && (
                    <div className="mt-1 font-inter text-xs text-muted">
                      {p.sessionName} {p.speakerName ? ` · ${p.speakerName}` : ""}
                    </div>
                  )}

                  {/* Options */}
                  <div className="mt-3.5 space-y-2">
                    {options.map((opt, i) => {
                      const isChosen = voted ? myVote === i : curSelected === i;
                      return (
                        <button
                          key={i}
                          disabled={voted}
                          onClick={() => setSelectedOption((prev) => ({ ...prev, [pollId]: i }))}
                          className={`flex w-full items-center gap-2.5 rounded-xl border p-3 text-left font-inter text-xs font-semibold transition ${
                            isChosen
                              ? "border-[#8B5CF6] bg-[#8B5CF6]/20 text-white"
                              : "border-white/[0.08] bg-white/[0.02] text-white/80 hover:bg-white/[0.05]"
                          }`}
                        >
                          <Icon
                            name={isChosen ? "radio_button_checked" : "radio_button_unchecked"}
                            size={18}
                            color={isChosen ? "#A78BFA" : "#6B7280"}
                          />
                          <span className="flex-1">{opt}</span>
                        </button>
                      );
                    })}
                  </div>

                  {!voted && (
                    <div className="mt-3.5 flex justify-end">
                      <button
                        onClick={() => vote(p)}
                        disabled={curSelected === undefined || isVoting}
                        className="flex items-center gap-1.5 rounded-xl bg-[#3B82F6] px-4 py-2 font-inter text-xs font-bold text-white shadow disabled:opacity-50"
                      >
                        {isVoting ? <Spinner size={14} color="#fff" /> : "Submit Vote"}
                      </button>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
