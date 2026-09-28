/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
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
  PhotoInput,
  TextArea,
  useConfirm,
  useToast,
} from "@/components/ui";
import { del, formData, get, post, put } from "@/lib/api";
import { idOf } from "@/lib/format";

export default function ManageSpeakers() {
  const toast = useToast();
  const confirm = useConfirm();
  const [speakers, setSpeakers] = useState<any[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [editing, setEditing] = useState<any | null>(null); // {} = new
  const [name, setName] = useState("");
  const [bio, setBio] = useState("");
  const [designation, setDesignation] = useState("");
  const [institution, setInstitution] = useState("");
  const [mobile, setMobile] = useState("");
  const [photo, setPhoto] = useState<File | null>(null);
  const [photoUrl, setPhotoUrl] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    const res = await get("/speakers");
    if (!res.success) return setError(res.error || "Could not load speakers");
    setSpeakers(res.speakers ?? []);
  }, []);
  useEffect(() => { load(); }, [load]);

  const openEdit = (s?: any) => {
    setEditing(s ?? {});
    setName(s?.name ?? "");
    setBio(s?.bio ?? "");
    setDesignation(s?.designation ?? "");
    setInstitution(s?.institution ?? "");
    setMobile(s?.mobile ?? "");
    setPhotoUrl(s?.photoUrl ?? null);
    setPhoto(null);
  };

  const save = async () => {
    if (!name.trim()) return toast("Enter the speaker's name", "error");
    setSaving(true);
    const isNew = !idOf(editing);
    const fd = formData({ name: name.trim(), bio: bio.trim(), designation: designation.trim(), institution: institution.trim(), mobile: mobile.trim() }, { photo });
    const res = isNew ? await post("/speakers", fd) : await put(`/speakers/${idOf(editing)}`, fd);
    setSaving(false);
    if (!res.success) return toast(res.error || "Could not save", "error");
    toast(isNew ? "Speaker added" : "Speaker updated", "success");
    setEditing(null);
    load();
  };

  const remove = async (s: any) => {
    if (!(await confirm({ title: `Remove ${s.name}?`, confirm: "Remove", danger: true }))) return;
    const res = await del(`/speakers/${idOf(s)}`);
    if (res.success) { setSpeakers((l) => (l ?? []).filter((x) => idOf(x) !== idOf(s))); toast("Speaker removed", "success"); }
    else toast(res.error || "Could not remove", "error");
  };

  return (
    <Page title="Speakers" actions={<Button small icon="add" onClick={() => openEdit()}>Add</Button>}>
      {error ? <ErrorState message={error} onRetry={load} /> : !speakers ? <Loading /> : speakers.length === 0 ? (
        <Empty icon="mic" title="No speakers yet" action={<Button icon="add" onClick={() => openEdit()}>Add Speaker</Button>} />
      ) : (
        <div className="space-y-2.5">
          {speakers.map((s) => (
            <div key={idOf(s)} className="card flex items-center gap-3 p-3.5">
              <Avatar src={s.photoUrl} name={s.name} size={44} />
              <div className="min-w-0 flex-1">
                <div className="truncate font-bold">{s.name}</div>
                {s.designation && <div className="truncate text-xs text-muted">{s.designation}</div>}
                {s.institution && <div className="truncate text-xs text-muted">{s.institution}</div>}
              </div>
              <IconButton icon="edit" outline title="Edit" onClick={() => openEdit(s)} />
              <IconButton icon="delete" outline color="#EF4444" title="Remove" onClick={() => remove(s)} />
            </div>
          ))}
        </div>
      )}

      <Modal open={!!editing} onClose={() => setEditing(null)} title={idOf(editing) ? "Edit Speaker" : "Add Speaker"}>
        <div className="space-y-3">
          <PhotoInput file={photo} url={photoUrl} onFile={setPhoto} onRemove={() => { setPhoto(null); setPhotoUrl(null); }} label="Photo" round />
          <Field label="Name"><Input value={name} onChange={(e) => setName(e.target.value)} placeholder="Speaker name" /></Field>
          <Field label="Designation"><Input value={designation} onChange={(e) => setDesignation(e.target.value)} placeholder="e.g. Professor" /></Field>
          <Field label="Institution"><Input value={institution} onChange={(e) => setInstitution(e.target.value)} placeholder="e.g. University of..." /></Field>
          <Field label="Mobile"><Input value={mobile} onChange={(e) => setMobile(e.target.value)} placeholder="Mobile number" /></Field>
          <Field label="Bio"><TextArea value={bio} onChange={(e) => setBio(e.target.value)} placeholder="Short bio" /></Field>
          <Button full loading={saving} onClick={save}>{idOf(editing) ? "Save" : "Add Speaker"}</Button>
        </div>
      </Modal>
    </Page>
  );
}
