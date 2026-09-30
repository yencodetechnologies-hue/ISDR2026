/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useRef, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { AppBar, Icon, Spinner, useConfirm, useToast } from "@/components/ui";
import { AppFab, AppSpinner } from "@/components/app/AppControls";
import { AppTextField } from "@/components/app/AppForm";
import { del, formData, get, post, put } from "@/lib/api";
import { idOf } from "@/lib/format";

/** Dark-screen text field (darkInputDecoration). */
const dark = {
  fill: "#1E1E2A",
  outer: "#0A0A12",
  border: "rgba(255,255,255,0.08)",
  focus: "#3B82F6",
  iconColor: "#60A5FA",
  radius: 14,
};

/** Speakers at phone width — the app's ManageSpeakersPage. */
export function SpeakersListApp() {
  const navigate = useNavigate();
  const toast = useToast();
  const confirm = useConfirm();
  const [speakers, setSpeakers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    const r = await get("/speakers");
    setLoading(false);
    if (r.success) {
      setError(null);
      setSpeakers(r.speakers ?? []);
    } else setError(r.error || "Could not load speakers");
  }, []);
  useEffect(() => {
    load();
  }, [load]);

  const remove = async (s: any) => {
    if (
      !(await confirm({
        title: "Delete speaker?",
        message: `${s.name} will no longer be able to log in.`,
        confirm: "Delete",
        danger: true,
      }))
    )
      return;
    const r = await del(`/speakers/${idOf(s)}`);
    if (r.success) setSpeakers((l) => l.filter((x) => idOf(x) !== idOf(s)));
    else toast(r.error || "Could not delete");
  };

  return (
    <div className="min-h-screen bg-bg">
      <AppBar title="Speakers" outfit />
      <div className="px-4 pb-24 pt-2">
        {loading ? (
          <AppSpinner />
        ) : error || speakers.length === 0 ? (
          <div className="flex flex-col items-center pt-[120px] text-center">
            <Icon name="groups" size={44} color="#9CA3AF" />
            <div className="mt-3 font-outfit text-[17px] font-bold">{error ?? "No speakers yet"}</div>
            <div className="mt-1 text-[12.5px] text-muted">
              {error ? "Pull down to try again." : "Add speakers here, then pick them when adding a schedule."}
            </div>
          </div>
        ) : (
          speakers.map((s) => {
            const photo = String(s.photo ?? s.photoUrl ?? "");
            const name = String(s.name ?? "");
            return (
              <div
                key={idOf(s)}
                className="mb-2.5 flex items-center rounded-[14px] border border-line bg-card py-2.5 pl-3 pr-1"
              >
                <span className="flex h-12 w-12 shrink-0 items-center justify-center overflow-hidden rounded-full bg-[#1E3A8A]">
                  {photo ? (
                    <img src={photo} alt="" className="h-full w-full object-cover" />
                  ) : (
                    <span className="font-outfit text-[17px] font-bold">
                      {name.trim() ? name.trim()[0].toUpperCase() : "?"}
                    </span>
                  )}
                </span>
                <div className="ml-3 min-w-0 flex-1">
                  <div className="font-outfit text-[15px] font-bold">{name}</div>
                  <div className="mt-0.5 text-xs text-muted">{s.mobileNumber ?? s.mobile ?? ""}</div>
                </div>
                <button
                  title="Edit"
                  onClick={() => navigate(`/admin/speakers/${idOf(s)}/edit`)}
                  className="flex h-12 w-12 items-center justify-center rounded-full active:bg-white/10"
                >
                  <Icon name="edit" outline color="#60A5FA" />
                </button>
                <button
                  title="Delete"
                  onClick={() => remove(s)}
                  className="flex h-12 w-12 items-center justify-center rounded-full active:bg-white/10"
                >
                  <Icon name="delete" outline color="#F87171" />
                </button>
              </div>
            );
          })
        )}
      </div>
      <AppFab icon="person_add" label="Add Speaker" onClick={() => navigate("/admin/speakers/new")} />
    </div>
  );
}

