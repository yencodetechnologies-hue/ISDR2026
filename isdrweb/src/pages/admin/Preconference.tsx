/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import {
  AppBar,
  Button,
  Empty,
  ErrorState,
  Field,
  Icon,
  IconButton,
  Input,
  Loading,
  Modal,
  Page,
  Spinner,
  useConfirm,
  useToast,
} from "@/components/ui";
import { AppFab, AppSpinner } from "@/components/app/AppControls";
import { AppTextField } from "@/components/app/AppForm";
import { del, get, post, put } from "@/lib/api";
import { idOf } from "@/lib/format";
import { useAppLayout } from "@/lib/appLayout";

type Draft = { id?: string; serialNo: string; date: string; course: string; venue: string };

const emptyDraft = (): Draft => ({ serialNo: "", date: "", course: "", venue: "" });

const dark = {
  fill: "#1E1E2A",
  outer: "#0A0A12",
  border: "rgba(255,255,255,0.08)",
  focus: "#3B82F6",
  iconColor: "#60A5FA",
  radius: 14,
};

/** Admin pre-conference courses: add, edit, and delete. */
export default function ManagePreconference() {
  return useAppLayout() ? <PreconferenceAdminApp /> : <PreconferenceAdminWeb />;
}

function useCourseAdmin() {
  const toast = useToast();
  const confirm = useConfirm();
  const [items, setItems] = useState<any[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [draft, setDraft] = useState<Draft | null>(null);
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    const res = await get("/preconference");
    if (!res.success) {
      setError(res.error || "Could not load courses");
      setItems([]);
      return;
    }
    setError(null);
    setItems(res.courses ?? []);
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const save = async () => {
    if (!draft) return;
    const serialNo = Number(draft.serialNo);
    if (!Number.isInteger(serialNo) || serialNo < 1) return toast("Enter a whole S No starting at 1", "error");
    if (!draft.date.trim()) return toast("Enter the date", "error");
    if (!draft.course.trim()) return toast("Enter the course", "error");
    if (!draft.venue.trim()) return toast("Enter the venue", "error");
    const body = {
      serialNo,
      date: draft.date.trim(),
      course: draft.course.trim(),
      venue: draft.venue.trim(),
    };
    setSaving(true);
    const res = draft.id ? await put(`/preconference/${draft.id}`, body) : await post("/preconference", body);
    setSaving(false);
    if (!res.success) return toast(res.error || "Could not save", "error");
    toast(draft.id ? "Course updated" : "Course added", "success");
    setDraft(null);
    load();
  };

  const remove = async (row: any) => {
    if (
      !(await confirm({
        title: `Delete S No ${row.serialNo}?`,
        message: "It will be removed from the participant list.",
        confirm: "Delete",
        danger: true,
      }))
    )
      return;
    const res = await del(`/preconference/${idOf(row)}`);
    if (res.success) {
      setItems((list) => (list ?? []).filter((x) => idOf(x) !== idOf(row)));
      toast("Removed", "success");
    } else toast(res.error || "Could not delete", "error");
  };

  const openEdit = (row: any) =>
    setDraft({
      id: idOf(row),
      serialNo: String(row.serialNo ?? ""),
      date: String(row.date ?? ""),
      course: String(row.course ?? ""),
      venue: String(row.venue ?? ""),
    });

  return { items, error, load, draft, setDraft, saving, save, remove, openEdit, toast };
}

function CourseFields({
  draft,
  setDraft,
  app,
}: {
  draft: Draft;
  setDraft: (d: Draft) => void;
  app?: boolean;
}) {
  if (app) {
    return (
      <div className="space-y-3">
        <AppTextField {...dark} label="S No" icon="tag" value={draft.serialNo} onChange={(v) => setDraft({ ...draft, serialNo: v })} />
        <AppTextField {...dark} label="Date" icon="event" value={draft.date} onChange={(v) => setDraft({ ...draft, date: v })} />
        <AppTextField
          {...dark}
          label="Pre Conference Course"
          icon="school"
          multiline
          value={draft.course}
          onChange={(v) => setDraft({ ...draft, course: v })}
        />
        <AppTextField
          {...dark}
          label="Venue"
          icon="location_on"
          multiline
          value={draft.venue}
          onChange={(v) => setDraft({ ...draft, venue: v })}
        />
      </div>
    );
  }
  return (
    <div className="space-y-4">
      <Field label="S No">
        <Input value={draft.serialNo} onChange={(e) => setDraft({ ...draft, serialNo: e.target.value })} inputMode="numeric" />
      </Field>
      <Field label="Date">
        <Input value={draft.date} onChange={(e) => setDraft({ ...draft, date: e.target.value })} placeholder="08.09.26" />
      </Field>
      <Field label="Pre Conference Course">
        <textarea
          className="input min-h-[96px] py-3"
          value={draft.course}
          onChange={(e) => setDraft({ ...draft, course: e.target.value })}
        />
      </Field>
      <Field label="Venue">
        <textarea
          className="input min-h-[72px] py-3"
          value={draft.venue}
          onChange={(e) => setDraft({ ...draft, venue: e.target.value })}
        />
      </Field>
    </div>
  );
}

function PreconferenceAdminWeb() {
  const admin = useCourseAdmin();
  const { items, error, load, draft, setDraft, saving, save, remove, openEdit } = admin;
  return (
    <Page
      title="Preconference"
      subtitle={items ? `${items.length} ${items.length === 1 ? "course" : "courses"}` : undefined}
      actions={
        <Button icon="add" onClick={() => setDraft(emptyDraft())}>
          Add course
        </Button>
      }
    >
      {error ? (
        <ErrorState message={error} onRetry={load} />
      ) : !items ? (
        <Loading />
      ) : items.length === 0 ? (
        <Empty
          icon="school"
          title="No courses yet"
          action={
            <Button icon="add" onClick={() => setDraft(emptyDraft())}>
              Add course
            </Button>
          }
        />
      ) : (
        <div className="grid gap-3 lg:grid-cols-2">
          {items.map((row) => (
            <article key={idOf(row)} className="overflow-hidden rounded-[18px] border border-white/10 bg-[#14141F]">
              <div className="flex">
                <div className="w-1 shrink-0 bg-gradient-to-b from-[#A5B4FC] to-[#6366F1]" />
                <div className="min-w-0 flex-1 p-4">
                  <div className="flex items-center gap-2">
                    <span className="rounded-full bg-[#6366F1]/20 px-2.5 py-1 text-[11px] font-extrabold tracking-wide text-[#C7D2FE]">
                      S NO {row.serialNo}
                    </span>
                    <span className="inline-flex items-center gap-1 text-[12px] font-bold text-[#93C5FD]">
                      <Icon name="calendar_today" size={13} color="#93C5FD" />
                      {row.date}
                    </span>
                    <div className="ml-auto flex">
                      <IconButton icon="edit" outline title="Edit" onClick={() => openEdit(row)} />
                      <IconButton icon="delete" outline color="#EF4444" title="Delete" onClick={() => remove(row)} />
                    </div>
                  </div>
                  <h3 className="mt-2 font-outfit text-[15px] font-bold leading-snug">{row.course}</h3>
                  <div className="mt-3 flex items-start gap-1.5 rounded-xl bg-[#0A0A12] px-3 py-2.5 text-[12.5px] leading-snug text-white/75">
                    <Icon name="location_on" size={16} color="#A5B4FC" />
                    <span>{row.venue}</span>
                  </div>
                </div>
              </div>
            </article>
          ))}
        </div>
      )}
      <Modal
        open={!!draft}
        onClose={() => setDraft(null)}
        title={draft?.id ? "Edit course" : "Add course"}
        footer={
          <>
            <Button variant="outline" onClick={() => setDraft(null)}>
              Cancel
            </Button>
            <Button loading={saving} onClick={save}>
              {draft?.id ? "Save changes" : "Add course"}
            </Button>
          </>
        }
      >
        {draft && <CourseFields draft={draft} setDraft={setDraft} />}
      </Modal>
    </Page>
  );
}

function PreconferenceAdminApp() {
  const admin = useCourseAdmin();
  const { items, error, load, draft, setDraft, saving, save, remove, openEdit } = admin;
  return (
    <div className="min-h-screen bg-bg">
      <AppBar title="Preconference" outfit />
      <div className="px-4 pb-24 pt-2">
        {items === null && !error ? (
          <AppSpinner />
        ) : error || !items || items.length === 0 ? (
          <div className="flex flex-col items-center pt-[120px] text-center">
            <Icon name="school" size={44} color="#9CA3AF" />
            <div className="mt-3 font-outfit text-[17px] font-bold">{error ?? "No courses yet"}</div>
            {error && (
              <button onClick={load} className="mt-3 text-sm font-semibold text-[#60A5FA]">
                Try again
              </button>
            )}
          </div>
        ) : (
          items.map((row) => (
            <article key={idOf(row)} className="mb-3 overflow-hidden rounded-[18px] border border-white/10 bg-[#14141F]">
              <div className="flex">
                <div className="w-1 shrink-0 bg-gradient-to-b from-[#A5B4FC] to-[#6366F1]" />
                <div className="min-w-0 flex-1 p-3.5">
                  <div className="flex items-center gap-2">
                    <span className="rounded-full bg-[#6366F1]/20 px-2.5 py-1 text-[11px] font-extrabold tracking-wide text-[#C7D2FE]">
                      S NO {row.serialNo}
                    </span>
                    <span className="inline-flex items-center gap-1 text-[12px] font-bold text-[#93C5FD]">
                      <Icon name="calendar_today" size={13} color="#93C5FD" />
                      {row.date}
                    </span>
                    <div className="ml-auto flex">
                      <button title="Edit" onClick={() => openEdit(row)} className="flex h-10 w-10 items-center justify-center">
                        <Icon name="edit" outline color="#60A5FA" />
                      </button>
                      <button title="Delete" onClick={() => remove(row)} className="flex h-10 w-10 items-center justify-center">
                        <Icon name="delete" outline color="#F87171" />
                      </button>
                    </div>
                  </div>
                  <div className="mt-2 font-outfit text-[15px] font-bold leading-snug">{row.course}</div>
                  <div className="mt-3 flex items-start gap-1.5 rounded-xl bg-[#0A0A12] px-3 py-2.5 text-[12.5px] leading-snug text-white/75">
                    <Icon name="location_on" size={16} color="#A5B4FC" />
                    <span>{row.venue}</span>
                  </div>
                </div>
              </div>
            </article>
          ))
        )}
      </div>
      <AppFab icon="add" label="Add" onClick={() => setDraft(emptyDraft())} />
      <Modal
        open={!!draft}
        onClose={() => (saving ? undefined : setDraft(null))}
        title={draft?.id ? "Edit course" : "Add course"}
        footer={
          <button
            onClick={saving ? undefined : save}
            className="flex h-12 w-full items-center justify-center rounded-[14px] bg-accent text-[15px] font-bold"
          >
            {saving ? <Spinner size={22} color="#fff" /> : draft?.id ? "Save changes" : "Add course"}
          </button>
        }
      >
        {draft && <CourseFields draft={draft} setDraft={setDraft} app />}
      </Modal>
    </div>
  );
}
