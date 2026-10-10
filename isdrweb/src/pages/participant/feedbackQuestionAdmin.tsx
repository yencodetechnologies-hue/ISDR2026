import { useCallback, useEffect, useState } from "react";
import { Button, Icon, Modal, useConfirm, useToast } from "@/components/ui";
import { del, get, post, put } from "@/lib/api";
import type { FeedbackQuestion } from "./conferenceFeedback";

const emptyDraft = {
  section: "",
  prompt: "",
  type: "choice" as "choice" | "text",
  required: true,
  multiline: false,
  optionsText: "Excellent\nVery good\nGood\nFair\nPoor",
};

/** Admin: add, edit, delete and reorder the conference feedback questions. */
export function FeedbackQuestionManager({ onChanged }: { onChanged?: () => void }) {
  const toast = useToast();
  const confirm = useConfirm();
  const [questions, setQuestions] = useState<FeedbackQuestion[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [draft, setDraft] = useState<typeof emptyDraft | null>(null);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    const r = await get("/certificates/questions");
    if (r.success) {
      setQuestions(r.questions ?? []);
      setError(null);
    } else setError(r.error || "Could not load questions");
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const apply = (r: { success?: boolean; questions?: FeedbackQuestion[]; error?: string }, done: string) => {
    if (r.success) {
      setQuestions(r.questions ?? []);
      toast(done, "success");
      onChanged?.();
      return true;
    }
    toast(r.error || "Could not save", "error");
    return false;
  };

  const move = async (index: number, dir: -1 | 1) => {
    if (!questions) return;
    const next = questions.slice();
    const target = index + dir;
    if (target < 0 || target >= next.length) return;
    const [item] = next.splice(index, 1);
    next.splice(target, 0, item);
    const r = await put("/certificates/questions/reorder", {
      questionIds: next.map((q) => q.questionId),
    });
    apply(r, "Order updated");
  };

  const remove = async (q: FeedbackQuestion) => {
    if (
      !(await confirm({
        title: "Delete question",
        message: "Participants will no longer be asked this. Answers already submitted stay on file.",
        confirm: "Delete",
        danger: true,
      }))
    )
      return;
    const r = await del(`/certificates/questions/${q.questionId}`);
    apply(r, "Question deleted");
  };

  const openNew = () => {
    setEditingId(null);
    setDraft({ ...emptyDraft });
  };

  const openEdit = (q: FeedbackQuestion) => {
    setEditingId(q.questionId || null);
    setDraft({
      section: q.section,
      prompt: q.prompt,
      type: q.type,
      required: q.required !== false,
      multiline: Boolean(q.multiline),
      optionsText: (q.options || []).join("\n"),
    });
  };

  const save = async () => {
    if (!draft) return;
    setSaving(true);
    const body = {
      section: draft.section,
      prompt: draft.prompt,
      type: draft.type,
      required: draft.required,
      multiline: draft.type === "text" && draft.multiline,
      options: draft.type === "choice" ? draft.optionsText.split("\n") : [],
    };
    const r = editingId
      ? await put(`/certificates/questions/${editingId}`, body)
      : await post("/certificates/questions", body);
    setSaving(false);
    if (apply(r, editingId ? "Question updated" : "Question added")) setDraft(null);
  };

  return (
    <div>
      <div className="mb-3 flex items-center gap-3">
        <div className="min-w-0 flex-1 text-sm text-muted">
          Participants see this list after their certificate is enabled. Numbers follow the order here.
        </div>
        <Button small icon="add" onClick={openNew}>
          Add question
        </Button>
      </div>
      {error ? (
        <div className="py-8 text-center text-sm text-muted">{error}</div>
      ) : !questions ? (
        <div className="py-8 text-center text-sm text-muted">Loading questions…</div>
      ) : questions.length === 0 ? (
        <div className="py-8 text-center text-sm text-muted">No questions yet</div>
      ) : (
        <div className="space-y-2">
          {questions.map((q, index) => (
            <div key={q.questionId || q.id} className="rounded-xl border border-white/10 bg-white/[0.03] px-3 py-3">
              <div className="flex items-start gap-2">
                <div className="min-w-0 flex-1">
                  <div className="text-[11px] font-semibold uppercase tracking-wide text-muted">
                    {q.number}. {q.section}
                    {q.required ? " · Required" : ""}
                    {q.type === "choice" ? " · Choice" : q.multiline ? " · Paragraph" : " · Short answer"}
                  </div>
                  <div className="mt-1 text-sm">{q.prompt}</div>
                  {q.type === "choice" && (
                    <div className="mt-1 text-xs text-muted">{(q.options || []).join(" · ")}</div>
                  )}
                </div>
                <button title="Move up" disabled={index === 0} onClick={() => move(index, -1)} className="text-muted disabled:opacity-30">
                  <Icon name="arrow_upward" size={18} />
                </button>
                <button
                  title="Move down"
                  disabled={index === questions.length - 1}
                  onClick={() => move(index, 1)}
                  className="text-muted disabled:opacity-30"
                >
                  <Icon name="arrow_downward" size={18} />
                </button>
                <button title="Edit" onClick={() => openEdit(q)} className="text-accent">
                  <Icon name="edit" size={18} color="#3B82F6" />
                </button>
                <button title="Delete" onClick={() => remove(q)} className="text-[#F87171]">
                  <Icon name="delete" size={18} color="#F87171" />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      <Modal open={draft != null} onClose={() => setDraft(null)} title={editingId ? "Edit question" : "Add question"} width={560}>
        {draft && (
          <div className="space-y-3">
            <label className="block text-sm">
              <span className="text-muted">Section</span>
              <input
                value={draft.section}
                onChange={(e) => setDraft({ ...draft, section: e.target.value })}
                className="mt-1 w-full rounded-lg border border-white/10 bg-field px-3 py-2 outline-none"
              />
            </label>
            <label className="block text-sm">
              <span className="text-muted">Question</span>
              <textarea
                value={draft.prompt}
                rows={3}
                onChange={(e) => setDraft({ ...draft, prompt: e.target.value })}
                className="mt-1 w-full rounded-lg border border-white/10 bg-field px-3 py-2 outline-none"
              />
            </label>
            <label className="block text-sm">
              <span className="text-muted">Type</span>
              <select
                value={draft.type === "text" && draft.multiline ? "paragraph" : draft.type}
                onChange={(e) => {
                  const value = e.target.value;
                  setDraft({
                    ...draft,
                    type: value === "choice" ? "choice" : "text",
                    multiline: value === "paragraph",
                  });
                }}
                className="mt-1 w-full rounded-lg border border-white/10 bg-field px-3 py-2 outline-none"
              >
                <option value="choice">Choice</option>
                <option value="text">Short answer</option>
                <option value="paragraph">Paragraph</option>
              </select>
            </label>
            {draft.type === "choice" && (
              <label className="block text-sm">
                <span className="text-muted">Options, one per line</span>
                <textarea
                  value={draft.optionsText}
                  rows={5}
                  onChange={(e) => setDraft({ ...draft, optionsText: e.target.value })}
                  className="mt-1 w-full rounded-lg border border-white/10 bg-field px-3 py-2 outline-none"
                />
              </label>
            )}
            <label className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={draft.required}
                onChange={(e) => setDraft({ ...draft, required: e.target.checked })}
              />
              Required
            </label>
            <div className="flex justify-end gap-2 pt-1">
              <Button variant="outline" onClick={() => setDraft(null)}>
                Cancel
              </Button>
              <Button loading={saving} onClick={save}>
                Save
              </Button>
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
}
