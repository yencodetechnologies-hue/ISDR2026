/* eslint-disable react-refresh/only-export-components */
import { useEffect, useRef, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import DelegateBadge from "@/components/DelegateBadge";
import ScreenshotGuard from "@/components/ScreenshotGuard";
import InclusionsSection from "@/components/InclusionsSection";
import {
  AppBar,
  Avatar,
  Button,
  Icon,
  PasswordInput,
  Page,
  Panel,
  Spinner,
  useConfirm,
  useToast,
} from "@/components/ui";
import { useAppLayout } from "@/lib/appLayout";
import { get, put } from "@/lib/api";
import { useAuth, type User } from "@/lib/auth";
import { ChangePasswordApp, MyProfileApp, ParticipantProfileApp, ParticipantQrPassApp } from "./ProfileApp";

/** Ask "Log out?", then sign out and go to login. */
export function useLogout() {
  const { logout } = useAuth();
  const confirm = useConfirm();
  const navigate = useNavigate();
  return async () => {
    if (
      !(await confirm({
        title: "Log out?",
        message: "Are you sure you want to logout?",
        confirm: "Log out",
        danger: true,
      }))
    )
      return;
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
    <div className="space-y-4">
      <div>
        <label className="label">Current password</label>
        <PasswordInput value={cur} onChange={(e) => setCur(e.target.value)} placeholder="Current password" />
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        <div>
          <label className="label">New password</label>
          <PasswordInput value={next} onChange={(e) => setNext(e.target.value)} placeholder="New password" />
        </div>
        <div>
          <label className="label">Confirm new password</label>
          <PasswordInput value={conf} onChange={(e) => setConf(e.target.value)} placeholder="Confirm new password" />
        </div>
      </div>
      <div className="flex justify-end">
        <Button loading={busy} icon="lock_reset" onClick={submit}>
          Update Password
        </Button>
      </div>
    </div>
  );
}

export function ChangePassword() {
  // Phone width: the mobile app's screen.
  return useAppLayout() ? <ChangePasswordApp /> : <ChangePasswordWeb />;
}

function ChangePasswordWeb() {
  const navigate = useNavigate();
  return (
    <Page title="Change Password" subtitle="Use at least 6 characters" width={640}>
      <Panel title="Password" icon="lock" subtitle="Enter your current password to set a new one">
        <PasswordForm onDone={() => navigate(-1)} />
      </Panel>
    </Page>
  );
}

function IdCard({ user }: { user: User }) {
  const photo = useProfilePhoto();
  return (
    <div className="card flex flex-col items-center p-6 text-center">
      <button onClick={photo.pick} className="relative" title="Change photo">
        <Avatar src={user.profilePic} name={user.name} size={104} />
        <span className="absolute bottom-0 right-0 flex h-9 w-9 items-center justify-center rounded-full border-2 border-card bg-accent">
          {photo.uploading ? <Spinner size={15} color="#fff" /> : <Icon name="photo_camera" size={17} />}
        </span>
      </button>
      {photo.input}
      <div className="mt-4 text-lg font-semibold">{user.name}</div>
      <div className="text-sm font-semibold text-[#60A5FA]">{roleLabel(user)}</div>
      {user.username && <div className="text-xs text-muted">@{user.username}</div>}
    </div>
  );
}

function InfoRow({ icon, label, value }: { icon: string; label: string; value: string }) {
  return (
    <div className="flex items-center gap-3 px-5 py-3.5">
      <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-accent/15">
        <Icon name={icon} size={19} color="#3B82F6" />
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
  // Participant's own registration: badge type + banner colour chosen by the admin.
  const [reg, setReg] = useState<Record<string, any> | null>(null);
  const isParticipant = user?.userType === "participant";
  const appLayout = useAppLayout();
  useEffect(() => {
    if (!isParticipant) return;
    get("/managed-events/my-registration").then((res) => {
      if (res.success && res.registration) setReg(res.registration);
    });
  }, [isParticipant]);

  if (!user) return null;
  if (user.userType === "participant") {
    if (appLayout) return <ParticipantQrPassApp />;
    const id = badgeIdOf(user);
    const data = {
      name: user.name,
      participantType: /^spot register$/i.test(String(reg?.packageName || "")) ? "" : reg?.participantType || "DELEGATE",
      participantTypeColor: reg?.participantTypeColor,
      packageName: reg?.packageName,
      idNumber: id,
      designation: user.department ?? "",
      institution: user.apartmentName ?? "",
      qrCode: id,
    };
    return (
      <Page title="QR Pass" subtitle="Show this pass at entry, exit and inclusion counters" back={false} width={1100}>
        <div className="grid gap-6 lg:grid-cols-[400px_1fr]">
          <div className="lg:sticky lg:top-24 lg:self-start">
            <ScreenshotGuard>
              <DelegateBadge data={data} />
            </ScreenshotGuard>
            <div className="mt-4 flex items-center justify-center gap-2 rounded-lg border border-line bg-white/[0.03] px-4 py-2.5 text-sm font-semibold text-white/70">
              <Icon name="info" outline size={16} />
              ID: {id} &nbsp; • &nbsp; {user.mobileNumber}
            </div>
          </div>
          <div className="card p-5 sm:p-6">
            <InclusionsSection />
          </div>
        </div>
      </Page>
    );
  }
  // Phone width: the app's MyProfilePage.
  if (appLayout) return <MyProfileApp />;
  return (
    <Page title="My Profile" width={1000}>
      <div className="grid gap-5 lg:grid-cols-3">
        <IdCard user={user} />
        <div className="space-y-5 lg:col-span-2">
          <Panel title="Account details" icon="badge" bodyClass="divide-y divide-line">
            <InfoRow icon="phone" label="Mobile" value={String(user.mobileNumber ?? "")} />
            <InfoRow icon="email" label="Email address" value={String(user.email ?? "")} />
            {user.apartmentName && <InfoRow icon="event" label="Event" value={String(user.apartmentName)} />}
          </Panel>
          <Panel title="Change Password" subtitle="Enter current password to set a new one" icon="lock">
            <PasswordForm />
          </Panel>
        </div>
      </div>
    </Page>
  );
}

/** Older pass code from the role and account id, e.g. "ADM3F2A1C" — shown only until the saved pass number loads. */
export function passCode(role: string, userId: string) {
  const prefix = role === "ADMIN" ? "ADM" : role === "SPEAKER" ? "SPK" : "STF";
  const tail = userId.length > 6 ? userId.slice(-6) : userId;
  return `${prefix}${tail.toUpperCase()}`;
}

/** QR Pass for admins, speakers and event staff (?role=ADMIN|SPEAKER|EVENT STAFF, &profile=1 adds the profile link). */
export function RoleQrPass() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const role = params.get("role") || "EVENT STAFF";
  const appLayout = useAppLayout();
  // Saved pass number (ADM0001 / SPK0001 / STF0001…); older logins don't have it yet, so ask the server.
  const [passNumber, setPassNumber] = useState<string>(String(user?.passNumber ?? ""));
  useEffect(() => {
    get("/auth/me").then((res: any) => {
      const n = String(res?.user?.passNumber ?? "");
      if (n) setPassNumber(n);
    });
  }, []);
  if (!user) return null;
  const code = passNumber || passCode(role, String(user.id ?? user._id ?? ""));
  // Phone width: the app's QrPassPage — badge, "code • mobile" line, profile link.
  if (appLayout)
    return (
      <div className="min-h-screen bg-[#0F172A]">
        <AppBar title="QR Pass" titleClassName="text-xl font-extrabold" bg="#0F172A" />
        <div className="px-4 pb-5 pt-2.5">
          <ScreenshotGuard>
            <div className="overflow-hidden rounded-2xl">
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
            </div>
          </ScreenshotGuard>
          <div className="mt-4 flex items-center justify-center gap-2 rounded-xl bg-white/[0.08] px-3.5 py-2.5 text-[13px] font-semibold whitespace-pre text-white/70">
            <Icon name="info" size={16} color="rgba(255,255,255,0.7)" />
            {[code, user.mobileNumber].filter(Boolean).join("   •   ")}
          </div>
          {params.get("profile") === "1" && (
            <button
              onClick={() => navigate("/my-profile")}
              className="mt-4 flex w-full items-center justify-center gap-2 rounded-[14px] border border-white/25 py-3.5 font-bold"
            >
              <Icon name="person" size={20} />
              My Profile &amp; Password
            </button>
          )}
        </div>
      </div>
    );
  return (
    <Page title="QR Pass" back={false} width={1000}>
      <div className="grid gap-6 lg:grid-cols-[400px_1fr]">
        <ScreenshotGuard>
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
        </ScreenshotGuard>
        <Panel title="Pass details" icon="qr_code_2" iconColor="#10B981" className="self-start">
          <dl className="space-y-4 text-sm">
            <div>
              <dt className="text-xs text-muted">Pass code</dt>
              <dd className="mt-0.5 font-mono font-semibold">{code}</dd>
            </div>
            <div>
              <dt className="text-xs text-muted">Role</dt>
              <dd className="mt-0.5 font-semibold">{role}</dd>
            </div>
            {user.mobileNumber && (
              <div>
                <dt className="text-xs text-muted">Mobile</dt>
                <dd className="mt-0.5 font-semibold">{user.mobileNumber}</dd>
              </div>
            )}
          </dl>
          {params.get("profile") === "1" && (
            <Button full variant="outline" icon="person" className="mt-5" onClick={() => navigate("/my-profile")}>
              My Profile &amp; Password
            </Button>
          )}
        </Panel>
      </div>
    </Page>
  );
}

/** Participant "My Profile": header card, personal info, change password, logout. */
export function ParticipantProfile() {
  return useAppLayout() ? <ParticipantProfileApp /> : <ParticipantProfileWeb />;
}

function ParticipantProfileWeb() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const doLogout = useLogout();
  const photo = useProfilePhoto();
  if (!user) return null;
  const id = badgeIdOf(user);
  return (
    <Page title="My Profile" width={1000}>
      <div className="grid gap-5 lg:grid-cols-3">
        <div className="card flex flex-col items-center self-start p-6 text-center">
          <div className="eyebrow text-[#60A5FA]">ISDR 2026</div>
          <button onClick={photo.pick} className="relative mt-4" title="Change photo">
            <Avatar src={user.profilePic} name={user.name} size={104} />
            <span className="absolute bottom-0 right-0 flex h-9 w-9 items-center justify-center rounded-full border-2 border-card bg-accent">
              {photo.uploading ? <Spinner size={15} color="#fff" /> : <Icon name="photo_camera" size={17} />}
            </span>
          </button>
          {photo.input}
          <div className="mt-4 text-xl font-semibold">{user.name?.trim() || "Participant"}</div>
          <div className="mt-2 flex flex-wrap justify-center gap-2">
            <span className="rounded-md bg-accent/15 px-2.5 py-1 text-[11px] font-bold text-[#60A5FA]">
              {roleLabel(user).toUpperCase()}
            </span>
            {id && <span className="rounded-md bg-white/10 px-2.5 py-1 text-[11px] font-bold">ID: {id}</span>}
          </div>
        </div>
        <div className="space-y-5 lg:col-span-2">
          <Panel title="Personal Information" icon="person" bodyClass="grid py-2 sm:grid-cols-2">
            <InfoRow icon="phone" label="Mobile Number" value={String(user.mobileNumber ?? "")} />
            <InfoRow icon="email" label="Email Address" value={String(user.email ?? "")} />
            {user.apartmentName && (
              <InfoRow icon="confirmation_number" label="Registration / Package" value={String(user.apartmentName)} />
            )}
            {user.department && (
              <InfoRow icon="school" label="Institution / Department" value={String(user.department)} />
            )}
          </Panel>
          <Panel title="Account & Security" icon="shield" iconColor="#10B981" bodyClass="p-3">
            <button
              onClick={() => navigate("/change-password")}
              className="flex w-full items-center gap-3 rounded-lg px-3 py-3 text-left transition hover:bg-white/5"
            >
              <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-accent/15">
                <Icon name="lock" size={19} color="#3B82F6" />
              </span>
              <span className="flex-1">
                <span className="block text-sm font-semibold">Change Password</span>
                <span className="block text-xs text-muted">Update your account password</span>
              </span>
              <Icon name="chevron_right" color="#9CA3AF" />
            </button>
            <button
              onClick={doLogout}
              className="flex w-full items-center gap-3 rounded-lg px-3 py-3 text-left transition hover:bg-red-500/10"
            >
              <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-red-500/15">
                <Icon name="logout" size={19} color="#EF4444" />
              </span>
              <span className="flex-1">
                <span className="block text-sm font-semibold text-[#F87171]">Logout</span>
                <span className="block text-xs text-muted">Sign out of this device</span>
              </span>
            </button>
          </Panel>
        </div>
      </div>
    </Page>
  );
}
