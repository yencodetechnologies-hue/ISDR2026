import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import DelegateBadge from "@/components/DelegateBadge";
import ScreenshotGuard from "@/components/ScreenshotGuard";
import InclusionsSection from "@/components/InclusionsSection";
import { AppBar, Icon, Spinner, useToast } from "@/components/ui";
import { AppTextField } from "@/components/app/AppForm";
import { get, put } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { badgeIdOf, roleLabel, useLogout, useProfilePhoto } from "./Profile";

/** The app's _pwDecoration field: hint text, blue prefix icon, optional eye toggle. */
function PwField({
  value,
  onChange,
  hint,
  outline,
  hidden,
  onToggle,
}: {
  value: string;
  onChange: (v: string) => void;
  hint: string;
  outline?: boolean;
  hidden: boolean;
  onToggle?: () => void;
}) {
  return (
    <div className="relative">
      <span className="pointer-events-none absolute inset-y-0 left-3.5 flex items-center">
        <Icon name="lock" outline={outline} size={20} color="#3B82F6" />
      </span>
      <input
        type={hidden ? "password" : "text"}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={hint}
        className={`block w-full rounded-xl border border-white/10 bg-[#0A0A12] py-3 pl-12 text-[15px] text-white outline-none placeholder:text-[14.5px] placeholder:text-muted focus:border-accent focus:shadow-[inset_0_0_0_0.4px_#3B82F6] ${onToggle ? "pr-12" : "pr-3"}`}
      />
      {onToggle && (
        <button
          type="button"
          onClick={onToggle}
          className="absolute right-1 top-1/2 flex h-10 w-10 -translate-y-1/2 items-center justify-center rounded-full"
        >
          <Icon name={hidden ? "visibility" : "visibility_off"} outline size={20} color="#9CA3AF" />
        </button>
      )}
    </div>
  );
}

