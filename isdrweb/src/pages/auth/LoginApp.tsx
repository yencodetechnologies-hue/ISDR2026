import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { Icon, Spinner } from "@/components/ui";
import { asset } from "@/lib/api";

/** Poster is 1024×933: height = width / this. */
const HERO_ASPECT = 1024 / 933;
/** Room kept for the login card (the poster gives up its bottom to make it fit). */
const CARD_SLOT = 404;
/** How far the card pulls up over the poster's white curve. */
const CARD_OVERLAP = 28;
const FOOTER_H = 100;

type Props = {
  identifier: string;
  setIdentifier: (v: string) => void;
  password: string;
  setPassword: (v: string) => void;
  remember: boolean;
  setRemember: (v: boolean) => void;
  errors: { id?: string; pw?: string };
  loading: boolean;
  onSubmit: (e: React.FormEvent) => void;
};

/** The app's _buildTextField: light filled field, round blue icon badge, 16px corners. */
function Field({
  icon,
  error,
  suffix,
  ...input
}: React.InputHTMLAttributes<HTMLInputElement> & { icon: string; error?: string; suffix?: React.ReactNode }) {
  return (
    <div>
      <div
        className={`flex items-center rounded-2xl border bg-[#F8FAFC] transition-colors focus-within:border-[1.5px] ${
          error ? "border-[#EF4444]" : "border-[#E2E8F0] focus-within:border-[#2563EB]"
        }`}
      >
        <span className="m-[9px] flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-[#2563EB]/10">
          <Icon name={icon} outline size={15} color="#2563EB" />
        </span>
        <input
          {...input}
          className="min-w-0 flex-1 bg-transparent py-[13px] pr-3 text-sm font-medium text-[#0F172A] outline-none placeholder:font-normal placeholder:text-[#94A3B8] disabled:opacity-60"
        />
        {suffix}
      </div>
      {error && <div className="ml-3 mt-1.5 text-xs text-[#EF4444]">{error}</div>}
    </div>
  );
}

/** The app's _FooterWave: three layered blue waves, a sparkle and the rounded pill. */
function FooterWave() {
  return (
    <div className="relative w-full shrink-0" style={{ height: FOOTER_H }}>
      <svg className="absolute inset-0 h-full w-full" viewBox="0 0 100 100" preserveAspectRatio="none">
        <defs>
          <linearGradient id="lw1" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" stopColor="#D6EBFE" />
            <stop offset="0.5" stopColor="#A5D2FD" />
            <stop offset="1" stopColor="#70B8F8" />
          </linearGradient>
          <linearGradient id="lw2" x1="0" y1="0" x2="1" y2="0">
            <stop offset="0" stopColor="#38BDF8" />
            <stop offset="0.5" stopColor="#0284C7" />
            <stop offset="1" stopColor="#1D70D8" />
          </linearGradient>
          <linearGradient id="lw3" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#1565C0" />
            <stop offset="0.5" stopColor="#0D47A1" />
            <stop offset="1" stopColor="#0A3470" />
          </linearGradient>
        </defs>
        <path d="M0 20 C14 34 32 20 60 4 C76 -4 88 6 100 22 L100 100 L0 100 Z" fill="url(#lw1)" />
        <path d="M0 44 C16 52 34 32 62 16 C78 8 90 22 100 40 L100 100 L0 100 Z" fill="url(#lw2)" />
        <path d="M0 66 C20 64 36 34 52 28 C72 22 86 44 100 62 L100 100 L0 100 Z" fill="url(#lw3)" />
      </svg>
      {/* Sparkle on the back wave (80% across, 9% down). */}
      <svg className="absolute" style={{ left: "calc(80% - 24px)", top: 9 - 24 }} width="48" height="48" viewBox="-24 -24 48 48">
        <defs>
          <radialGradient id="lglow">
            <stop offset="0" stopColor="#fff" stopOpacity="0.75" />
            <stop offset="1" stopColor="#fff" stopOpacity="0" />
          </radialGradient>
        </defs>
        <circle r="24" fill="url(#lglow)" />
        <path d="M0 -11 Q0 0 11 0 Q0 0 0 11 Q0 0 -11 0 Q0 0 0 -11 Z" fill="#fff" fillOpacity="0.95" />
      </svg>
      <span className="absolute bottom-3 left-1/2 h-[3.5px] w-[115px] -translate-x-1/2 rounded-[10px] bg-white/90" />
    </div>
  );
}

