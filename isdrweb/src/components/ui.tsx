/* eslint-disable react-refresh/only-export-components */
import { createContext, useCallback, useContext, useEffect, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import { AppLayoutContext, isAppLayoutActive } from "@/lib/appLayout";

/* ------------------------------------------------------------------ */
/* Basics                                                              */
/* ------------------------------------------------------------------ */

export function Icon({
  name,
  size = 22,
  color,
  outline,
  className = "",
}: {
  name: string;
  size?: number;
  color?: string;
  outline?: boolean;
  className?: string;
}) {
  return (
    <span
      className={`ms ${outline ? "ms-outline" : ""} ${className}`}
      style={{ fontSize: size, width: size, height: size, color }}
      aria-hidden
    >
      {name}
    </span>
  );
}

export function Spinner({ size = 26, color = "#3B82F6" }: { size?: number; color?: string }) {
  return (
    <span
      className="inline-block rounded-full border-[3px] border-white/10"
      style={{ width: size, height: size, borderTopColor: color, animation: "spin 0.8s linear infinite" }}
    />
  );
}

export function Loading({ label }: { label?: string }) {
  return (
    <div className="flex flex-col items-center justify-center gap-3 py-20 text-sm text-muted">
      <Spinner />
      {label}
    </div>
  );
}

export function Empty({
  icon = "inbox",
  title,
  subtitle,
  action,
}: {
  icon?: string;
  title: string;
  subtitle?: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="flex flex-col items-center rounded-xl border border-dashed border-white/10 px-6 py-14 text-center">
      <div className="flex h-14 w-14 items-center justify-center rounded-xl bg-accent/10">
        <Icon name={icon} outline size={28} color="#3B82F6" />
      </div>
      <div className="mt-4 text-base font-semibold">{title}</div>
      {subtitle && <div className="mt-1.5 max-w-sm text-sm text-muted">{subtitle}</div>}
      {action && <div className="mt-5">{action}</div>}
    </div>
  );
}

export function ErrorState({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div className="flex flex-col items-center rounded-xl border border-dashed border-red-500/25 px-6 py-14 text-center">
      <Icon name="error" outline size={40} color="#EF4444" />
      <div className="mt-3 text-sm text-white/80">{message}</div>
      {onRetry && (
        <Button variant="outline" className="mt-4" onClick={onRetry}>
          Retry
        </Button>
      )}
    </div>
  );
}

type BtnVariant = "primary" | "outline" | "ghost" | "danger" | "success";

export function Button({
  children,
  onClick,
  variant = "primary",
  loading,
  disabled,
  icon,
  className = "",
  type = "button",
  full,
  small,
  title,
}: {
  children?: React.ReactNode;
  onClick?: () => void;
  variant?: BtnVariant;
  loading?: boolean;
  disabled?: boolean;
  icon?: string;
  className?: string;
  type?: "button" | "submit";
  full?: boolean;
  small?: boolean;
  title?: string;
}) {
  const styles: Record<BtnVariant, string> = {
    primary: "bg-accent text-white shadow-sm shadow-accent/25 hover:bg-blue-500",
    outline: "border border-white/15 bg-white/[0.02] text-white hover:border-white/25 hover:bg-white/5",
    ghost: "text-accent hover:bg-accent/10",
    danger: "bg-danger text-white hover:bg-red-500",
    success: "bg-success text-white hover:bg-green-500",
  };
  return (
    <button
      type={type}
      title={title}
      onClick={onClick}
      disabled={disabled || loading}
      className={`inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-lg font-semibold transition disabled:cursor-not-allowed disabled:opacity-50 ${
        small ? "px-3 py-1.5 text-xs" : "px-4 py-2.5 text-sm"
      } ${full ? "w-full" : ""} ${styles[variant]} ${className}`}
    >
      {loading ? <Spinner size={16} color="#fff" /> : icon && <Icon name={icon} size={small ? 16 : 18} />}
      {children}
    </button>
  );
}

export function IconButton({
  icon,
  onClick,
  title,
  color = "#fff",
  size = 22,
  badge,
  disabled,
  outline,
}: {
  icon: string;
  onClick?: () => void;
  title?: string;
  color?: string;
  size?: number;
  badge?: number;
  disabled?: boolean;
  outline?: boolean;
}) {
  return (
    <button
      type="button"
      title={title}
      aria-label={title}
      onClick={onClick}
      disabled={disabled}
      className="relative inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-lg transition hover:bg-white/10 disabled:opacity-40"
    >
      <Icon name={icon} size={size} color={color} outline={outline} />
      {!!badge && badge > 0 && (
        <span className="absolute right-1 top-1 min-w-[16px] rounded-full bg-danger px-1 text-center text-[10px] font-bold leading-4 text-white">
          {badge > 99 ? "99+" : badge}
        </span>
      )}
    </button>
  );
}

export function Avatar({ src, name, size = 44 }: { src?: string | null; name?: string; size?: number }) {
  const [failed, setFailed] = useState(false);
  const initials = (name ?? "?")
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((s) => s[0]?.toUpperCase())
    .join("");
  return (
    <div
      className="flex shrink-0 items-center justify-center overflow-hidden rounded-full bg-field font-bold text-white/80"
      style={{ width: size, height: size, fontSize: size * 0.36 }}
    >
      {src && !failed ? (
        <img src={src} alt="" className="h-full w-full object-cover" onError={() => setFailed(true)} />
      ) : (
        initials || <Icon name="person" size={size * 0.55} color="#9CA3AF" />
      )}
    </div>
  );
}

export function Pill({ children, color = "#3B82F6" }: { children: React.ReactNode; color?: string }) {
  return (
    <span
      className="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[11px] font-bold"
      style={{ background: `${color}22`, color }}
    >
      {children}
    </span>
  );
}

/* ------------------------------------------------------------------ */
/* Form controls                                                       */
/* ------------------------------------------------------------------ */

export function Field({
  label,
  children,
  hint,
  error,
}: {
  label?: string;
  children: React.ReactNode;
  hint?: string;
  error?: string | null;
}) {
  return (
    <div>
      {label && <label className="label">{label}</label>}
      {children}
      {hint && !error && <div className="mt-1 text-xs text-muted">{hint}</div>}
      {error && <div className="mt-1 text-xs font-medium text-danger">{error}</div>}
    </div>
  );
}

export function Input(props: React.InputHTMLAttributes<HTMLInputElement> & { icon?: string }) {
  const { icon, className = "", ...rest } = props;
  if (!icon) return <input {...rest} className={`input ${className}`} />;
  return (
    <div className="relative">
      <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2">
        <Icon name={icon} outline size={20} color="#9CA3AF" />
      </span>
      <input {...rest} className={`input pl-10 ${className}`} />
    </div>
  );
}

export function PasswordInput(props: React.InputHTMLAttributes<HTMLInputElement> & { icon?: string }) {
  const [show, setShow] = useState(false);
  const { icon = "lock", className = "", ...rest } = props;
  return (
    <div className="relative">
      <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2">
        <Icon name={icon} outline size={20} color="#9CA3AF" />
      </span>
      <input {...rest} type={show ? "text" : "password"} className={`input pl-10 pr-11 ${className}`} />
      <button
        type="button"
        tabIndex={-1}
        onClick={() => setShow((s) => !s)}
        className="absolute right-2 top-1/2 flex h-8 w-8 -translate-y-1/2 items-center justify-center"
      >
        <Icon name={show ? "visibility_off" : "visibility"} outline size={20} color="#9CA3AF" />
      </button>
    </div>
  );
}

export function TextArea(props: React.TextareaHTMLAttributes<HTMLTextAreaElement>) {
  const { className = "", ...rest } = props;
  return <textarea rows={3} {...rest} className={`input resize-y ${className}`} />;
}

export function Select({
  value,
  onChange,
  options,
  placeholder,
  disabled,
  className = "",
}: {
  value: string;
  onChange: (v: string) => void;
  options: { value: string; label: string }[];
  placeholder?: string;
  disabled?: boolean;
  className?: string;
}) {
  return (
    <div className="relative">
      <select
        value={value}
        disabled={disabled}
        onChange={(e) => onChange(e.target.value)}
        className={`input appearance-none pr-10 disabled:opacity-50 ${value ? "" : "text-muted"} ${className}`}
      >
        {placeholder !== undefined && <option value="">{placeholder}</option>}
        {options.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
      <span className="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2">
        <Icon name="expand_more" size={20} color="#9CA3AF" />
      </span>
    </div>
  );
}

export function Switch({
  checked,
  onChange,
  disabled,
  color = "#3B82F6",
}: {
  checked: boolean;
  onChange: (v: boolean) => void;
  disabled?: boolean;
  color?: string;
}) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      disabled={disabled}
      onClick={(e) => {
        e.stopPropagation();
        onChange(!checked);
      }}
      className="relative h-6 w-11 shrink-0 rounded-full transition-colors disabled:opacity-50"
      style={{ background: checked ? color : "#374151" }}
    >
      <span
        className="absolute top-0.5 h-5 w-5 rounded-full bg-white transition-all"
        style={{ left: checked ? 22 : 2 }}
      />
    </button>
  );
}

