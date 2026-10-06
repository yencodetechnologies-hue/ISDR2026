/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import {
  Button,
  Empty,
  ErrorState,
  IconButton,
  Loading,
  Page,
  Pill,
  SearchBox,
  Switch,
  TextArea,
  useConfirm,
  useToast,
} from "@/components/ui";
import { del, get, put } from "@/lib/api";
import { idOf } from "@/lib/format";

/** Questions participants asked one speaker. Search by participant or question, then answer and publish. */
export default function SpeakerQuestions() {
  const { id = "" } = useParams<{ id: string }>();
  const [speakerName, setSpeakerName] = useState("Questions");
  const [items, setItems] = useState<any[] | null>(null);
  const [query, setQuery] = useState("");
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    const [speakers, qs] = await Promise.all([get("/speakers"), get("/engagement/speaker-questions")]);
    if (!qs.success) return setError(qs.error || "Could not load questions");
    const speaker = (speakers.speakers ?? []).find((s: any) => idOf(s) === id);
    setSpeakerName(speaker?.name || "Questions");
    setError(null);
    setItems((qs.questions ?? []).filter((q: any) => String(q.speakerId) === id));
  }, [id]);

  useEffect(() => {
    load();
  }, [load]);

  const term = query.trim().toLowerCase();
  const shown = (items ?? []).filter((q) => {
    if (!term) return true;
    const name = String(q.participantName ?? "").toLowerCase();
    const text = String(q.question ?? "").toLowerCase();
    return name.includes(term) || text.includes(term);
  });

  const groups = new Map<string, any[]>();
  for (const q of shown) {
    const name = String(q.participantName ?? "").trim() || "Participant";
    const list = groups.get(name) ?? [];
    list.push(q);
    groups.set(name, list);
  }

  const updateOne = (next: any) => {
    setItems((list) => (list ?? []).map((x) => (idOf(x) === idOf(next) ? { ...x, ...next } : x)));
  };

  const removeOne = (id: string) => {
    setItems((list) => (list ?? []).filter((x) => idOf(x) !== id));
  };

  return (
    <Page title={speakerName} subtitle="Questions from participants">
      {error ? (
        <ErrorState message={error} onRetry={load} />
      ) : !items ? (
        <Loading />
      ) : items.length === 0 ? (
        <Empty icon="forum" title="No questions for this speaker yet" />
      ) : (
        <>
          <div className="mb-4 w-full sm:w-80">
            <SearchBox value={query} onChange={setQuery} placeholder="Search participant or question…" />
          </div>
          {groups.size === 0 ? (
            <Empty icon="search" title={`No results for "${query.trim()}"`} />
          ) : (
            <div className="space-y-6">
              {[...groups.entries()].map(([name, questions]) => (
                <section key={name}>
                  <div className="mb-2 text-sm font-semibold">{name}</div>
                  <div className="grid gap-3 md:grid-cols-2">
                    {questions.map((q) => (
                      <QuestionCard key={idOf(q)} item={q} onUpdated={updateOne} onDeleted={removeOne} />
                    ))}
                  </div>
                </section>
              ))}
            </div>
          )}
        </>
      )}
    </Page>
  );
}

function QuestionCard({
  item,
  onUpdated,
  onDeleted,
}: {
  item: any;
  onUpdated: (next: any) => void;
  onDeleted: (id: string) => void;
}) {
  const toast = useToast();
  const confirm = useConfirm();
  const [answer, setAnswer] = useState(String(item.answer ?? ""));
  const [saving, setSaving] = useState(false);
  const [publishing, setPublishing] = useState(false);
  const [deleting, setDeleting] = useState(false);

  useEffect(() => {
    setAnswer(String(item.answer ?? ""));
  }, [item.answer]);

  const save = async () => {
    const t = answer.trim();
    if (!t) return toast("Type an answer", "error");
    setSaving(true);
    const r = await put(`/speaker-questions/${idOf(item)}/answer`, { answer: t });
    setSaving(false);
    if (r.success) onUpdated(r.question ?? { ...item, answer: t, answered: true });
    else toast(r.error || "Could not save the answer", "error");
  };

  const togglePublic = async (isPublic: boolean) => {
    setPublishing(true);
    const r = await put(`/speaker-questions/${idOf(item)}/public`, { isPublic });
    setPublishing(false);
    if (r.success) onUpdated(r.question ?? { ...item, isPublic });
    else toast(r.error || "Could not update", "error");
  };

  const remove = async () => {
    if (
      !(await confirm({
        title: "Delete question?",
        message: "The question and its answer will be removed for participants.",
        confirm: "Delete",
        danger: true,
      }))
    )
      return;
    setDeleting(true);
    const r = await del(`/speaker-questions/${idOf(item)}`);
    setDeleting(false);
    if (r.success) {
      toast("Question deleted", "success");
      onDeleted(idOf(item));
    } else toast(r.error || "Could not delete", "error");
  };

  return (
    <div className="card flex flex-col p-5">
      <div className="flex items-center gap-2">
        <span className="flex-1 truncate text-xs text-muted">Question</span>
        <Pill color={item.answered ? "#22C55E" : "#F59E0B"}>{item.answered ? "Answered" : "Unanswered"}</Pill>
        <IconButton
          icon="delete"
          outline
          color="#EF4444"
          title="Delete question"
          disabled={deleting}
          onClick={remove}
        />
      </div>
      <div className="mt-2 whitespace-pre-wrap font-semibold">{item.question}</div>
      <TextArea
        className="mt-3"
        rows={3}
        maxLength={1000}
        value={answer}
        onChange={(e) => setAnswer(e.target.value)}
        placeholder="Type the answer"
      />
      <div className="mt-2 flex justify-end">
        <Button small loading={saving} disabled={!answer.trim()} onClick={save}>
          {item.answered ? "Update answer" : "Save answer"}
        </Button>
      </div>
      <div className="mt-3 flex items-center gap-2 border-t border-line pt-3">
        <Switch checked={item.isPublic === true} disabled={publishing} onChange={togglePublic} />
        <span className="text-xs text-muted">Show to all participants</span>
      </div>
    </div>
  );
}
