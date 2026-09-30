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
  PasswordInput,
  PhotoInput,
  SearchBox,
  useConfirm,
  useToast,
} from "@/components/ui";
import { del, formData, get, post, put } from "@/lib/api";
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
  const toast = useToast();
  const confirm = useConfirm();
  const [speakers, setSpeakers] = useState<any[] | null>(null);
  const [search, setSearch] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [editing, setEditing] = useState<any | null>(null); // {} = new
  const [name, setName] = useState("");
  const [mobile, setMobile] = useState("");
  const [password, setPassword] = useState("");
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
    setMobile(s?.mobileNumber ?? "");
    setPassword("");
    setPhotoUrl(s?.photo || null);
    setPhoto(null);
  };

  const save = async () => {
    const isNew = !idOf(editing);
    if (!name.trim()) return toast("Enter the speaker's name", "error");
    if (!/^\d{10}$/.test(mobile.trim()))
      return toast("Enter a valid 10-digit mobile number", "error");
    if (isNew && password.trim().length < 6) return toast("Password must be at least 6 characters", "error");
    if (!isNew && password && password.trim().length < 6)
      return toast("Password must be at least 6 characters", "error");
    setSaving(true);
    const fd = formData(
      {
        name: name.trim(),
        mobileNumber: mobile.trim(),
        password: password || undefined,
        // Edit: the old photo was removed and no new one picked.
        removePhoto: !isNew && !photo && !photoUrl && editing?.photo ? "true" : undefined,
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
              <div className="flex items-start gap-3.5">
                <Avatar src={s.photo} name={s.name} size={56} />
                <div className="min-w-0 flex-1">
                  <div className="truncate font-semibold">{s.name}</div>
                  <div className="truncate text-sm text-[#93C5FD]">{speakerPass(s)}</div>
                </div>
              </div>
              <div className="flex-1" />
              <div className="mt-4 flex items-center gap-2 border-t border-line pt-3">
                <span className="flex flex-1 items-center gap-1.5 truncate text-xs text-muted">
                  {s.mobileNumber && (
                    <>
                      <Icon name="call" size={14} outline />
                      {s.mobileNumber}
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
              <Input
                value={mobile}
                inputMode="numeric"
                maxLength={10}
                onChange={(e) => setMobile(e.target.value.replace(/D/g, ""))}
                placeholder="10-digit mobile number"
              />
            </Field>
          </div>
          <Field label={idOf(editing) ? "New password (optional)" : "Password"}>
            <PasswordInput
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder={idOf(editing) ? "Leave blank to keep the current password" : "At least 6 characters"}
            />
          </Field>
        </div>
      </Modal>
    </Page>
  );
}
