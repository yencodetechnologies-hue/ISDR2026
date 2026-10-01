/* eslint-disable @typescript-eslint/no-explicit-any, react-refresh/only-export-components */
import { Icon } from "@/components/ui";

/** Filter dropdown for list toolbars: "All <label>" (value "") plus the given options. */
export function FilterSelect({
  label,
  value,
  onChange,
  options,
  className = "",
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  options: (string | { value: string; label: string })[];
  className?: string;
}) {
  const opts = options.map((o) => (typeof o === "string" ? { value: o, label: o } : o));
  return (
    <div className={`relative min-w-[150px] ${className}`}>
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        title={label}
        className={`input appearance-none pr-9 ${value ? "border-accent/60" : "text-white/70"}`}
      >
        <option value="">All {label}</option>
        {opts.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
      <span className="pointer-events-none absolute right-2.5 top-1/2 -translate-y-1/2">
        <Icon name="expand_more" size={20} color="#9CA3AF" />
      </span>
    </div>
  );
}

/** Every text in the item (nested objects / arrays too), lower-cased — for search boxes. */
export function textOf(v: any, depth = 0): string {
  if (v == null) return "";
  if (typeof v === "object") {
    if (depth > 3) return "";
    return Object.values(v)
      .map((x) => textOf(x, depth + 1))
      .join(" ");
  }
  return String(v).toLowerCase();
}

/** True when the search term is empty or found anywhere in the item. */
export const matches = (item: any, term: string) => {
  const t = term.trim().toLowerCase();
  return !t || textOf(item).includes(t);
};

/** Sorted distinct non-empty values, for filter options. */
export const distinct = (values: any[]) =>
  [...new Set(values.map((v) => String(v ?? "").trim()).filter(Boolean))].sort((a, b) => a.localeCompare(b));

/** The 2-letter ID code prefixes in use (SB, OT, OR, UG…), for the ID code range filter. */
export const idPrefixes = (regs: any[]) =>
  distinct(regs.map((r) => String(r.idNumber ?? "").trim().slice(0, 2).toUpperCase())).filter((p) => /^[A-Z]{2}$/.test(p));

/**
 * ID code range filter: the ID number starts with [prefix] and its number is between [from] and [to]
 * (inclusive; either may be left empty). "10", "0010" and "SB0010" all mean 10.
 */
export function inIdRange(r: any, prefix: string, from: string, to: string) {
  if (!prefix) return true;
  const id = String(r.idNumber ?? "").trim().toUpperCase();
  if (!id.startsWith(prefix)) return false;
  const num = (s: string) => parseInt(s.replace(/\D/g, ""), 10);
  const n = num(id.slice(2));
  const f = num(from);
  const t = num(to);
  if (!Number.isNaN(f) && !(n >= f)) return false;
  if (!Number.isNaN(t) && !(n <= t)) return false;
  return true;
}
