import { useId, useState } from "react";
import { Icon, Spinner } from "../ui";

/**
 * Flutter outlined TextFormField with a floating label: the label sits inside
 * the field, and floats into a notch in the border when focused or filled.
 */
export function AppTextField({
  label,
  value,
  onChange,
  icon,
  type = "text",
  inputMode,
  maxLength,
  error,
  fill = "#0A0A12",
  outer = "#14141F",
  border = "rgba(255,255,255,0.08)",
  focus = "#3B82F6",
  iconColor = "#3B82F6",
  iconSize = 20,
  password,
  multiline,
  disabled,
  radius = 12,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  icon?: string;
  type?: string;
  inputMode?: React.HTMLAttributes<HTMLInputElement>["inputMode"];
  maxLength?: number;
  error?: string | null;
  /** Inside colour of the field. */
  fill?: string;
  /** Colour behind the field (fills the label notch). */
  outer?: string;
  border?: string;
  focus?: string;
  iconColor?: string;
  iconSize?: number;
  /** Adds the eye toggle. */
  password?: boolean;
  multiline?: boolean;
  disabled?: boolean;
  radius?: number;
}) {
  const id = useId();
  const [focused, setFocused] = useState(false);
  const [show, setShow] = useState(false);
  const floated = focused || value.length > 0;
  const lineColor = error ? "#EF4444" : focused ? focus : border;
  const common = {
    id,
    value,
    disabled,
    maxLength,
    onFocus: () => setFocused(true),
    onBlur: () => setFocused(false),
    className: `w-full bg-transparent text-sm font-medium text-white outline-none ${icon ? "pl-12" : "pl-3.5"} ${
      password ? "pr-12" : "pr-3.5"
    } ${multiline ? "min-h-[80px] resize-none py-3.5" : "py-3.5"}`,
  };
  return (
    <div>
      <div
        className="relative rounded-xl"
        style={{
          background: fill,
          borderRadius: radius,
          boxShadow: `inset 0 0 0 ${focused || error ? 1.5 : 1}px ${lineColor}`,
          opacity: disabled ? 0.6 : 1,
        }}
      >
        {icon && (
          <span className="pointer-events-none absolute left-3.5 top-[15px]">
            <Icon name={icon} size={iconSize} color={iconColor} />
          </span>
        )}
        <label
          htmlFor={id}
          className="pointer-events-none absolute transition-all duration-150"
          style={
            floated
              ? {
                  left: 12,
                  top: -8,
                  fontSize: 12,
                  fontWeight: 600,
                  color: error ? "#EF4444" : focused ? focus : "#9CA3AF",
                  padding: "0 4px",
                  background: `linear-gradient(to bottom, ${outer} 50%, ${fill} 50%)`,
                  lineHeight: "16px",
                }
              : {
                  left: icon ? 48 : 14,
                  top: 15,
                  fontSize: 13,
                  fontWeight: 500,
                  color: "#9CA3AF",
                  lineHeight: "18px",
                }
          }
        >
          {label}
        </label>
        {multiline ? (
          <textarea {...common} onChange={(e) => onChange(e.target.value)} />
        ) : (
          <input
            {...common}
            type={password ? (show ? "text" : "password") : type}
            inputMode={inputMode}
            onChange={(e) => onChange(e.target.value)}
          />
        )}
        {password && (
          <button
            type="button"
            tabIndex={-1}
            onClick={() => setShow((s) => !s)}
            className="absolute right-1 top-1/2 flex h-11 w-11 -translate-y-1/2 items-center justify-center"
            aria-label={show ? "Hide password" : "Show password"}
          >
            <Icon name={show ? "visibility_off" : "visibility"} size={22} color="#9CA3AF" />
          </button>
        )}
      </div>
      {error && <div className="ml-3 mt-1.5 text-xs text-[#EF4444]">{error}</div>}
    </div>
  );
}

/** Flutter DropdownButtonFormField (outlined, floating label, prefix icon, ▾). */
export function AppSelectField({
  label,
  value,
  onChange,
  options,
  icon,
  hint,
  disabled,
  fill = "#1E1E2A",
  outer = "#0A0A12",
  border = "rgba(255,255,255,0.1)",
  radius = 14,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  options: { value: string; label: string }[];
  icon?: string;
  /** Shown (in place of a value) when nothing is selected; the label then stays inside the field. */
  hint?: string;
  disabled?: boolean;
  fill?: string;
  outer?: string;
  border?: string;
  radius?: number;
}) {
  const id = useId();
  const [focused, setFocused] = useState(false);
  const selected = options.find((o) => o.value === value);
  const floated = focused || !!selected || !!hint;
  return (
    <div
      className="relative"
      style={{
        background: fill,
        borderRadius: radius,
        boxShadow: `inset 0 0 0 ${focused ? 2 : 1}px ${focused ? "#3B82F6" : border}`,
        opacity: disabled ? 0.55 : 1,
      }}
    >
      {icon && (
        <span className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2">
          <Icon name={icon} size={20} color="#3B82F6" />
        </span>
      )}
      <label
        htmlFor={id}
        className="pointer-events-none absolute transition-all duration-150"
        style={
          floated
            ? {
                left: 12,
                top: -8,
                fontSize: 12,
                color: focused ? "#3B82F6" : "#9CA3AF",
                padding: "0 4px",
                background: `linear-gradient(to bottom, ${outer} 50%, ${fill} 50%)`,
                lineHeight: "16px",
              }
            : { left: icon ? 48 : 14, top: 17, fontSize: 15, color: "#9CA3AF", lineHeight: "20px" }
        }
      >
        {label}
      </label>
      <select
        id={id}
        value={value}
        disabled={disabled}
        onFocus={() => setFocused(true)}
        onBlur={() => setFocused(false)}
        onChange={(e) => onChange(e.target.value)}
        className={`w-full appearance-none truncate bg-transparent py-4 pr-10 text-[15px] outline-none ${
          icon ? "pl-12" : "pl-3.5"
        } ${selected ? "text-white" : "text-transparent"}`}
      >
        {hint !== undefined && !selected && (
          <option value="" disabled hidden>
            {hint}
          </option>
        )}
        {options.map((o) => (
          <option key={o.value} value={o.value} className="text-white">
            {o.label}
          </option>
        ))}
      </select>
      {hint && !selected && (
        <span
          className="pointer-events-none absolute top-1/2 -translate-y-1/2 text-[15px] text-white/60"
          style={{ left: icon ? 48 : 14 }}
        >
          {hint}
        </span>
      )}
      <span className="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2">
        <Icon name="arrow_drop_down" size={24} color="#9CA3AF" />
      </span>
    </div>
  );
}

