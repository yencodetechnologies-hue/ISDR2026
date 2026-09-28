import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Button, Icon, Input, PasswordInput, useToast } from "@/components/ui";
import { post } from "@/lib/api";

const RESEND_SECONDS = 60;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/** Email → 6-digit OTP → new password. */
export default function ForgotPassword() {
  const navigate = useNavigate();
  const toast = useToast();
  const [step, setStep] = useState(0);
  const [email, setEmail] = useState("");
  const [otp, setOtp] = useState("");
  const [pw, setPw] = useState("");
  const [pw2, setPw2] = useState("");
  const [busy, setBusy] = useState(false);
  const [resendLeft, setResendLeft] = useState(0);

  useEffect(() => {
    if (resendLeft <= 0) return;
    const t = setTimeout(() => setResendLeft((s) => s - 1), 1000);
    return () => clearTimeout(t);
  }, [resendLeft]);

  const requestOtp = async () => {
    const e = email.trim();
    if (!e) return toast("Please enter email address", "error");
    if (!EMAIL_RE.test(e)) return toast("Please enter a valid email address", "error");
    setBusy(true);
    const res = await post("/auth/forgot-password", { email: e });
    setBusy(false);
    if (!res.success) return toast(res.error || "Failed to send OTP", "error");
    setStep(1);
    setOtp("");
    setResendLeft(RESEND_SECONDS);
  };

  const verifyOtp = async () => {
    if (!/^\d{6}$/.test(otp.trim())) return toast("Please enter the 6-digit OTP", "error");
    setBusy(true);
    const res = await post("/auth/verify-otp", { email: email.trim(), otp: otp.trim() });
    setBusy(false);
    if (!res.success) return toast(res.error || "Invalid OTP", "error");
    setStep(2);
  };

  const reset = async () => {
    if (!pw || !pw2) return toast("Please enter new password and confirm password", "error");
    if (pw.length < 6) return toast("Password must be at least 6 characters long", "error");
    if (pw !== pw2) return toast("Passwords do not match", "error");
    setBusy(true);
    const res = await post("/auth/reset-password", { email: email.trim(), otp: otp.trim(), newPassword: pw });
    setBusy(false);
    if (!res.success) return toast(res.error || "Failed to reset password", "error");
    toast("Password reset successfully! Please login with your new password.", "success");
    navigate("/login", { replace: true });
  };

  const [title, subtitle] =
    step === 0
      ? ["Forgot Password", "Enter the email registered for your account."]
      : step === 1
        ? ["Enter OTP", `We sent a 6-digit code to ${email.trim()}`]
        : ["New Password", "Choose a new password for your account."];

  const check = (ok: boolean, text: string) => (
    <div className="flex items-center gap-1.5 text-xs" style={{ color: ok ? "#22C55E" : "#9CA3AF" }}>
      <Icon name={ok ? "check_circle" : "radio_button_unchecked"} size={16} />
      {text}
    </div>
  );

  return (
    <div className="flex min-h-screen items-center justify-center bg-bg px-4 py-10">
      <div className="card w-full max-w-sm p-6">
        <div className="flex items-center justify-between gap-2 text-xs text-muted">
          {["Email", "OTP", "Password"].map((s, i) => (
            <div key={s} className="flex items-center gap-1.5">
              <span
                className="flex h-6 w-6 items-center justify-center rounded-full text-[11px] font-bold"
                style={{ background: i <= step ? "#3B82F6" : "#1E1E2A", color: "#fff" }}
              >
                {i < step ? <Icon name="check" size={14} /> : i + 1}
              </span>
              <span style={{ color: i <= step ? "#fff" : undefined }}>{s}</span>
            </div>
          ))}
        </div>
        <div className="mt-6 text-xl font-extrabold">{title}</div>
        <div className="mt-1 text-sm text-muted">{subtitle}</div>
        <div className="mt-5 space-y-3">
          {step === 0 && (
            <>
              <label className="label">Email Address</label>
              <Input icon="mail" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="Registered account email" />
              <Button full loading={busy} icon="send" onClick={requestOtp}>
                Send OTP
              </Button>
            </>
          )}
          {step === 1 && (
            <>
              <Input
                value={otp}
                onChange={(e) => setOtp(e.target.value.replace(/\D/g, "").slice(0, 6))}
                placeholder="6-digit OTP"
                inputMode="numeric"
                className="text-center text-lg tracking-[0.5em]"
                autoFocus
              />
              <div className="text-center text-sm">
                {resendLeft > 0 ? (
                  <span className="text-muted">Resend code in 0:{String(resendLeft).padStart(2, "0")}</span>
                ) : (
                  <button className="font-semibold text-accent" disabled={busy} onClick={requestOtp}>
                    Resend OTP
                  </button>
                )}
              </div>
              <div className="flex gap-2">
                <Button
                  variant="outline"
                  className="flex-1"
                  disabled={busy}
                  onClick={() => {
                    setStep(0);
                    setResendLeft(0);
                    setOtp("");
                  }}
                >
                  Back
                </Button>
                <Button className="flex-[2]" loading={busy} icon="verified_user" onClick={verifyOtp}>
                  Verify OTP
                </Button>
              </div>
            </>
          )}
          {step === 2 && (
            <>
              <label className="label">New Password</label>
              <PasswordInput value={pw} onChange={(e) => setPw(e.target.value)} placeholder="New password" />
              <label className="label">Confirm Password</label>
              <PasswordInput value={pw2} onChange={(e) => setPw2(e.target.value)} placeholder="Confirm password" />
              <div className="space-y-1">
                {check(pw.length >= 6, "At least 6 characters")}
                {check(!!pw && pw === pw2, "Passwords match")}
              </div>
              <div className="flex gap-2">
                <Button variant="outline" className="flex-1" disabled={busy} onClick={() => setStep(1)}>
                  Back
                </Button>
                <Button className="flex-[2]" loading={busy} icon="lock_reset" onClick={reset}>
                  Reset Password
                </Button>
              </div>
            </>
          )}
        </div>
        <button onClick={() => navigate("/login", { replace: true })} className="mt-6 w-full text-center text-sm font-semibold text-accent">
          Back to Login
        </button>
      </div>
    </div>
  );
}
