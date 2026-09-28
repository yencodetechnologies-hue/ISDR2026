/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { get, post } from "@/lib/api";
import { idOf } from "@/lib/format";
import { Button, Icon, Spinner, TextArea, useToast } from "./ui";

export function StarRow({ value, size = 22, onChange }: { value: number; size?: number; onChange?: (v: number) => void }) {
  return (
    <div className="flex gap-0.5">
      {[1, 2, 3, 4, 5].map((i) => (
        <button key={i} type="button" disabled={!onChange} onClick={() => onChange?.(i)} className="disabled:cursor-default">
          <Icon name="star" outline={i > value} size={size} color={i <= value ? "#F59E0B" : "#6B7280"} />
        </button>
      ))}
    </div>
  );
}

function Group({ title, icon, color, children }: { title: string; icon: string; color: string; children: React.ReactNode }) {
  return (
    <div className="card mt-3 flex gap-3 p-3.5">
      <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full" style={{ background: color }}>
        <Icon name={icon} size={19} color="#fff" />
      </div>
      <div className="min-w-0 flex-1">
        <div className="mb-2 text-[11px] font-bold tracking-wider" style={{ color }}>
          {title}
        </div>
        {children}
      </div>
    </div>
  );
}

function PollCard({ scheduleId, poll, canRespond, onUpdated }: { scheduleId: string; poll: any; canRespond: boolean; onUpdated: (p: any) => void }) {
  const toast = useToast();
  const [selected, setSelected] = useState<number | null>(null);
  const [sending, setSending] = useState(false);
  const options: string[] = poll.options ?? [];
  const myVote = poll.myVote === null || poll.myVote === undefined ? null : Number(poll.myVote);
  const voted = myVote !== null;
  const canVote = canRespond && !voted;

  const vote = async () => {
    if (selected === null) return;
    setSending(true);
    const res = await post(`/session-content/${scheduleId}/polls/${idOf(poll)}/vote`, { option: selected });
    setSending(false);
    if (res.success && res.poll) onUpdated(res.poll);
    else toast(res.error || "Could not vote", "error");
  };

  return (
    <div className="mb-2.5 rounded-xl border border-line bg-field p-3">
      <div className="font-bold">{poll.question}</div>
      <div className="mt-2.5 space-y-1.5">
        {options.map((o, i) => {
          const chosen = voted ? myVote === i : selected === i;
          return (
            <button
              key={i}
              disabled={!canVote}
              onClick={() => setSelected(i)}
              className="flex w-full items-center gap-2 rounded-lg border px-3 py-2 text-left text-sm disabled:cursor-default"
              style={{ borderColor: chosen ? "#3B82F6" : "rgba(255,255,255,0.1)", background: chosen ? "rgba(59,130,246,0.12)" : undefined }}
            >
              <Icon name={chosen ? "radio_button_checked" : "radio_button_unchecked"} size={18} color={chosen ? "#3B82F6" : "#6B7280"} />
              {o}
            </button>
          );
        })}
      </div>
      {voted ? (
        <div className="mt-2 text-xs font-semibold text-[#22C55E]">Thanks — your vote is recorded</div>
      ) : (
        canVote && (
          <div className="mt-2.5 flex justify-end">
            <Button small icon="how_to_vote" loading={sending} disabled={selected === null} onClick={vote}>
              Submit vote
            </Button>
          </div>
        )
      )}
    </div>
  );
}

function QuestionCard({
  scheduleId,
  question,
  canRespond,
  onUpdated,
}: {
  scheduleId: string;
  question: any;
  canRespond: boolean;
  onUpdated: (q: any) => void;
}) {
  const toast = useToast();
  const [text, setText] = useState("");
  const [sending, setSending] = useState(false);
  const myAnswer: string | undefined = question.myAnswer ?? undefined;

  const send = async () => {
    const t = text.trim();
    if (!t) return;
    setSending(true);
    const res = await post(`/session-content/${scheduleId}/questions/${idOf(question)}/answer`, { text: t });
    setSending(false);
    if (res.success && res.question) onUpdated(res.question);
    else toast(res.error || "Could not send answer", "error");
  };

  return (
    <div className="mb-2.5 rounded-xl border border-line bg-field p-3">
      <div className="font-bold">{question.question}</div>
      {myAnswer ? (
        <div className="mt-2 rounded-lg bg-accent/10 p-2.5">
          <div className="text-[10.5px] font-bold tracking-wider text-accent">YOUR ANSWER</div>
          <div className="mt-1 whitespace-pre-wrap text-sm">{myAnswer}</div>
        </div>
      ) : (
        canRespond && (
          <>
            <TextArea className="mt-2" maxLength={1000} value={text} onChange={(e) => setText(e.target.value)} placeholder="Type your answer" />
            <div className="mt-2 flex justify-end">
              <Button small icon="send" loading={sending} disabled={!text.trim()} onClick={send}>
                Submit answer
              </Button>
            </div>
          </>
        )
      )}
    </div>
  );
}