export function Checkbox({
  checked,
  onChange,
  label,
  color = "#3B82F6",
}: {
  checked: boolean;
  onChange: (v: boolean) => void;
  label?: React.ReactNode;
  color?: string;
}) {
  return (
    <label className="inline-flex cursor-pointer items-center gap-2 text-sm">
      <span
        onClick={(e) => {
          e.preventDefault();
          onChange(!checked);
        }}
        className="flex h-5 w-5 items-center justify-center rounded-md border-2"
        style={{ borderColor: checked ? color : "#6B7280", background: checked ? color : "transparent" }}
      >
        {checked && <Icon name="check" size={16} color="#fff" />}
      </span>
      {label && <span onClick={() => onChange(!checked)}>{label}</span>}
    </label>
  );
}

/** A photo chooser: preview + choose/remove. */
export function PhotoInput({
  file,
  url,
  onFile,
  onRemove,
  label = "Photo",
  round,
}: {
  file: File | null;
  url?: string | null;
  onFile: (f: File) => void;
  onRemove?: () => void;
  label?: string;
  round?: boolean;
}) {
  const ref = useRef<HTMLInputElement>(null);
  const [preview, setPreview] = useState<string | null>(null);
  useEffect(() => {
    if (!file) {
      setPreview(null);
      return;
    }
    const u = URL.createObjectURL(file);
    setPreview(u);
    return () => URL.revokeObjectURL(u);
  }, [file]);
  const shown = preview ?? url ?? null;
  return (
    <div className="flex items-center gap-3">
      <div
        className={`flex h-20 w-20 shrink-0 items-center justify-center overflow-hidden border border-line bg-field ${
          round ? "rounded-full" : "rounded-xl"
        }`}
      >
        {shown ? (
          <img src={shown} alt="" className="h-full w-full object-cover" />
        ) : (
          <Icon name="image" outline size={30} color="#6B7280" />
        )}
      </div>
      <div className="flex flex-wrap gap-2">
        <Button variant="outline" small icon="upload" onClick={() => ref.current?.click()}>
          {shown ? `Change ${label.toLowerCase()}` : `Choose ${label.toLowerCase()}`}
        </Button>
        {shown && onRemove && (
          <Button variant="ghost" small icon="delete" onClick={onRemove} className="!text-danger">
            Remove
          </Button>
        )}
      </div>
      <input
        ref={ref}
        type="file"
        accept="image/*"
        hidden
        onChange={(e) => {
          const f = e.target.files?.[0];
          if (f) onFile(f);
          e.target.value = "";
        }}
      />
    </div>
  );
}

