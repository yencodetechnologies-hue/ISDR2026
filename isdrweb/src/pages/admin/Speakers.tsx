/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import {
  Avatar,
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
  useEffect(() => {
    load();
  }, [load]);

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
    const fd = formData(
      {
        name: name.trim(),
        bio: bio.trim(),
        designation: designation.trim(),
        institution: institution.trim(),
        mobile: mobile.trim(),
      },
      { photo },
    );
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
    if (res.success) {
      setSpeakers((l) => (l ?? []).filter((x) => idOf(x) !== idOf(s)));
      toast("Speaker removed", "success");
    } else toast(res.error || "Could not remove", "error");
  };

  return (
    <Page
      title="Speakers"
      subtitle={speakers ? `${speakers.length} ${speakers.length === 1 ? "speaker" : "speakers"}` : undefined}
      actions={
        <Button icon="add" onClick={() => openEdit()}>
          Add Speaker
        </Button>
      }
    >
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
          {speakers.map((s) => (
            <div key={idOf(s)} className="card flex flex-col p-5">
              <div className="flex items-start gap-3.5">
                <Avatar src={s.photoUrl} name={s.name} size={56} />
                <div className="min-w-0 flex-1">
                  <div className="truncate font-semibold">{s.name}</div>
                  {s.designation && <div className="truncate text-sm text-[#93C5FD]">{s.designation}</div>}
                  {s.institution && <div className="truncate text-xs text-muted">{s.institution}</div>}
                </div>
              </div>
              {s.bio && <p className="mt-3 line-clamp-3 text-sm text-white/65">{s.bio}</p>}
              <div className="flex-1" />
              <div className="mt-4 flex items-center gap-2 border-t border-line pt-3">
                <span className="flex flex-1 items-center gap-1.5 truncate text-xs text-muted">
                  {s.mobile && (
                    <>
                      <Icon name="call" size={14} outline />
                      {s.mobile}
                    </>
                  )}
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
        <div className="space-y-4">
          <PhotoInput
            file={photo}
            url={photoUrl}
            onFile={setPhoto}
            onRemove={() => {
              setPhoto(null);
              setPhotoUrl(null);
            }}
            label="Photo"
            round
          />
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Name">
              <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="Speaker name" />
            </Field>
            <Field label="Mobile">
              <Input value={mobile} onChange={(e) => setMobile(e.target.value)} placeholder="Mobile number" />
            </Field>
            <Field label="Designation">
              <Input
                value={designation}
                onChange={(e) => setDesignation(e.target.value)}
                placeholder="e.g. Professor"
              />
            </Field>
            <Field label="Institution">
              <Input
                value={institution}
                onChange={(e) => setInstitution(e.target.value)}
                placeholder="e.g. University of..."
              />
            </Field>
          </div>
          <Field label="Bio">
            <TextArea rows={4} value={bio} onChange={(e) => setBio(e.target.value)} placeholder="Short bio" />
          </Field>
        </div>
      </Modal>
    </Page>
  );
}