function RateCard({ scheduleId, myRating, onRated }: { scheduleId: string; myRating: any; onRated: (r: any) => void }) {
  const toast = useToast();
  const [stars, setStars] = useState(0);
  const [comment, setComment] = useState("");
  const [sending, setSending] = useState(false);

  if (myRating) {
    return (
      <div>
        <StarRow value={Number(myRating.stars) || 0} size={26} />
        {myRating.comment && <div className="mt-2 whitespace-pre-wrap text-sm text-white/80">“{myRating.comment}”</div>}
        <div className="mt-2 text-xs font-semibold text-[#22C55E]">Thanks for rating this session</div>
      </div>
    );
  }

  const send = async () => {
    if (!stars) return;
    setSending(true);
    const res = await post(`/session-content/${scheduleId}/rating`, { stars, comment: comment.trim() });
    setSending(false);
    if (res.success && res.rating) onRated(res.rating);
    else toast(res.error || "Could not send rating", "error");
  };

  return (
    <div>
      <StarRow value={stars} size={30} onChange={setStars} />
      <TextArea className="mt-2" maxLength={1000} value={comment} onChange={(e) => setComment(e.target.value)} placeholder="Add a comment (optional)" />
      <div className="mt-2 flex items-center gap-2">
        <div className="flex-1 text-xs text-muted">You can rate a session only once.</div>
        <Button small icon="star" loading={sending} disabled={!stars} onClick={send}>
          Submit rating
        </Button>
      </div>
    </div>
  );
}

/**
 * What the speaker added to a session — polls, questions, a rating card for
 * participants, and the ratings list for the session's speaker.
 */
export function SessionContent({ scheduleId }: { scheduleId: string }) {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [data, setData] = useState<any>(null);

  const load = useCallback(async () => {
    const res = await get(`/session-content/${scheduleId}`);
    setLoading(false);
    if (res.success) {
      setError(null);
      setData(res);
    } else setError(res.error || "Could not load session materials");
  }, [scheduleId]);

  useEffect(() => {
    load();
  }, [load]);

  if (loading)
    return (
      <div className="flex justify-center py-6">
        <Spinner />
      </div>
    );
  if (error) return <div className="mt-4 text-sm text-muted">{error}</div>;
  const polls: any[] = data?.polls ?? [];
  const questions: any[] = data?.questions ?? [];
  const canRespond = data?.canRespond === true;
  const isSpeaker = data?.isSpeaker === true;
  const ratings: any[] = data?.ratings ?? [];
  const summary = data?.ratingSummary;
  if (!polls.length && !questions.length && !canRespond && !isSpeaker) return null;

  const update = (key: "polls" | "questions", i: number, v: any) =>
    setData((d: any) => ({ ...d, [key]: d[key].map((x: any, k: number) => (k === i ? v : x)) }));

  return (
    <div>
      {polls.length > 0 && (
        <Group title="POLLS" icon="bar_chart" color="#10B981">
          {polls.map((p, i) => (
            <PollCard key={idOf(p)} scheduleId={scheduleId} poll={p} canRespond={canRespond} onUpdated={(v) => update("polls", i, v)} />
          ))}
        </Group>
      )}
      {questions.length > 0 && (
        <Group title="QUESTIONS" icon="help" color="#3B82F6">
          {questions.map((q, i) => (
            <QuestionCard key={idOf(q)} scheduleId={scheduleId} question={q} canRespond={canRespond} onUpdated={(v) => update("questions", i, v)} />
          ))}
        </Group>
      )}
      {canRespond && (
        <Group title="RATE THIS SESSION" icon="star" color="#F59E0B">
          <RateCard scheduleId={scheduleId} myRating={data?.myRating ?? null} onRated={(r) => setData((d: any) => ({ ...d, myRating: r }))} />
        </Group>
      )}
      {isSpeaker && (
        <Group title="RATINGS & COMMENTS" icon="reviews" color="#F59E0B">
          {!summary || !Number(summary.count) ? (
            <div className="text-sm text-muted">No ratings yet</div>
          ) : (
            <div className="mb-3 flex items-center gap-2">
              <span className="text-2xl font-extrabold">{Number(summary.average).toFixed(1)}</span>
              <StarRow value={Math.round(Number(summary.average))} size={18} />
              <span className="text-xs text-muted">
                {summary.count} rating{Number(summary.count) === 1 ? "" : "s"}
              </span>
            </div>
          )}
          {ratings.map((r, i) => (
            <div key={i} className="border-t border-line py-2.5">
              <div className="flex items-center gap-2">
                <span className="flex-1 text-sm font-semibold">{r.name || "Participant"}</span>
                <StarRow value={Number(r.stars) || 0} size={16} />
              </div>
              {r.comment && <div className="mt-1 whitespace-pre-wrap text-[13px] text-white/75">{r.comment}</div>}
            </div>
          ))}
        </Group>
      )}
    </div>
  );
}