export function SearchBox({
  value,
  onChange,
  placeholder = "Search...",
}: {
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
}) {
  return (
    <div className="relative">
      <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2">
        <Icon name="search" size={20} color="#9CA3AF" />
      </span>
      <input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className="input pl-10 pr-10"
      />
      {value && (
        <button
          className="absolute right-2 top-1/2 flex h-8 w-8 -translate-y-1/2 items-center justify-center"
          onClick={() => onChange("")}
        >
          <Icon name="close" size={18} color="#9CA3AF" />
        </button>
      )}
    </div>
  );
}

export function Tabs<T extends string>({
  tabs,
  value,
  onChange,
}: {
  tabs: { value: T; label: string; count?: number }[];
  value: T;
  onChange: (v: T) => void;
}) {
  return (
    <div className="flex gap-1 overflow-x-auto border-b border-line">
      {tabs.map((t) => {
        const on = value === t.value;
        return (
          <button
            key={t.value}
            onClick={() => onChange(t.value)}
            className={`relative -mb-px flex items-center gap-2 whitespace-nowrap border-b-2 px-4 py-2.5 text-sm font-semibold transition ${
              on ? "border-accent text-white" : "border-transparent text-muted hover:text-white"
            }`}
          >
            {t.label}
            {t.count !== undefined && (
              <span
                className={`rounded-full px-2 py-0.5 text-[11px] font-bold ${on ? "bg-accent/20 text-[#93C5FD]" : "bg-white/5 text-muted"}`}
              >
                {t.count}
              </span>
            )}
          </button>
        );
      })}
    </div>
  );
}

