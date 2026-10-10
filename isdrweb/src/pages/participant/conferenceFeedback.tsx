import { useMemo, useState } from "react";
import { Button, Icon } from "@/components/ui";

export type FeedbackQuestion = {
  id: string;
  questionId?: string;
  number: number;
  section: string;
  prompt: string;
  type: "choice" | "text";
  required?: boolean;
  options?: string[];
  multiline?: boolean;
};

export function ConferenceFeedbackForm({
  questions,
  submitting,
  onSubmit,
}: {
  questions: FeedbackQuestion[];
  submitting: boolean;
  onSubmit: (answers: Record<string, string>) => void;
}) {
  const [answers, setAnswers] = useState<Record<string, string>>({});
  const [error, setError] = useState<string | null>(null);

  const sections = useMemo(() => {
    const order: string[] = [];
    const bySection = new Map<string, FeedbackQuestion[]>();
    for (const q of questions) {
      if (!bySection.has(q.section)) {
        order.push(q.section);
        bySection.set(q.section, []);
      }
      bySection.get(q.section)!.push(q);
    }
    return order.map((section) => ({ section, questions: bySection.get(section)! }));
  }, [questions]);

  const submit = () => {
    const missing = questions.find((q) => q.required && !String(answers[q.id] || "").trim());
    if (missing) {
      setError("Please answer every required question.");
      return;
    }
    setError(null);
    onSubmit(answers);
  };

  return (
    <div className="card mt-6 px-4 py-5 sm:px-5">
      <div className="eyebrow">Conference feedback</div>
      <p className="mt-2 text-sm text-muted">
        Share your feedback to download your certificate. Rating questions are required. Written comments are optional.
      </p>
      {sections.map(({ section, questions: items }) => (
        <div key={section} className="mt-6">
          <div className="text-sm font-semibold text-white">{section}</div>
          <div className="mt-3 space-y-5">
            {items.map((q) => (
              <fieldset key={q.id} className="min-w-0">
                <legend className="text-[13.5px] font-medium leading-snug">
                  {q.number}. {q.prompt}
                  {q.required ? <span className="text-[#F87171]"> *</span> : null}
                </legend>
                {q.type === "choice" ? (
                  <div className="mt-2 flex flex-col gap-1.5">
                    {(q.options || []).map((option) => (
                      <label key={option} className="flex cursor-pointer items-center gap-2 text-sm text-white/90">
                        <input
                          type="radio"
                          name={q.id}
                          value={option}
                          checked={answers[q.id] === option}
                          onChange={() => setAnswers((a) => ({ ...a, [q.id]: option }))}
                        />
                        {option}
                      </label>
                    ))}
                  </div>
                ) : q.multiline ? (
                  <textarea
                    value={answers[q.id] || ""}
                    maxLength={2000}
                    rows={3}
                    onChange={(e) => setAnswers((a) => ({ ...a, [q.id]: e.target.value }))}
                    className="mt-2 w-full rounded-lg border border-white/10 bg-field px-3 py-2 text-sm outline-none"
                  />
                ) : (
                  <input
                    value={answers[q.id] || ""}
                    maxLength={2000}
                    onChange={(e) => setAnswers((a) => ({ ...a, [q.id]: e.target.value }))}
                    className="mt-2 w-full rounded-lg border border-white/10 bg-field px-3 py-2 text-sm outline-none"
                  />
                )}
              </fieldset>
            ))}
          </div>
        </div>
      ))}
      {error && (
        <div className="mt-4 flex items-center gap-2 text-sm text-[#F87171]">
          <Icon name="error" size={16} color="#F87171" />
          {error}
        </div>
      )}
      <Button className="mt-5" icon="send" loading={submitting} disabled={submitting} onClick={submit}>
        Submit feedback
      </Button>
    </div>
  );
}

export function FeedbackAnswers({
  questions,
  answers,
}: {
  questions: FeedbackQuestion[];
  answers: Record<string, string> | null | undefined;
}) {
  const given = answers || {};
  const known = new Set(questions.map((q) => q.id));
  const earlier = Object.entries(given).filter(([id, value]) => !known.has(id) && String(value || "").trim());
  return (
    <div className="space-y-3">
      {questions.map((q) => (
        <div key={q.id}>
          <div className="text-xs text-muted">
            {q.number}. {q.prompt}
          </div>
          <div className="mt-0.5 text-sm">{given[q.id] || "—"}</div>
        </div>
      ))}
      {earlier.map(([id, value]) => (
        <div key={id}>
          <div className="text-xs text-muted">Removed question</div>
          <div className="mt-0.5 text-sm">{value}</div>
        </div>
      ))}
    </div>
  );
}