/** Add / Edit Speaker — the app's AddSpeakerPage (photo, name, mobile, password). */
export function SpeakerFormApp() {
  const { id = "" } = useParams<{ id: string }>();
  const isEdit = !!id;
  const navigate = useNavigate();
  const toast = useToast();
  const [loaded, setLoaded] = useState(!isEdit);
  const [currentPhoto, setCurrentPhoto] = useState("");
  const [name, setName] = useState("");
  const [mobile, setMobile] = useState("");
  const [password, setPassword] = useState("");
  const [photo, setPhoto] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [saving, setSaving] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!isEdit) return;
    get("/speakers").then((r) => {
      const s = (r.speakers ?? []).find((x: any) => idOf(x) === id);
      if (s) {
        setName(s.name ?? "");
        setMobile(s.mobileNumber ?? s.mobile ?? "");
        setCurrentPhoto(String(s.photo ?? s.photoUrl ?? ""));
      }
      setLoaded(true);
    });
  }, [id, isEdit]);
  useEffect(() => {
    if (!photo) return setPreview(null);
    const u = URL.createObjectURL(photo);
    setPreview(u);
    return () => URL.revokeObjectURL(u);
  }, [photo]);

  const save = async () => {
    const e: Record<string, string> = {};
    if (!name.trim()) e.name = "Enter the speaker name";
    if (!/^\d{10}$/.test(mobile.trim())) e.mobile = "Enter a valid 10-digit mobile number";
    if (!(isEdit && !password.trim()) && password.trim().length < 6)
      e.password = "Password must be at least 6 characters";
    setErrors(e);
    if (Object.keys(e).length) return;
    setSaving(true);
    const fd = formData(
      { name: name.trim(), mobileNumber: mobile.trim(), ...(password ? { password } : {}) },
      { photo },
    );
    const r = isEdit ? await put(`/speakers/${id}`, fd) : await post("/speakers", fd);
    setSaving(false);
    if (r.success) navigate(-1);
    else toast(r.error || (isEdit ? "Could not save speaker" : "Could not add speaker"));
  };

  const shown = preview ?? (currentPhoto || null);
  return (
    <div className="min-h-screen bg-bg">
      <AppBar title={isEdit ? "Edit Speaker" : "Add Speaker"} outfit />
      {!loaded ? (
        <AppSpinner />
      ) : (
        <div className="p-4">
          <div className="flex justify-center">
            <button onClick={() => fileRef.current?.click()} className="relative">
              <span className="flex h-24 w-24 items-center justify-center overflow-hidden rounded-full bg-field">
                {shown ? (
                  <img src={shown} alt="" className="h-full w-full object-cover" />
                ) : (
                  <Icon name="person" size={44} color="#60A5FA" />
                )}
              </span>
              <span className="absolute bottom-0 right-0 rounded-full bg-accent p-[7px]">
                <Icon name="photo_camera" size={16} />
              </span>
            </button>
            <input
              ref={fileRef}
              type="file"
              accept="image/*"
              hidden
              onChange={(e) => {
                const f = e.target.files?.[0];
                if (f) setPhoto(f);
                e.target.value = "";
              }}
            />
          </div>
          <div className="mt-1.5 text-center text-xs text-muted">Speaker photo</div>
          <div className="mt-4 space-y-3">
            <AppTextField
              {...dark}
              label="Name of the speaker"
              icon="person"
              value={name}
              onChange={setName}
              error={errors.name}
            />
            <AppTextField
              {...dark}
              label="Mobile number (login)"
              icon="phone"
              inputMode="numeric"
              maxLength={10}
              value={mobile}
              onChange={(v) => setMobile(v.replace(/\D/g, ""))}
              error={errors.mobile}
            />
            <AppTextField
              {...dark}
              label={isEdit ? "New password (leave blank to keep)" : "Password"}
              icon="lock"
              password
              value={password}
              onChange={setPassword}
              error={errors.password}
            />
          </div>
          <button
            onClick={saving ? undefined : save}
            className="mt-5 flex h-[50px] w-full items-center justify-center rounded-[14px] bg-accent text-[15px] font-bold"
          >
            {saving ? <Spinner size={22} color="#fff" /> : "Save Speaker"}
          </button>
        </div>
      )}
    </div>
  );
}