/** Pill-style filter chips (a row of toggle buttons). */
export function Chips<T extends string>({
  items,
  value,
  onChange,
}: {
  items: { value: T; label: string; icon?: string; color?: string; count?: number }[];
  value: T;
  onChange: (v: T) => void;
}) {
  return (
    <div className="flex flex-wrap gap-2">
      {items.map((it) => {
        const on = it.value === value;
        const c = it.color ?? "#3B82F6";
        return (
          <button
            key={it.value}
            onClick={() => onChange(it.value)}
            className="flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-sm font-semibold transition"
            style={{
              borderColor: on ? c : "rgba(255,255,255,0.1)",
              background: on ? `${c}22` : "transparent",
              color: on ? c : "#9CA3AF",
            }}
          >
            {it.icon && <Icon name={it.icon} size={16} />}
            {it.label}
            {it.count !== undefined && <span className="opacity-75">{it.count}</span>}
          </button>
        );
      })}
    </div>
  );
}

/** A card with a titled header row and a body. */
export function Panel({
  title,
  subtitle,
  icon,
  iconColor = "#3B82F6",
  action,
  children,
  className = "",
  bodyClass = "p-5",
}: {
  title?: React.ReactNode;
  subtitle?: React.ReactNode;
  icon?: string;
  iconColor?: string;
  action?: React.ReactNode;
  children: React.ReactNode;
  className?: string;
  bodyClass?: string;
}) {
  return (
    <section className={`card overflow-hidden ${className}`}>
      {title !== undefined && (
        <div className="flex items-center gap-3 border-b border-line px-5 py-3.5">
          {icon && (
            <span
              className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg"
              style={{ background: `${iconColor}22` }}
            >
              <Icon name={icon} size={18} color={iconColor} />
            </span>
          )}
          <div className="min-w-0 flex-1">
            <div className="truncate text-[15px] font-semibold">{title}</div>
            {subtitle && <div className="truncate text-xs text-muted">{subtitle}</div>}
          </div>
          {action}
        </div>
      )}
      <div className={bodyClass}>{children}</div>
    </section>
  );
}

