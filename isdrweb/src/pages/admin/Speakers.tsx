/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  Avatar,
  Button,
  Empty,
  ErrorState,
  Field,
  IconButton,
  Input,
  Loading,
  Modal,
  Page,
  SearchBox,
  Switch,
  useConfirm,
  useToast,
} from "@/components/ui";
import { del, get, patch, post, put } from "@/lib/api";
import { matches } from "@/components/ListFilters";
import ExportMenu from "@/components/ExportMenu";
import { passCode } from "../common/Profile";
import { idOf } from "@/lib/format";
import { useAppLayout } from "@/lib/appLayout";
import { SpeakersListApp } from "./SpeakersApp";

/** Speaker's QR pass number (SPK0001…); the older id-based code until the backend has assigned one. */
const speakerPass = (s: any) => String(s.passNumber || passCode("SPEAKER", idOf(s)));

export default function ManageSpeakers() {
  // Phone width: the mobile app's screen.
  return useAppLayout() ? <SpeakersListApp /> : <ManageSpeakersWeb />;
}

function ManageSpeakersWeb() {
  const navigate = useNavigate();
  const toast = useToast();
  const confirm = useConfirm();
  const [speakers, setSpeakers] = useState<any[] | null>(null);
  const [search, setSearch] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [editing, setEditing] = useState<any | null>(null); // {} = new
  const [name, setName] = useState("");
  const [saving, setSaving] = useState(false);
  const [toggling, setToggling] = useState<string | null>(null);

  const load = useCallback(async () => {
    const res = await get("/speakers");
    if (!res.success) return setError(res.error || "Could not load speakers");
    setSpeakers(res.speakers ?? []);
  }, []);
  useEffect(() => {
    load();
  }, [load]);

  const openEdit = (s?: any) => {
    setEditing(s ?? {});
    setName(s?.name ?? "");
  };

  const save = async () => {
    const isNew = !idOf(editing);
    if (!name.trim()) return toast("Enter the speaker's name", "error");
    setSaving(true);
    const body = { name: name.trim() };
    const res = isNew ? await post("/speakers", body) : await put(`/speakers/${idOf(editing)}`, body);
    setSaving(false);
    if (!res.success) return toast(res.error || "Could not save", "error");
    toast(isNew ? "Speaker added" : "Speaker updated", "success");
    setEditing(null);
    load();
  };

  const toggleAsk = async (s: any, askEnabled: boolean) => {
    const id = idOf(s);
    setToggling(id);
    const res = await patch(`/speakers/${id}`, { askEnabled });
    setToggling(null);
    if (!res.success) return toast(res.error || "Could not update", "error");
    setSpeakers((list) => (list ?? []).map((x) => (idOf(x) === id ? { ...x, askEnabled } : x)));
  };

  const remove = async (s: any) => {
    if (!(await confirm({ title: `Remove ${s.name}?`, confirm: "Remove", danger: true }))) return;
    const res = await del(`/speakers/${idOf(s)}`);
    if (res.success) {
      setSpeakers((l) => (l ?? []).filter((x) => idOf(x) !== idOf(s)));
      toast("Speaker removed", "success");
    } else toast(res.error || "Could not remove", "error");
  };

  const shownSpeakers = (speakers ?? []).filter((s) => matches(s, search));

  return (
    <Page
      title="Speakers"
      subtitle={speakers ? `${speakers.length} ${speakers.length === 1 ? "speaker" : "speakers"}` : undefined}
      actions={
        <div className="flex flex-wrap gap-2">
          <ExportMenu
            title="Speakers"
            rows={shownSpeakers}
            columns={[
              { header: "Pass no.", value: (s: any) => speakerPass(s), width: 12 },
              { header: "Name", value: (s: any) => s.name, width: 24 },
              { header: "Mobile no.", value: (s: any) => s.mobileNumber, width: 14 },
            ]}
            qr={{
              code: speakerPass,
              badge: (s: any) => ({
                name: s.name,
                participantType: "SPEAKER",
                idNumber: speakerPass(s),
                designation: "",
                institution: "",
                qrCode: speakerPass(s),
              }),
              fileName: (s: any) => `${speakerPass(s)} - ${s.name || "Speaker"}`,
            }}
          />
          <Button icon="add" onClick={() => openEdit()}>
            Add Speaker
          </Button>
        </div>
      }
    >
      {speakers && speakers.length > 0 && (
        <div className="mb-4 flex flex-wrap items-center gap-3">
          <div className="w-full sm:w-80">
            <SearchBox value={search} onChange={setSearch} placeholder="Search name, mobile, pass no.…" />
          </div>
        </div>
      )}
      {speakers && speakers.length > 0 && shownSpeakers.length === 0 && (
        <div className="mb-4 rounded-xl border border-line px-5 py-8 text-center text-sm text-muted">
          No results match your search / filters.
        </div>
      )}
      {error ? (
        <ErrorState message={error} onRetry={load} />
      ) : !speakers ? (
        <Loading />
      ) : speakers.length === 0 ? (
        <Empty
          icon="mic"
          title="No speakers yet"
          action={
            <Button icon="add" onClick={() => openEdit()}>
              Add Speaker
            </Button>
          }
        />
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {shownSpeakers.map((s) => (
            <div key={idOf(s)} className="card flex flex-col p-5">
              <button
                type="button"
                onClick={() => navigate(`/admin/speakers/${idOf(s)}/questions`)}
                className="flex w-full items-start gap-3.5 text-left"
              >
                <Avatar src={s.photo} name={s.name} size={56} />
                <div className="min-w-0 flex-1">
                  <div className="truncate font-semibold">{s.name}</div>
                  <div className="truncate text-sm text-[#93C5FD]">{speakerPass(s)}</div>
                  <div className="mt-1 text-xs text-muted">Questions</div>
                </div>
              </button>
              <div className="mt-4 flex items-center gap-2 border-t border-line pt-3">
                <span className="flex flex-1 items-center gap-2 text-xs text-muted">
                  <Switch
                    checked={s.askEnabled === true}
                    disabled={toggling === idOf(s)}
                    onChange={(v) => toggleAsk(s, v)}
                  />
                  {s.askEnabled === true ? "Open for questions" : "Hidden from Ask a Speaker"}
                </span>
                <IconButton icon="edit" outline title="Edit" onClick={() => openEdit(s)} />
                <IconButton icon="delete" outline color="#EF4444" title="Remove" onClick={() => remove(s)} />
              </div>
            </div>
          ))}
        </div>
      )}

      <Modal
        open={!!editing}
        onClose={() => setEditing(null)}
        title={idOf(editing) ? "Edit Speaker" : "Add Speaker"}
        width={640}
        footer={
          <>
            <Button variant="outline" onClick={() => setEditing(null)}>
              Cancel
            </Button>
            <Button loading={saving} onClick={save}>
              {idOf(editing) ? "Save" : "Add Speaker"}
            </Button>
          </>
        }
      >
        <Field label="Name">
          <Input
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Speaker name"
            autoFocus
          />
        </Field>
      </Modal>
    </Page>
  );
}
