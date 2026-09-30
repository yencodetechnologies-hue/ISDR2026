import { Icon, Spinner } from "../ui";

/**
 * Flutter Material 3 Switch as the app draws it (primary #3B82F6): 52×32 track;
 * on = blue track + large thumb, off = dark track with an outline + small grey thumb.
 */
export function AppSwitch({
  checked,
  onChange,
  disabled,
  activeThumb = "#DBEAFE",
}: {
  checked: boolean;
  onChange: (v: boolean) => void;
  disabled?: boolean;
  /** Thumb colour when on (SwitchListTile with activeThumbColor white uses #fff). */
  activeThumb?: string;
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
      className="relative h-8 w-[52px] shrink-0 rounded-full border-2 transition-colors disabled:opacity-40"
      style={{
        background: checked ? "#3B82F6" : "#2A2A36",
        borderColor: checked ? "#3B82F6" : "#8E8E98",
      }}
    >
      <span
        className="absolute top-1/2 -translate-y-1/2 rounded-full transition-all"
        style={
          checked
            ? { width: 24, height: 24, left: 22, background: activeThumb }
            : { width: 16, height: 16, left: 6, background: "#8E8E98" }
        }
      />
    </button>
  );
}

/** The app's search field: #1E1E2A fill, rounded 12, blue search icon, clear button. */
export function AppSearchField({
  value,
  onChange,
  placeholder,
}: {
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
}) {
  return (
    <div className="relative flex-1">
      <span className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2">
        <Icon name="search" size={20} color="#3B82F6" />
      </span>
      <input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className="w-full rounded-xl border border-white/[0.08] bg-field py-3 pl-11 pr-10 text-sm text-white outline-none placeholder:text-[13px] placeholder:text-[#94A3B8] focus:border-[1.5px] focus:border-accent"
      />
      {value && (
        <button
          onClick={() => onChange("")}
          aria-label="Clear"
          className="absolute right-1.5 top-1/2 flex h-9 w-9 -translate-y-1/2 items-center justify-center"
        >
          <Icon name="clear" size={18} color="#CBD5E1" />
        </button>
      )}
    </div>
  );
}

/** Square tinted icon button next to a search field (the app's "+" create button). */
export function AppSquareButton({ icon, onClick, title }: { icon: string; onClick: () => void; title?: string }) {
  return (
    <button
      onClick={onClick}
      title={title}
      aria-label={title}
      className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl border border-white/[0.08] bg-accent/[0.06]"
    >
      <Icon name={icon} size={24} color="#3B82F6" />
    </button>
  );
}

/** Flutter M3 FloatingActionButton.extended: fixed bottom-right, 56px, 16px corners. */
export function AppFab({ icon, label, onClick }: { icon: string; label: string; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      className="fixed bottom-4 right-4 z-30 flex h-14 items-center gap-3 rounded-2xl bg-accent pl-4 pr-5 text-sm font-medium shadow-[0_3px_8px_rgba(0,0,0,0.35)]"
    >
      <Icon name={icon} size={24} />
      {label}
    </button>
  );
}

/** Centered spinner for app lists. */
export function AppSpinner({ top = 120 }: { top?: number }) {
  return (
    <div className="flex justify-center" style={{ paddingTop: top }}>
      <Spinner size={30} />
    </div>
  );
}