/** A metric card: icon, big value, label. */
export function StatCard({
  icon,
  color,
  label,
  value,
  hint,
  onClick,
}: {
  icon: string;
  color: string;
  label: string;
  value: React.ReactNode;
  hint?: string;
  onClick?: () => void;
}) {
  const Tag = onClick ? "button" : "div";
  return (
    <Tag
      onClick={onClick}
      className={`card relative overflow-hidden p-5 text-left ${onClick ? "card-hover cursor-pointer" : ""}`}
    >
      <div
        className="absolute -right-6 -top-6 h-24 w-24 rounded-full opacity-20 blur-2xl"
        style={{ background: color }}
      />
      <div className="flex items-start justify-between gap-3">
        <div>
          <div className="text-[13px] font-medium text-muted">{label}</div>
          <div className="mt-2 text-3xl font-extrabold tracking-tight">{value}</div>
          {hint && <div className="mt-1 text-xs text-muted">{hint}</div>}
        </div>
        <span
          className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl"
          style={{ background: `${color}22` }}
        >
          <Icon name={icon} size={22} color={color} />
        </span>
      </div>
    </Tag>
  );
}

/* ------------------------------------------------------------------ */
/* Page chrome                                                         */
/* ------------------------------------------------------------------ */

/**
 * The mobile app's dark app bar (buildDarkAppBar): #0A0A12, back arrow on the
 * left, centred white title (Inter 20 / 600), action icons on the right.
 */
export function AppBar({
  title,
  actions,
  back = true,
  onBack,
  outfit,
  titleClassName,
  bg = "#0A0A12",
}: {
  title?: React.ReactNode;
  actions?: React.ReactNode;
  back?: boolean;
  onBack?: () => void;
  /** Title in Outfit 18 / 700 (pages that set GoogleFonts.outfit on their title). */
  outfit?: boolean;
  /** Overrides the title font classes (e.g. "text-[18px] font-bold"). */
  titleClassName?: string;
  bg?: string;
}) {
  const navigate = useNavigate();
  return (
    <header className="sticky top-0 z-30" style={{ background: bg }}>
      {/* Like Flutter's centred title: centred when it fits, otherwise squeezed between back and actions. */}
      <div className="flex h-14 items-center px-1">
        {back ? (
          <button
            onClick={onBack ?? (() => (window.history.length > 1 ? navigate(-1) : navigate("/")))}
            className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full active:bg-white/10"
            aria-label="Back"
          >
            <Icon name="arrow_back" size={24} />
          </button>
        ) : (
          <span className="w-3 shrink-0" />
        )}
        <span
          className={`min-w-0 flex-1 truncate px-1 text-center text-white ${titleClassName ?? (outfit ? "font-outfit text-[18px] font-bold" : "text-[20px] font-semibold")}`}
        >
          {title}
        </span>
        {actions ? (
          <div className="flex shrink-0 items-center pr-1">{actions}</div>
        ) : (
          <span className={back ? "w-12 shrink-0" : "w-3 shrink-0"} />
        )}
      </div>
    </header>
  );
}

/** A page inside the website shell: back link, title, subtitle, actions, then the content. */
export function Page({
  title,
  subtitle,
  actions,
  back = true,
  onBack,
  children,
  width = 1200,
  eyebrow,
}: {
  title?: React.ReactNode;
  subtitle?: React.ReactNode;
  actions?: React.ReactNode;
  back?: boolean;
  onBack?: () => void;
  children: React.ReactNode;
  /** Max content width in px (forms use a narrower column). */
  width?: number;
  eyebrow?: React.ReactNode;
}) {
  const navigate = useNavigate();
  const app = useContext(AppLayoutContext);
  if (app)
    return (
      <div className="min-h-screen bg-bg pb-8">
        <AppBar title={title} back={back} onBack={onBack} />
        <div className="px-4 pt-2">
          {actions && <div className="mb-4 flex flex-wrap items-center gap-2">{actions}</div>}
          {children}
        </div>
      </div>
    );
  return (
    <main className="mx-auto w-full px-4 py-6 sm:px-6 lg:px-8 lg:py-8" style={{ maxWidth: Math.max(width, 480) + 64 }}>
      {back && (
        <button
          onClick={onBack ?? (() => (window.history.length > 1 ? navigate(-1) : navigate("/")))}
          className="mb-3 inline-flex items-center gap-1 text-[13px] font-medium text-muted transition hover:text-white"
        >
          <Icon name="arrow_back" size={17} />
          Back
        </button>
      )}
      {(title || actions) && (
        <div className="mb-6 flex flex-wrap items-end gap-x-4 gap-y-3">
          <div className="min-w-0 flex-1">
            {eyebrow && <div className="eyebrow mb-1">{eyebrow}</div>}
            <h1 className="text-2xl font-bold tracking-tight sm:text-[28px]">{title}</h1>
            {subtitle && <div className="mt-1 text-sm text-muted">{subtitle}</div>}
          </div>
          {actions && <div className="flex shrink-0 flex-wrap items-center gap-2">{actions}</div>}
        </div>
      )}
      {children}
    </main>
  );
}