/** My Profile at phone width (admin, speaker, event staff) — the app's MyProfilePage. */
export function MyProfileApp() {
  const { user } = useAuth();
  const toast = useToast();
  const photo = useProfilePhoto();
  const [cur, setCur] = useState("");
  const [next, setNext] = useState("");
  const [conf, setConf] = useState("");
  const [hideCur, setHideCur] = useState(true);
  const [hideNew, setHideNew] = useState(true);
  const [saving, setSaving] = useState(false);

  const change = async () => {
    const n = next.trim();
    const c = conf.trim();
    if (!cur && !n && !c) return toast("Enter your current and new password");
    if (!cur) return toast("Enter your current password");
    if (n.length < 6) return toast("New password must be at least 6 characters");
    if (n !== c) return toast("New password and confirm password do not match");
    setSaving(true);
    const r = await put("/auth/change-password", { currentPassword: cur, newPassword: n });
    setSaving(false);
    if (r.success) {
      setCur("");
      setNext("");
      setConf("");
      toast("Password updated successfully");
    } else toast(r.error || "Failed to update password");
  };

  const tile = (icon: string, label: string, value: string) => (
    <div className="flex items-center gap-3 rounded-[14px] bg-accent/[0.08] px-3.5 py-2.5">
      <Icon name={icon} size={20} color="#3B82F6" />
      <div className="min-w-0 flex-1">
        <div className="text-[11px] text-muted">{label}</div>
        <div className="break-words text-[14.5px] font-bold text-accent">{value || "-"}</div>
      </div>
    </div>
  );

  const name = String(user?.name ?? "");
  return (
    <div className="min-h-screen bg-bg">
      <AppBar title="My Profile" bg="#3B82F6" titleClassName="!text-left text-xl font-extrabold" />
      {!user ? (
        <div className="pt-40 text-center">Not logged in</div>
      ) : (
        <div className="space-y-2 px-4 pb-5 pt-1">
          <div className="!mb-3 flex items-center rounded-[20px] bg-accent p-3.5 shadow-[0_12px_24px_rgba(59,130,246,0.25)]">
            <button onClick={photo.uploading ? undefined : photo.pick} className="relative h-[68px] w-[68px] shrink-0">
              <span className="flex h-full w-full items-center justify-center overflow-hidden rounded-2xl bg-white/25">
                {user.profilePic ? (
                  <img src={user.profilePic} alt="" className="h-full w-full object-cover" />
                ) : (
                  <span className="text-[28px] font-extrabold">{name.trim() ? name.trim()[0].toUpperCase() : "?"}</span>
                )}
              </span>
              {photo.uploading && (
                <span className="absolute inset-0 flex items-center justify-center rounded-2xl bg-[#9CA3AF]">
                  <Spinner size={26} color="#fff" />
                </span>
              )}
              <span className="absolute bottom-0 right-0 rounded-br-2xl rounded-tl-[10px] bg-card p-[5px]">
                <Icon name="photo_camera" size={13} color="#3B82F6" />
              </span>
            </button>
            {photo.input}
            <div className="ml-3.5 min-w-0 flex-1">
              <div className="text-[11px] font-extrabold tracking-[2px]">ISDR 2026</div>
              <div className="mt-[3px] line-clamp-2 text-[19px] font-extrabold">{name}</div>
              <div className="mt-0.5 text-[13.5px] text-white/60">{roleLabel(user)}</div>
            </div>
          </div>
          {tile("phone", "Mobile", String(user.mobileNumber ?? ""))}
          {tile("email", "Email address", String(user.email ?? ""))}
          {user.apartmentName && tile("event", "Event", String(user.apartmentName))}
          <div className="!mt-3 rounded-[18px] border border-white/10 bg-card p-3.5 shadow-[0_6px_14px_rgba(0,0,0,0.04)]">
            <div className="flex items-center">
              <span className="flex h-9 w-9 items-center justify-center rounded-[10px] bg-accent/[0.09]">
                <Icon name="lock" outline size={20} color="#3B82F6" />
              </span>
              <div className="ml-3.5 min-w-0 flex-1">
                <div className="text-base font-extrabold">Change Password</div>
                <div className="mt-0.5 truncate text-[11.5px] text-muted">Enter current password to set a new one</div>
              </div>
            </div>
            <div className="mt-3 space-y-2">
              <PwField
                value={cur}
                onChange={setCur}
                hint="Current password"
                outline
                hidden={hideCur}
                onToggle={() => setHideCur((v) => !v)}
              />
              <PwField
                value={next}
                onChange={setNext}
                hint="New password"
                hidden={hideNew}
                onToggle={() => setHideNew((v) => !v)}
              />
              <PwField value={conf} onChange={setConf} hint="Confirm new password" hidden={hideNew} />
            </div>
            <button
              onClick={saving ? undefined : change}
              className="mt-3 flex h-11 w-full items-center justify-center rounded-[14px] bg-accent text-[15px] font-bold"
            >
              {saving ? <Spinner size={22} color="#fff" /> : "Update Password"}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

/** Change Password at phone width — the app's ChangePasswordPage. */
export function ChangePasswordApp() {
  const toast = useToast();
  const navigate = useNavigate();
  const [cur, setCur] = useState("");
  const [next, setNext] = useState("");
  const [conf, setConf] = useState("");
  const [errors, setErrors] = useState<Record<string, string | null>>({});
  const [saving, setSaving] = useState(false);

  const submit = async () => {
    const e = {
      cur: cur ? null : "Enter your current password",
      next: next.trim().length < 6 ? "New password must be at least 6 characters" : null,
      conf: conf.trim() !== next.trim() ? "Passwords do not match" : null,
    };
    setErrors(e);
    if (e.cur || e.next || e.conf) return;
    (document.activeElement as HTMLElement | null)?.blur();
    setSaving(true);
    const r = await put("/auth/change-password", { currentPassword: cur, newPassword: next.trim() });
    setSaving(false);
    if (r.success) {
      toast("Password changed successfully");
      navigate(-1);
    } else toast(r.error || "Could not change password");
  };

  const field = (key: string, label: string, value: string, set: (v: string) => void) => (
    <AppTextField
      label={label}
      icon="lock"
      iconColor="#60A5FA"
      password
      value={value}
      onChange={set}
      fill="#1E1E2A"
      outer="#0A0A12"
      radius={14}
      error={errors[key]}
    />
  );
  return (
    <div className="min-h-screen bg-bg">
      <AppBar title="Change Password" outfit titleClassName="!text-left font-outfit text-[18px] font-bold" />
      <div className="space-y-4 p-5">
        {field("cur", "Current password", cur, setCur)}
        {field("next", "New password", next, setNext)}
        {field("conf", "Confirm new password", conf, setConf)}
        <button
          onClick={saving ? undefined : submit}
          className="!mt-7 flex h-[50px] w-full items-center justify-center rounded-[14px] bg-accent text-[15px] font-bold"
        >
          {saving ? <Spinner size={20} color="#fff" /> : "Update Password"}
        </button>
      </div>
    </div>
  );
}

/** Participant QR Pass at phone width — matching Flutter _buildParticipantBadgeView. */
export function ParticipantQrPassApp() {
  const { user } = useAuth();
  const [reg, setReg] = useState<Record<string, any> | null>(null);

  useEffect(() => {
    get("/managed-events/my-registration").then((res) => {
      if (res.success && res.registration) setReg(res.registration);
    });
  }, []);

  if (!user) return null;
  const id = badgeIdOf(user);
  const data = {
    name: user.name,
    participantType: reg?.participantType || "DELEGATE",
    participantTypeColor: reg?.participantTypeColor,
    idNumber: id,
    designation: user.department ?? "",
    institution: user.apartmentName ?? "",
    qrCode: id,
  };

  return (
    <div className="min-h-screen bg-[#0A0A12] text-white">
      <AppBar title="QR Pass" outfit titleClassName="!text-left font-outfit text-[18px] font-bold" />
      <div className="px-4 pb-12 pt-2">
        <ScreenshotGuard>
          <div className="overflow-hidden rounded-2xl">
            <DelegateBadge data={data} />
          </div>
        </ScreenshotGuard>

        <div className="mt-3.5 flex items-center justify-center gap-2 rounded-xl border border-white/10 bg-white/[0.04] px-4 py-2.5 font-inter text-[13px] font-semibold text-white/70">
          <Icon name="info" outline size={16} />
          ID: {id} &nbsp; • &nbsp; {user.mobileNumber}
        </div>

        <div className="mt-5 rounded-2xl border border-white/[0.08] bg-[#14141F] p-4">
          <InclusionsSection />
        </div>
      </div>
    </div>
  );
}

/** Participant My Profile at phone width — matching Flutter ParticipantProfilePage. */
export function ParticipantProfileApp() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const doLogout = useLogout();
  const photo = useProfilePhoto();

  if (!user) return null;
  const id = badgeIdOf(user);

  const tile = (icon: string, label: string, value: string) => (
    <div className="flex items-center gap-3 rounded-[14px] border border-white/[0.06] bg-[#14141F] p-3.5 shadow-sm">
      <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-[10px] bg-[#3B82F6]/15 text-[#3B82F6]">
        <Icon name={icon} size={20} />
      </span>
      <div className="min-w-0 flex-1">
        <div className="font-inter text-[11px] font-medium text-muted">{label}</div>
        <div className="truncate font-outfit text-sm font-bold text-white">{value || "—"}</div>
      </div>
    </div>
  );

  return (
    <div className="min-h-screen bg-[#0A0A12] text-white">
      <AppBar title="My Profile" outfit titleClassName="!text-left font-outfit text-[18px] font-bold" />
      <div className="space-y-4 px-4 pb-12 pt-2">
        {/* ID Card Hero Banner */}
        <div className="relative overflow-hidden rounded-[20px] border border-[#3B82F6]/40 bg-gradient-to-br from-[#0F172A] to-[#1E3A8A] p-4 shadow-lg">
          <div className="flex items-center gap-3.5">
            <button
              onClick={photo.uploading ? undefined : photo.pick}
              className="relative h-[68px] w-[68px] shrink-0"
              title="Change photo"
            >
              <span className="flex h-full w-full items-center justify-center overflow-hidden rounded-2xl bg-white/20">
                {user.profilePic ? (
                  <img src={user.profilePic} alt="" className="h-full w-full object-cover" />
                ) : (
                  <span className="font-outfit text-2xl font-bold">{user.name ? user.name[0].toUpperCase() : "P"}</span>
                )}
              </span>
              <span className="absolute -bottom-1 -right-1 flex h-6 w-6 items-center justify-center rounded-full bg-[#3B82F6] text-white shadow">
                {photo.uploading ? <Spinner size={12} color="#fff" /> : <Icon name="photo_camera" size={13} />}
              </span>
            </button>
            {photo.input}
            <div className="min-w-0 flex-1">
              <div className="truncate font-outfit text-lg font-bold text-white">{user.name?.trim() || "Participant"}</div>
              <div className="mt-1 flex flex-wrap gap-1.5">
                <span className="rounded-md bg-[#3B82F6]/25 px-2 py-0.5 font-inter text-[10.5px] font-bold text-[#93C5FD]">
                  {roleLabel(user).toUpperCase()}
                </span>
                {id && (
                  <span className="rounded-md bg-white/10 px-2 py-0.5 font-inter text-[10.5px] font-bold text-white/80">
                    ID: {id}
                  </span>
                )}
              </div>
            </div>
          </div>
        </div>

        {/* Section: PERSONAL INFORMATION */}
        <div>
          <div className="mb-2 font-inter text-xs font-extrabold tracking-[0.4px] text-muted">
            PERSONAL INFORMATION
          </div>
          <div className="space-y-2">
            {tile("phone", "Mobile Number", String(user.mobileNumber ?? ""))}
            {tile("email", "Email Address", String(user.email ?? ""))}
            {user.apartmentName && tile("confirmation_number", "Registration / Package", String(user.apartmentName))}
            {user.department && tile("school", "Institution / Department", String(user.department))}
          </div>
        </div>

        {/* Section: ACCOUNT & SECURITY */}
        <div>
          <div className="mb-2 font-inter text-xs font-extrabold tracking-[0.4px] text-muted">
            ACCOUNT &amp; SECURITY
          </div>
          <div className="space-y-2">
            <button
              onClick={() => navigate("/change-password")}
              className="flex w-full items-center gap-3 rounded-[14px] border border-white/[0.06] bg-[#14141F] p-3.5 transition active:scale-[0.99]"
            >
              <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-[10px] bg-[#3B82F6]/15 text-[#3B82F6]">
                <Icon name="lock" size={20} />
              </span>
              <div className="min-w-0 flex-1 text-left">
                <div className="font-outfit text-sm font-bold text-white">Change Password</div>
                <div className="font-inter text-xs text-muted">Update your account password</div>
              </div>
              <Icon name="chevron_right" size={20} color="#9CA3AF" />
            </button>

            <button
              onClick={doLogout}
              className="flex w-full items-center gap-3 rounded-[14px] border border-red-500/20 bg-[#14141F] p-3.5 transition active:scale-[0.99]"
            >
              <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-[10px] bg-red-500/15 text-[#EF4444]">
                <Icon name="logout" size={20} />
              </span>
              <div className="min-w-0 flex-1 text-left">
                <div className="font-outfit text-sm font-bold text-[#F87171]">Logout</div>
                <div className="font-inter text-xs text-muted">Sign out of this device</div>
              </div>
              <Icon name="chevron_right" size={20} color="#F87171" />
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