/** Login at phone width — the app's LoginPage (_buildPhoneBody). */
export default function LoginApp(p: Props) {
  const [show, setShow] = useState(false);
  const [size, setSize] = useState(() => ({ w: window.innerWidth, h: window.innerHeight }));
  const [keyboard, setKeyboard] = useState(false);

  useEffect(() => {
    const vv = window.visualViewport;
    const onResize = () => {
      setSize({ w: window.innerWidth, h: window.innerHeight });
      // The on-screen keyboard shrinks the visual viewport; hide the footer like the app does.
      if (vv) setKeyboard(window.innerHeight - vv.height > 120);
    };
    window.addEventListener("resize", onResize);
    vv?.addEventListener("resize", onResize);
    return () => {
      window.removeEventListener("resize", onResize);
      vv?.removeEventListener("resize", onResize);
    };
  }, []);

  const footer = keyboard ? 0 : FOOTER_H;
  const heroH = Math.max(0, Math.min(size.w / HERO_ASPECT, size.h - footer - CARD_SLOT));

  return (
    <div className="flex h-[100dvh] flex-col overflow-hidden bg-white">
      {heroH > 0 && (
        <div className="w-full shrink-0 overflow-hidden" style={{ height: heroH }}>
          {/* The poster's first 8 of 933 rows are a dark border — pulled up out of view. */}
          <img
            src={asset("login-poster.jpeg")}
            alt="36th ISDR International Conference"
            className="w-full object-cover object-top"
            style={{
              height: heroH + (size.w * 8) / 1024,
              marginTop: -(size.w * 8) / 1024,
              maskImage: "linear-gradient(to bottom, #000 0%, #000 94%, transparent 99%)",
              WebkitMaskImage: "linear-gradient(to bottom, #000 0%, #000 94%, transparent 99%)",
            }}
          />
        </div>
      )}
      <div className="min-h-0 flex-1 overflow-y-auto px-7" style={{ marginTop: heroH > 0 ? -CARD_OVERLAP : 0 }}>
        <form
          onSubmit={p.onSubmit}
          noValidate
          className="relative rounded-3xl bg-white px-[22px] pb-5 pt-[22px] shadow-[0_10px_30px_rgba(15,23,42,0.10)]"
        >
          <div className="flex items-center justify-center gap-2.5">
            <span className="h-px w-[26px] bg-[#CBD5E1]" />
            <span className="flex h-[50px] w-[50px] items-center justify-center rounded-full bg-[#2563EB]/10">
              <Icon name="person" size={25} color="#2563EB" />
            </span>
            <span className="h-px w-[26px] bg-[#CBD5E1]" />
          </div>
          <div className="mt-2.5 text-center font-outfit text-[22px] font-extrabold text-[#0F172A]">Welcome Back</div>
          <div className="mt-[3px] text-center text-xs font-medium text-[#64748B]">Sign in to access your portal</div>
          <div className="mt-[18px] space-y-3">
            <Field
              icon="mail"
              type="text"
              inputMode="email"
              autoComplete="username"
              placeholder="Email or mobile number"
              value={p.identifier}
              onChange={(e) => p.setIdentifier(e.target.value)}
              disabled={p.loading}
              error={p.errors.id}
            />
            <Field
              icon="lock"
              type={show ? "text" : "password"}
              autoComplete="current-password"
              placeholder="Password"
              value={p.password}
              onChange={(e) => p.setPassword(e.target.value)}
              disabled={p.loading}
              error={p.errors.pw}
              suffix={
                <button
                  type="button"
                  onClick={() => !p.loading && setShow((s) => !s)}
                  className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full"
                  aria-label={show ? "Hide password" : "Show password"}
                >
                  <Icon name={show ? "visibility_off" : "visibility"} outline color="#64748B" />
                </button>
              }
            />
          </div>
          <div className="mt-3 flex items-center">
            <button
              type="button"
              onClick={() => p.setRemember(!p.remember)}
              className="flex min-w-0 flex-1 items-center gap-[7px] text-left"
            >
              <span
                className={`flex h-[18px] w-[18px] shrink-0 items-center justify-center rounded-[5px] border-2 ${
                  p.remember ? "border-[#2563EB] bg-[#2563EB]" : "border-[#64748B]"
                }`}
              >
                {p.remember && <Icon name="check" size={14} color="#fff" />}
              </span>
              <span className="truncate text-[12.5px] font-medium text-[#334155]">Remember me</span>
            </button>
            <Link to="/forgot-password" className="truncate text-[12.5px] font-semibold text-[#2563EB]">
              Forgot Password?
            </Link>
          </div>
          <button
            type="submit"
            disabled={p.loading}
            className="mt-[18px] flex h-12 w-full items-center justify-center gap-[9px] rounded-full bg-gradient-to-r from-[#1D6BE8] to-[#1550D0] text-base font-semibold tracking-[0.2px] text-white shadow-[0_7px_18px_rgba(29,107,232,0.35)] active:brightness-95"
          >
            {p.loading ? (
              <Spinner size={22} color="#fff" />
            ) : (
              <>
                <Icon name="login" size={19} color="#fff" />
                Login
                <Icon name="arrow_forward" size={19} color="#fff" />
              </>
            )}
          </button>
        </form>
      </div>
      {!keyboard && <FooterWave />}
    </div>
  );
}