/* ------------------------------------------------------------------ */
/* Overlays                                                            */
/* ------------------------------------------------------------------ */

export function Modal({
  open,
  onClose,
  title,
  children,
  footer,
  width = 520,
}: {
  open: boolean;
  onClose: () => void;
  title?: React.ReactNode;
  children: React.ReactNode;
  footer?: React.ReactNode;
  width?: number;
}) {
  const app = useContext(AppLayoutContext);
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, onClose]);
  if (!open) return null;
  if (app)
    return (
      <div className="animate-fade fixed inset-0 z-[90] flex items-end" onClick={onClose}>
        <div className="absolute inset-0 bg-black/55" />
        <div
          className="animate-sheet relative flex max-h-[92vh] w-full flex-col rounded-t-[20px] bg-card"
          onClick={(e) => e.stopPropagation()}
        >
          {title !== undefined && (
            <div className="flex items-center pb-1 pl-5 pr-2 pt-4">
              <div className="min-w-0 flex-1 truncate text-lg font-extrabold">{title}</div>
              <button
                onClick={onClose}
                aria-label="Close"
                className="flex h-12 w-12 items-center justify-center rounded-full active:bg-white/10"
              >
                <Icon name="close" size={24} />
              </button>
            </div>
          )}
          <div className="flex-1 overflow-y-auto px-5 pb-6 pt-2">{children}</div>
          {footer && <div className="flex justify-end gap-2 px-5 pb-5 pt-1">{footer}</div>}
        </div>
      </div>
    );
  return (
    <div className="animate-fade fixed inset-0 z-[90] flex items-center justify-center p-4" onClick={onClose}>
      <div className="absolute inset-0 bg-black/70 backdrop-blur-sm" />
      <div
        className="animate-sheet relative flex max-h-[90vh] w-full flex-col rounded-2xl border border-line bg-card shadow-2xl"
        style={{ maxWidth: width }}
        onClick={(e) => e.stopPropagation()}
      >
        {title !== undefined && (
          <div className="flex items-center gap-2 border-b border-line py-3 pl-6 pr-3">
            <div className="min-w-0 flex-1 truncate text-lg font-semibold">{title}</div>
            <IconButton icon="close" title="Close" onClick={onClose} />
          </div>
        )}
        <div className="flex-1 overflow-y-auto p-6">{children}</div>
        {footer && <div className="flex justify-end gap-2 border-t border-line px-6 py-4">{footer}</div>}
      </div>
    </div>
  );
}

