/* eslint-disable react-refresh/only-export-components */
import { useRef, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import DelegateBadge from "@/components/DelegateBadge";
import InclusionsSection from "@/components/InclusionsSection";
import { Avatar, Button, Icon, PasswordInput, Page, Spinner, useConfirm, useToast } from "@/components/ui";
import { put } from "@/lib/api";
import { useAuth, type User } from "@/lib/auth";

/** Ask "Log out?", then sign out and go to login. */
export function useLogout() {
  const { logout } = useAuth();
  const confirm = useConfirm();
  const navigate = useNavigate();
  return async () => {
    if (!(await confirm({ title: "Log out?", message: "Are you sure you want to logout?", confirm: "Log out", danger: true }))) return;
    logout();
    navigate("/login", { replace: true });
  };
}

/** Upload a new profile photo (PUT /auth/management-profile-photo). */
export function useProfilePhoto() {
  const { refresh } = useAuth();
  const toast = useToast();
  const [uploading, setUploading] = useState(false);
  const ref = useRef<HTMLInputElement>(null);
  const input = (
    <input
      ref={ref}
      type="file"
      accept="image/*"
      hidden
      onChange={async (e) => {
        const f = e.target.files?.[0];
        e.target.value = "";
        if (!f) return;
        setUploading(true);
        const fd = new FormData();
        fd.append("profilePic", f, f.name || "profilePic.jpg");
        const res = await put("/auth/management-profile-photo", fd);
        setUploading(false);
        if (res.success) {
          await refresh();
          toast("Profile photo updated successfully", "success");
        } else toast(res.error || "Upload failed", "error");
      }}
    />
  );
  return { uploading, pick: () => ref.current?.click(), input };
}

/** The participant's badge ID: employeeId, else apartmentId, else the user id. */
export const badgeIdOf = (u: User) => String(u.employeeId || u.apartmentId || u.id || u._id || "");

export function roleLabel(u: User) {
  if (u.loginRole) return u.loginRole[0].toUpperCase() + String(u.loginRole).slice(1);
  if (u.userType === "apartment") return "Event Admin";
  if (u.userType === "participant") return "Delegate";
  const t = String(u.userType ?? "");
  return t ? t[0].toUpperCase() + t.slice(1) : "";
}

function PasswordForm({ onDone }: { onDone?: () => void }) {
  const toast = useToast();
  const [cur, setCur] = useState("");
  const [next, setNext] = useState("");
  const [conf, setConf] = useState("");
  const [busy, setBusy] = useState(false);
  const submit = async () => {
    if (!cur && !next && !conf) return toast("Enter your current and new password", "error");
    if (!cur) return toast("Enter your current password", "error");
    if (next.trim().length < 6) return toast("New password must be at least 6 characters", "error");
    if (next !== conf) return toast("New password and confirm password do not match", "error");
    setBusy(true);
    const res = await put("/auth/change-password", { currentPassword: cur, newPassword: next });
    setBusy(false);
    if (!res.success) return toast(res.error || "Failed to update password", "error");
    toast("Password updated successfully", "success");
    setCur("");
    setNext("");
    setConf("");
    onDone?.();
  };
  return (
    <div className="space-y-3">
      <PasswordInput value={cur} onChange={(e) => setCur(e.target.value)} placeholder="Current password" />
      <PasswordInput value={next} onChange={(e) => setNext(e.target.value)} placeholder="New password" />
      <PasswordInput value={conf} onChange={(e) => setConf(e.target.value)} placeholder="Confirm new password" />
      <Button full loading={busy} icon="lock_reset" onClick={submit}>
        Update Password
      </Button>
    </div>
  );
}

export function ChangePassword() {
  const navigate = useNavigate();
  return (
    <Page title="Change Password" width={520}>
      <div className="card p-5">
        <PasswordForm onDone={() => navigate(-1)} />
      </div>
    </Page>
  );
}

function IdCard({ user }: { user: User }) {
  const photo = useProfilePhoto();
  return (
    <div className="card flex items-center gap-4 p-4">
      <button onClick={photo.pick} className="relative" title="Change photo">
        <Avatar src={user.profilePic} name={user.name} size={72} />
        <span className="absolute -bottom-0.5 -right-0.5 flex h-7 w-7 items-center justify-center rounded-full border-2 border-card bg-accent">
          {photo.uploading ? <Spinner size={14} color="#fff" /> : <Icon name="photo_camera" size={15} />}
        </span>
      </button>
      {photo.input}
      <div className="min-w-0">
        <div className="text-lg font-extrabold">{user.name}</div>
        <div className="text-sm font-semibold text-[#60A5FA]">{roleLabel(user)}</div>
        {user.username && <div className="text-xs text-muted">@{user.username}</div>}
      </div>
    </div>
  );
}

function InfoTile({ icon, label, value }: { icon: string; label: string; value: string }) {
  return (
    <div className="card flex items-center gap-3 p-3.5">
      <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-accent/15">
        <Icon name={icon} size={20} color="#3B82F6" />
      </span>
      <div className="min-w-0">
        <div className="text-xs text-muted">{label}</div>
        <div className="truncate text-sm font-semibold">{value || "—"}</div>
      </div>
    </div>
  );
}

/**
 * Participant: "QR Pass" — the delegate badge + package inclusions.
 * Everyone else: "My Profile" — ID card, mobile, email, event, change password.
 */
export function QrPass() {
  const { user } = useAuth();

  if (!user) return null;
  if (user.userType === "participant") {
    const id = badgeIdOf(user);
    const data = {
      name: user.name,
      participantType: "DELEGATE",
      idNumber: id,
      designation: user.department ?? "",
      institution: user.apartmentName ?? "",
      qrCode: id,
    };
    return (
      <Page title="QR Pass" width={560}>
        <DelegateBadge data={data} />
        <div className="mt-4 flex items-center justify-center gap-2 rounded-xl bg-white/5 px-4 py-2.5 text-sm font-semibold text-white/70">
          <Icon name="info" outline size={16} />
          ID: {id} &nbsp; • &nbsp; {user.mobileNumber}
        </div>
        <div className="mt-6">
          <InclusionsSection />
        </div>
      </Page>
    );
  }
  return (
    <Page title="My Profile" width={560}>
      <IdCard user={user} />
      <div className="mt-3 space-y-2">
        <InfoTile icon="phone" label="Mobile" value={String(user.mobileNumber ?? "")} />
        <InfoTile icon="email" label="Email address" value={String(user.email ?? "")} />
        {user.apartmentName && <InfoTile icon="event" label="Event" value={String(user.apartmentName)} />}
      </div>
      <div className="card mt-3 p-4">
        <div className="font-bold">Change Password</div>
        <div className="mb-3 text-xs text-muted">Enter current password to set a new one</div>
        <PasswordForm />
      </div>
    </Page>
  );
}

/** A short pass code from the role and account id, e.g. "ADM-3F2A1C". */
export function passCode(role: string, userId: string) {
  const prefix = role === "ADMIN" ? "ADM" : role === "SPEAKER" ? "SPK" : "STF";
  const tail = userId.length > 6 ? userId.slice(-6) : userId;
  return `${prefix}-${tail.toUpperCase()}`;
}

/** QR Pass for admins, speakers and event staff (?role=ADMIN|SPEAKER|EVENT STAFF, &profile=1 adds the profile link). */
export function RoleQrPass() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const role = params.get("role") || "EVENT STAFF";
  if (!user) return null;
  const code = passCode(role, String(user.id ?? user._id ?? ""));
  return (
    <Page title="QR Pass" width={560}>
      <DelegateBadge
        data={{
          name: user.name,
          participantType: role,
          idNumber: code,
          designation: user.department ?? "",
          institution: user.apartmentName ?? "",
          qrCode: code,
        }}
      />
      <div className="mt-4 flex items-center justify-center gap-2 rounded-xl bg-white/5 px-4 py-2.5 text-sm font-semibold text-white/70">
        <Icon name="info" outline size={16} />
        {[code, user.mobileNumber].filter(Boolean).join("   •   ")}
      </div>
      {params.get("profile") === "1" && (
        <Button full variant="outline" icon="person" className="mt-4 py-3" onClick={() => navigate("/my-profile")}>
          My Profile &amp; Password
        </Button>
      )}
    </Page>
  );
}