/**
 * Flutter InputDecorator with darkInputDecoration: a filled, outlined box whose label
 * sits floated on the border, prefix icon on the left, any content inside.
 */
export function AppDecorator({
  label,
  icon,
  children,
  onClick,
  fill = "#1E1E2A",
  outer = "#0A0A12",
  error,
}: {
  label: string;
  icon?: string;
  children: React.ReactNode;
  onClick?: () => void;
  fill?: string;
  outer?: string;
  error?: string | null;
}) {
  return (
    <div>
      <div
        onClick={onClick}
        className={`relative rounded-[14px] ${onClick ? "cursor-pointer active:brightness-110" : ""}`}
        style={{ background: fill, boxShadow: `inset 0 0 0 1px ${error ? "#EF4444" : "rgba(255,255,255,0.08)"}` }}
      >
        <span
          className="pointer-events-none absolute left-3 top-[-8px] px-1 text-xs leading-4"
          style={{
            color: error ? "#EF4444" : "#9CA3AF",
            background: `linear-gradient(to bottom, ${outer} 50%, ${fill} 50%)`,
          }}
        >
          {label}
        </span>
        <div className="flex items-start py-4 pr-3.5" style={{ paddingLeft: icon ? 0 : 14 }}>
          {icon && (
            <span className="flex w-12 shrink-0 justify-center pt-0.5">
              <Icon name={icon} size={20} color="#60A5FA" />
            </span>
          )}
          <div className="min-w-0 flex-1">{children}</div>
        </div>
      </div>
      {error && <div className="ml-3 mt-1.5 text-xs text-[#EF4444]">{error}</div>}
    </div>
  );
}

/** Flutter M3 FilterChip / ChoiceChip on the dark screens (accent when selected). */
export function AppChip({
  label,
  selected,
  onClick,
  check,
}: {
  label: string;
  selected: boolean;
  onClick: () => void;
  /** FilterChip shows a check mark when selected. */
  check?: boolean;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="inline-flex h-8 items-center gap-1.5 rounded-lg border px-3 text-sm font-semibold"
      style={{
        background: selected ? "#3B82F6" : "#14141F",
        borderColor: selected ? "#3B82F6" : "rgba(255,255,255,0.08)",
        color: selected ? "#fff" : "#9CA3AF",
      }}
    >
      {check && selected && <Icon name="check" size={18} />}
      {label}
    </button>
  );
}

/** The app's BrandGradientCtaButton: 50px, #13275D → #111827 gradient, 14px corners. */
export function AppCtaButton({
  label,
  icon,
  onClick,
  loading,
  disabled,
  height = 50,
}: {
  label: string;
  icon?: string;
  onClick?: () => void;
  loading?: boolean;
  disabled?: boolean;
  height?: number;
}) {
  const enabled = !!onClick && !loading && !disabled;
  return (
    <button
      onClick={enabled ? onClick : undefined}
      disabled={!enabled}
      className="flex w-full items-center justify-center gap-2 rounded-[14px] text-[14.5px] font-semibold"
      style={{
        height,
        background: enabled ? "linear-gradient(135deg, #13275D, #111827)" : "#D1D5DB",
        boxShadow: enabled ? "0 5px 12px rgba(19,39,93,0.25)" : undefined,
      }}
    >
      {loading ? (
        <Spinner size={22} color="#fff" />
      ) : (
        <>
          {icon && <Icon name={icon} size={20} />}
          {label}
        </>
      )}
    </button>
  );
}

/** Centered success dialog (check circle, title, message, OK button) — the app's _showSuccessDialog. */
export function AppSuccessDialog({
  title,
  message,
  onOk,
  okLabel = "OK",
}: {
  title: string;
  message: string;
  onOk: () => void;
  okLabel?: string;
}) {
  return (
    <div className="fixed inset-0 z-[95] flex items-center justify-center bg-black/55 p-10">
      <div className="w-full max-w-sm rounded-[20px] bg-card p-6 text-center">
        <div className="mx-auto flex h-20 w-20 items-center justify-center rounded-full bg-[#10B981]/10">
          <Icon name="check_circle" size={50} color="#10B981" />
        </div>
        <div className="mt-5 text-[22px] font-bold">{title}</div>
        <div className="mt-3 text-base text-white/70">{message}</div>
        <div className="mt-6">
          <AppCtaButton label={okLabel} icon="arrow_forward" onClick={onOk} />
        </div>
      </div>
    </div>
  );
}