type ToastKind = "info" | "success" | "error";
type ToastOpts = { onClick?: () => void; duration?: number; icon?: string };
const ToastCtx = createContext<(msg: string, kind?: ToastKind, opts?: ToastOpts) => void>(() => {});

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toasts, setToasts] = useState<{ id: number; msg: string; kind: ToastKind; onClick?: () => void; icon?: string }[]>([]);
  const show = useCallback((msg: string, kind: ToastKind = "info", opts?: ToastOpts) => {
    const id = Date.now() + Math.random();
    setToasts((t) => [...t, { id, msg, kind, onClick: opts?.onClick, icon: opts?.icon }]);
    setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), opts?.duration ?? 3200);
  }, []);
  return (
    <ToastCtx.Provider value={show}>
      {children}
      <div className="pointer-events-none fixed bottom-6 right-4 z-[100] flex w-[min(380px,calc(100vw-2rem))] flex-col items-end gap-2 sm:right-6">
        {toasts.map((t) => (
          <div
            key={t.id}
            role={t.onClick ? "button" : undefined}
            onClick={t.onClick}
            className={`animate-sheet pointer-events-auto flex w-full items-start gap-2.5 rounded-xl border border-white/10 px-4 py-3 text-left text-sm font-medium text-white shadow-2xl ${t.onClick ? "cursor-pointer" : ""}`}
            style={{ background: t.kind === "error" ? "#DC2626" : t.kind === "success" ? "#16A34A" : "#1F2937" }}
          >
            <Icon
              name={t.icon ?? (t.kind === "error" ? "error" : t.kind === "success" ? "check_circle" : "info")}
              size={19}
            />
            <span className="flex-1 whitespace-pre-wrap">{t.msg}</span>
          </div>
        ))}
      </div>
    </ToastCtx.Provider>
  );
}

export const useToast = () => useContext(ToastCtx);

type ConfirmOpts = {
  title: string;
  message?: string;
  confirm?: string;
  cancel?: string;
  danger?: boolean;
  /** App phone layout: confirm as a filled blue button (Flutter FilledButton) instead of a text button. */
  filled?: boolean;
};
const ConfirmCtx = createContext<(o: ConfirmOpts) => Promise<boolean>>(async () => false);

export function ConfirmProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState<(ConfirmOpts & { resolve: (v: boolean) => void }) | null>(null);
  const ask = useCallback((o: ConfirmOpts) => new Promise<boolean>((resolve) => setState({ ...o, resolve })), []);
  const close = (v: boolean) => {
    state?.resolve(v);
    setState(null);
  };
  // App phone layout: the app's Material AlertDialog instead of the website modal.
  if (state && isAppLayoutActive())
    return (
      <ConfirmCtx.Provider value={ask}>
        {children}
        <div
          className="animate-fade fixed inset-0 z-[95] flex items-center justify-center bg-black/55 px-10"
          onClick={() => close(false)}
        >
          <div
            className="w-full max-w-[340px] rounded-[20px] bg-card px-6 pb-4 pt-6"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="text-xl font-semibold">{state.title}</div>
            {state.message && <div className="mt-3 whitespace-pre-wrap text-sm text-white/75">{state.message}</div>}
            <div className="mt-5 flex items-center justify-end gap-2">
              <button
                onClick={() => close(false)}
                className="h-10 rounded-full px-3 text-sm font-medium text-accent active:bg-white/5"
              >
                {state.cancel ?? "Cancel"}
              </button>
              {state.danger || state.filled ? (
                <button
                  onClick={() => close(true)}
                  className={`h-10 rounded-full px-5 text-sm font-medium ${state.danger ? "bg-[#EF4444]" : "bg-accent"}`}
                >
                  {state.confirm ?? "OK"}
                </button>
              ) : (
                <button
                  onClick={() => close(true)}
                  className="h-10 rounded-full px-3 text-sm font-medium text-accent active:bg-white/5"
                >
                  {state.confirm ?? "OK"}
                </button>
              )}
            </div>
          </div>
        </div>
      </ConfirmCtx.Provider>
    );
  return (
    <ConfirmCtx.Provider value={ask}>
      {children}
      <Modal open={!!state} onClose={() => close(false)} width={420}>
        {state && (
          <div>
            <div className="text-lg font-bold">{state.title}</div>
            {state.message && <div className="mt-2 whitespace-pre-wrap text-sm text-white/70">{state.message}</div>}
            <div className="mt-6 flex justify-end gap-2">
              <Button variant="outline" onClick={() => close(false)}>
                {state.cancel ?? "Cancel"}
              </Button>
              <Button variant={state.danger ? "danger" : "primary"} onClick={() => close(true)}>
                {state.confirm ?? "OK"}
              </Button>
            </div>
          </div>
        )}
      </Modal>
    </ConfirmCtx.Provider>
  );
}

export const useConfirm = () => useContext(ConfirmCtx);