/** Participant "My Profile": header card, personal info, change password, logout. */
export function ParticipantProfile() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const doLogout = useLogout();
  const photo = useProfilePhoto();
  if (!user) return null;
  const id = badgeIdOf(user);
  return (
    <Page title="My Profile" width={560}>
      <div className="card flex flex-col items-center p-5 text-center">
        <div className="text-[11px] font-bold tracking-widest text-[#60A5FA]">ISDR 2026</div>
        <button onClick={photo.pick} className="relative mt-3" title="Change photo">
          <Avatar src={user.profilePic} name={user.name} size={92} />
          <span className="absolute bottom-0 right-0 flex h-8 w-8 items-center justify-center rounded-full border-2 border-card bg-accent">
            {photo.uploading ? <Spinner size={14} color="#fff" /> : <Icon name="photo_camera" size={16} />}
          </span>
        </button>
        {photo.input}
        <div className="mt-3 text-xl font-extrabold">{user.name?.trim() || "Participant"}</div>
        <div className="mt-2 flex flex-wrap justify-center gap-2">
          <span className="rounded-full bg-accent/15 px-3 py-1 text-[11px] font-bold text-[#60A5FA]">{roleLabel(user).toUpperCase()}</span>
          {id && <span className="rounded-full bg-white/10 px-3 py-1 text-[11px] font-bold">ID: {id}</span>}
        </div>
      </div>
      <div className="mb-2 mt-6 text-xs font-bold tracking-wider text-muted">PERSONAL INFORMATION</div>
      <div className="space-y-2">
        <InfoTile icon="phone" label="Mobile Number" value={String(user.mobileNumber ?? "")} />
        <InfoTile icon="email" label="Email Address" value={String(user.email ?? "")} />
        {user.apartmentName && <InfoTile icon="confirmation_number" label="Registration / Package" value={String(user.apartmentName)} />}
        {user.department && <InfoTile icon="school" label="Institution / Department" value={String(user.department)} />}
      </div>
      <div className="mb-2 mt-6 text-xs font-bold tracking-wider text-muted">ACCOUNT &amp; SECURITY</div>
      <div className="space-y-2">
        <button onClick={() => navigate("/change-password")} className="card flex w-full items-center gap-3 p-3.5 text-left hover:bg-[#191926]">
          <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-accent/15">
            <Icon name="lock" size={20} color="#3B82F6" />
          </span>
          <span className="flex-1">
            <span className="block text-sm font-semibold">Change Password</span>
            <span className="block text-xs text-muted">Update your account password</span>
          </span>
          <Icon name="chevron_right" color="#9CA3AF" />
        </button>
        <button onClick={doLogout} className="card flex w-full items-center gap-3 p-3.5 text-left hover:bg-[#191926]">
          <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-red-500/15">
            <Icon name="logout" size={20} color="#EF4444" />
          </span>
          <span className="flex-1">
            <span className="block text-sm font-semibold text-[#F87171]">Logout</span>
            <span className="block text-xs text-muted">Sign out of this device</span>
          </span>
        </button>
      </div>
    </Page>
  );
}
