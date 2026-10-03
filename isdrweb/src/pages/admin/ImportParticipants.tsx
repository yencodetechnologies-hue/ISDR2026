/* eslint-disable @typescript-eslint/no-explicit-any */
import { useRef, useState } from "react";
import { Button, Icon, Modal, Select, Spinner } from "@/components/ui";
import { DEFAULT_TYPE_COLOR, normalizeHex } from "@/components/DelegateBadge";
import { post } from "@/lib/api";

/**
 * Import participants from an Excel sheet whose header row has the same fields
 * as the "Create participants" form:
 *   Participant type, Banner colour, Package, Title, First name, Middle name, Last name, Gender,
 *   Designation, Organization, ID no., Mobile no., Email, Food preference,
 *   Payment mode, UTR no., Address
 * Each row names its own package; a blank ID no. is generated automatically and a
 * blank Banner colour (hex, behind the participant type on the badge) means #167E5D.
 */

/** Template columns, in order, with the header spellings accepted for each. */
const COLUMNS: { label: string; required: boolean; keys: string[] }[] = [
  { label: "Participant type", required: true, keys: ["participanttype", "type"] },
  { label: "Banner colour", required: false, keys: ["bannercolour", "bannercolor", "colour", "color"] },
  { label: "Package", required: true, keys: ["package", "packagename"] },
  { label: "Title", required: true, keys: ["title"] },
  { label: "First name", required: true, keys: ["firstname"] },
  { label: "Middle name", required: false, keys: ["middlename"] },
  { label: "Last name", required: false, keys: ["lastname"] },
  { label: "Gender", required: true, keys: ["gender"] },
  { label: "Designation", required: true, keys: ["designation"] },
  { label: "Organization", required: false, keys: ["organization", "organisation", "institution"] },
  { label: "ID no.", required: false, keys: ["idno", "idnumber"] },
  { label: "Mobile no.", required: true, keys: ["mobileno", "mobile", "mobilenumber"] },
  { label: "Email", required: true, keys: ["email"] },
  { label: "Food preference", required: true, keys: ["foodpreference", "food"] },
  { label: "Payment mode", required: false, keys: ["paymentmode", "payment"] },
  { label: "UTR no.", required: false, keys: ["utrno", "utrnumber", "utr"] },
  { label: "Address", required: false, keys: ["address"] },
];

type Row = {
  rowNumber: number;
  participantType: string;
  participantTypeColor: string;
  packageName: string;
  title: string;
  firstName: string;
  middleName: string;
  lastName: string;
  gender: string;
  designation: string;
  institution: string;
  idNumber: string;
  address: string;
  mobileNumber: string;
  email: string;
  foodPreference: string;
  paymentMode: string;
  utrNumber: string;
};

type Parsed = { ready: Row[]; problems: { row: Row; issues: string[] }[]; duplicates: Row[]; existing: Row[] };

const CHUNK = 25;
const TITLE_MAP: Record<string, string> = { miss: "Ms", mrs: "Ms", ms: "Ms", mr: "Mr", dr: "Dr", prof: "Prof" };

const text = (v: any) => String(v ?? "").trim();
const key = (h: any) =>
  String(h ?? "")
    .toLowerCase()
    .replace(/[^a-z]/g, "");
const nameOf = (r: Row) => [r.title, r.firstName, r.lastName].filter(Boolean).join(" ");
/** Package name without a trailing "(₹…)" / "(Free)", lower-cased — the backend matches the same way. */
const packageKey = (s: string) =>
  s
    .replace(/\s*\(.*\)\s*$/, "")
    .trim()
    .toLowerCase();

function mapRow(get: (label: string) => any, rowNumber: number): Row {
  const rawTitle = text(get("Title")).replace(/\.$/, "");
  return {
    rowNumber,
    participantType: text(get("Participant type")),
    participantTypeColor: text(get("Banner colour")).toUpperCase(),
    packageName: text(get("Package")),
    title: TITLE_MAP[rawTitle.toLowerCase()] ?? rawTitle,
    firstName: text(get("First name")).toUpperCase(),
    middleName: text(get("Middle name")).toUpperCase(),
    lastName: text(get("Last name")).toUpperCase(),
    gender: text(get("Gender")).toLowerCase(),
    designation: text(get("Designation")),
    institution: text(get("Organization")),
    idNumber: text(get("ID no.")).toUpperCase(),
    address: text(get("Address")),
    mobileNumber: text(get("Mobile no.")).replace(/[^\d+]/g, ""),
    email: text(get("Email")).toLowerCase(),
    foodPreference: text(get("Food preference")),
    paymentMode: text(get("Payment mode")).toLowerCase(),
    utrNumber: text(get("UTR no.")),
  };
}

/** The same checks as the form / backend, so problem rows show up before importing. */
function issuesOf(r: Row, pkg: any | null) {
  const bad: string[] = [];
  if (!r.participantType) bad.push("participant type");
  if (r.participantType.length > 60) bad.push("participant type too long");
  if (r.participantTypeColor && !normalizeHex(r.participantTypeColor))
    bad.push(`banner colour "${r.participantTypeColor}" (use hex like #167E5D)`);
  if (!r.packageName) bad.push("package");
  else if (!pkg) bad.push(`package "${r.packageName}" not on this event`);
  if (!["Dr", "Mr", "Mrs", "Ms", "Prof"].includes(r.title)) bad.push(r.title ? `title "${r.title}"` : "title");
  if (!r.firstName) bad.push("first name");
  if (!["male", "female", "other"].includes(r.gender)) bad.push(r.gender ? `gender "${r.gender}"` : "gender");
  if (!r.designation) bad.push("designation");
  if (!/^\+?\d{10,13}$/.test(r.mobileNumber)) bad.push("mobile no.");
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(r.email)) bad.push("email");
  if (!/^(non[\s-]?veg(etarian)?|veg(etarian)?)$/i.test(r.foodPreference))
    bad.push(r.foodPreference ? `food preference "${r.foodPreference}"` : "food preference");
  const paid = !!pkg && (Number(pkg.rate) || 0) > 0;
  if (paid && !["cash", "card", "upi"].includes(r.paymentMode))
    bad.push(r.paymentMode ? `payment mode "${r.paymentMode}"` : "payment mode");
  return bad;
}

async function readSheet(file: File): Promise<{ rows: Row[]; error?: string }> {
  const XLSX = await import("xlsx");
  const wb = XLSX.read(await file.arrayBuffer(), { type: "array" });
  const sheet = wb.Sheets[wb.SheetNames[0]];
  if (!sheet) return { rows: [], error: "The file has no sheets" };
  const grid: any[][] = XLSX.utils.sheet_to_json(sheet, { header: 1, defval: "", raw: false });
  const headerIndex = grid.findIndex((r) => r.some((c) => key(c) === "firstname"));
  if (headerIndex < 0) return { rows: [], error: 'Could not find the header row (it needs a "First name" column)' };

  const headerKeys = grid[headerIndex].map(key);
  const colOf = new Map<string, number>();
  for (const c of COLUMNS) {
    const i = headerKeys.findIndex((h) => c.keys.includes(h));
    if (i >= 0) colOf.set(c.label, i);
  }
  const missing = COLUMNS.filter((c) => c.required && !colOf.has(c.label)).map((c) => c.label);
  if (missing.length) return { rows: [], error: `The sheet is missing these columns: ${missing.join(", ")}` };

  const rows: Row[] = [];
  for (let i = headerIndex + 1; i < grid.length; i++) {
    const line = grid[i];
    const get = (label: string) => (colOf.has(label) ? line[colOf.get(label)!] : "");
    // Blank rows — and template rows that only have the package pre-filled — are skipped.
    if (!["First name", "Last name", "Mobile no.", "Email"].some((label) => text(get(label)))) continue;
    rows.push(mapRow(get, i + 1));
  }
  return { rows };
}

const TEMPLATE_ROWS = 200;

/** Empty import sheet with the form's columns and the chosen package filled in on every row. */
async function downloadTemplate(packageName: string) {
  const XLSX = await import("xlsx");
  const header = COLUMNS.map((c) => c.label);
  const pkgCol = header.indexOf("Package");
  const body = Array.from({ length: TEMPLATE_ROWS }, () => header.map((_, i) => (i === pkgCol ? packageName : "")));
  const ws = XLSX.utils.aoa_to_sheet([header, ...body]);
  ws["!cols"] = header.map((h) => ({ wch: Math.max(14, h === "Package" ? packageName.length + 2 : h.length + 4) }));
  // Keep Mobile no. / ID no. / UTR no. as text so Excel doesn't turn them into numbers.
  const textCols = ["Mobile no.", "ID no.", "UTR no."].map((l) => header.indexOf(l));
  for (let r = 1; r <= TEMPLATE_ROWS; r++)
    for (const c of textCols) ws[XLSX.utils.encode_cell({ r, c })] = { t: "s", v: "", z: "@" };
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, "Participants");
  const safe = packageName.replace(/[^\w-]+/g, "_").replace(/^_+|_+$/g, "") || "participants";
  XLSX.writeFile(wb, `import_template_${safe}.xlsx`);
}

export function ImportParticipantsModal({
  eventId,
  packages,
  registrations,
  onClose,
  onDone,
}: {
  eventId: string;
  packages: any[];
  registrations: any[];
  onClose: () => void;
  onDone: () => void;
}) {
  const fileRef = useRef<HTMLInputElement>(null);
  const [templatePkg, setTemplatePkg] = useState(packages.length ? String(packages[0].id) : "");
  const [downloading, setDownloading] = useState(false);
  const templatePackage = packages.find((p) => String(p.id) === templatePkg) ?? null;
  const [fileName, setFileName] = useState("");
  const [rows, setRows] = useState<Row[] | null>(null);
  const [reading, setReading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [progress, setProgress] = useState<{ done: number; total: number } | null>(null);
  const [result, setResult] = useState<{ created: any[]; failed: { line: string; error: string }[] } | null>(null);

  const packageFor = (name: string) =>
    packages.find((p) => packageKey(String(p.name ?? "")) === packageKey(name)) ?? null;

  const parsed: Parsed | null = (() => {
    if (!rows) return null;
    const registered = new Set(
      registrations.map((r) => String(r.mobileNumber ?? "").replace(/[^\d+]/g, "")).filter(Boolean),
    );
    const usedIds = new Set(
      registrations
        .map((r) =>
          String(r.idNumber ?? "")
            .trim()
            .toLowerCase(),
        )
        .filter(Boolean),
    );
    const seen = new Set<string>();
    const out: Parsed = { ready: [], problems: [], duplicates: [], existing: [] };
    for (const r of rows) {
      if (r.mobileNumber && seen.has(r.mobileNumber)) {
        out.duplicates.push(r);
        continue;
      }
      if (r.mobileNumber) seen.add(r.mobileNumber);
      if (r.mobileNumber && registered.has(r.mobileNumber)) {
        out.existing.push(r);
        continue;
      }
      const issues = issuesOf(r, packageFor(r.packageName));
      if (r.idNumber) {
        if (usedIds.has(r.idNumber.toLowerCase())) issues.push(`ID no. "${r.idNumber}" already used`);
        else usedIds.add(r.idNumber.toLowerCase());
      }
      if (issues.length) out.problems.push({ row: r, issues });
      else out.ready.push(r);
    }
    return out;
  })();

  const pick = async (f: File) => {
    setError(null);
    setResult(null);
    setReading(true);
    try {
      const res = await readSheet(f);
      if (res.error) {
        setRows(null);
        setError(res.error);
      } else if (!res.rows.length) {
        setRows(null);
        setError("No participant rows found in this file");
      } else {
        setRows(res.rows);
        setFileName(f.name);
      }
    } catch (e) {
      setRows(null);
      setError(`Could not read the file: ${(e as Error)?.message ?? e}`);
    }
    setReading(false);
  };

  const runImport = async () => {
    if (!parsed || !parsed.ready.length) return;
    const list = parsed.ready;
    const created: any[] = [];
    const failed: { line: string; error: string }[] = [];
    setProgress({ done: 0, total: list.length });
    for (let i = 0; i < list.length; i += CHUNK) {
      const part = list.slice(i, i + CHUNK);
      const res = await post(`/managed-events/${eventId}/registrations/bulk`, { participants: part });
      if (res.success) {
        created.push(...(res.registrations ?? []));
        failed.push(...(res.failed ?? []));
      } else {
        for (const r of part)
          failed.push({ line: `Row ${r.rowNumber}: ${nameOf(r)}`, error: res.error || "Failed to register" });
      }
      setProgress({ done: Math.min(i + CHUNK, list.length), total: list.length });
    }
    setProgress(null);
    setResult({ created, failed });
    onDone();
  };

  const importing = !!progress;
  const ids = (result?.created ?? []).map((r) => String(r.idNumber ?? "")).filter(Boolean);

  return (
    <Modal
      open
      onClose={importing ? () => {} : onClose}
      title="Import participants from Excel"
      width={780}
      footer={
        result ? (
          <Button onClick={onClose}>Done</Button>
        ) : (
          <>
            <Button variant="outline" disabled={importing} onClick={onClose}>
              Cancel
            </Button>
            <Button icon="upload" loading={importing} disabled={!parsed?.ready.length} onClick={runImport}>
              {parsed?.ready.length
                ? `Import ${parsed.ready.length} participant${parsed.ready.length === 1 ? "" : "s"}`
                : "Import"}
            </Button>
          </>
        )
      }
    >
      {result ? (
        <div>
          <div className="flex items-center gap-3 rounded-xl border border-[#22C55E]/30 bg-[#22C55E]/10 p-4">
            <Icon name="check_circle" size={28} color="#22C55E" />
            <div>
              <div className="font-semibold">
                {result.created.length} participant{result.created.length === 1 ? "" : "s"} registered
                {result.failed.length ? `, ${result.failed.length} failed` : ""}
              </div>
              {ids.length > 0 && (
                <div className="text-sm text-white/70">
                  ID numbers {ids[0]}
                  {ids.length > 1 ? ` … ${ids[ids.length - 1]}` : ""}
                </div>
              )}
            </div>
          </div>
          {result.failed.length > 0 && (
            <div className="mt-4">
              <div className="eyebrow mb-2">Failed rows</div>
              <div className="max-h-64 divide-y divide-line overflow-y-auto rounded-lg border border-line">
                {result.failed.map((f, i) => (
                  <div key={i} className="px-3 py-2 text-sm">
                    <span className="font-semibold">{f.line}</span>
                    <span className="text-[#F87171]"> — {f.error}</span>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      ) : (
        <div className="space-y-5">
          <div className="rounded-lg border border-line bg-white/[0.02] p-4">
            <div className="text-sm font-semibold">Excel columns (header row)</div>
            <div className="mt-2 flex flex-wrap gap-1.5">
              {COLUMNS.map((c) => (
                <span
                  key={c.label}
                  className={`rounded-md px-2 py-1 text-xs font-semibold ${c.required ? "bg-accent/15 text-[#93C5FD]" : "bg-white/5 text-muted"}`}
                >
                  {c.label}
                  {c.required ? " *" : ""}
                </span>
              ))}
            </div>
            <div className="mt-2.5 text-xs text-muted">
              * required. Package must match a package name on this event
              {packages.length ? ` (${packages.map((p) => p.name).join(", ")})` : ""}. Leave ID no. blank to create it
              automatically. Payment mode (Cash / Card / UPI) is needed only for paid packages.
            </div>
            <div className="mt-4 flex flex-wrap items-end gap-3 border-t border-line pt-4">
              <div className="min-w-[220px] flex-1">
                <div className="label">Template package</div>
                <Select
                  value={templatePkg}
                  placeholder={packages.length ? "Select a package" : "Add a package to this event first"}
                  disabled={!packages.length}
                  onChange={setTemplatePkg}
                  options={packages.map((p) => ({
                    value: String(p.id),
                    label: `${p.name} (${(Number(p.rate) || 0) === 0 ? "Free" : `₹${p.rate}`})`,
                  }))}
                />
              </div>
              <Button
                variant="outline"
                icon="download"
                loading={downloading}
                disabled={!templatePackage}
                onClick={async () => {
                  if (!templatePackage) return;
                  setDownloading(true);
                  try {
                    await downloadTemplate(String(templatePackage.name));
                  } catch (e) {
                    setError(`Could not create the template: ${(e as Error)?.message ?? e}`);
                  }
                  setDownloading(false);
                }}
              >
                Download template
              </Button>
            </div>
          </div>

          <div>
            <div className="label">Excel file *</div>
            <button
              type="button"
              disabled={importing}
              onClick={() => fileRef.current?.click()}
              className="flex w-full items-center gap-4 rounded-xl border border-dashed border-white/15 bg-white/[0.02] px-5 py-5 text-left transition hover:border-accent/60 hover:bg-accent/5 disabled:opacity-50"
            >
              <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-lg bg-[#16A34A]/15">
                {reading ? <Spinner size={20} /> : <Icon name="table_view" color="#22C55E" />}
              </span>
              <span className="min-w-0 flex-1">
                <span className="block truncate font-semibold">{fileName || "Choose an .xlsx / .xls / .csv file"}</span>
                <span className="block text-xs text-muted">
                  The first sheet is read; rows below the header row are imported.
                </span>
              </span>
              <span className="text-sm font-semibold text-[#60A5FA]">{fileName ? "Change" : "Browse"}</span>
            </button>
            <input
              ref={fileRef}
              type="file"
              hidden
              accept=".xlsx,.xls,.csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,application/vnd.ms-excel,text/csv"
              onChange={(e) => {
                const f = e.target.files?.[0];
                e.target.value = "";
                if (f) pick(f);
              }}
            />
          </div>

          {error && (
            <div className="flex items-center gap-2 rounded-lg border border-red-500/30 bg-red-500/15 px-3 py-2.5 text-sm font-semibold text-[#F87171]">
              <Icon name="error" size={18} outline />
              {error}
            </div>
          )}

          {parsed && (
            <>
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
                {[
                  { label: "Ready to import", value: parsed.ready.length, color: "#22C55E" },
                  { label: "Need fixing", value: parsed.problems.length, color: "#EF4444" },
                  { label: "Duplicate mobile in file", value: parsed.duplicates.length, color: "#F59E0B" },
                  { label: "Already registered", value: parsed.existing.length, color: "#9CA3AF" },
                ].map((s) => (
                  <div key={s.label} className="rounded-lg border border-line bg-white/[0.02] p-3">
                    <div className="text-2xl font-extrabold" style={{ color: s.color }}>
                      {s.value}
                    </div>
                    <div className="text-xs text-muted">{s.label}</div>
                  </div>
                ))}
              </div>

              {progress && (
                <div>
                  <div className="mb-1.5 flex justify-between text-xs text-muted">
                    <span>Importing…</span>
                    <span>
                      {progress.done} / {progress.total}
                    </span>
                  </div>
                  <div className="h-2 overflow-hidden rounded-full bg-white/10">
                    <div
                      className="h-full rounded-full bg-accent transition-all"
                      style={{ width: `${(progress.done / progress.total) * 100}%` }}
                    />
                  </div>
                </div>
              )}

              {parsed.problems.length > 0 && (
                <div>
                  <div className="eyebrow mb-2">Rows that need fixing (skipped)</div>
                  <div className="max-h-48 divide-y divide-line overflow-y-auto rounded-lg border border-line">
                    {parsed.problems.map(({ row, issues }) => (
                      <div key={row.rowNumber} className="px-3 py-2 text-sm">
                        <span className="font-semibold">
                          Row {row.rowNumber}: {nameOf(row) || "(no name)"}
                        </span>
                        <span className="text-[#F87171]"> — missing / invalid: {issues.join(", ")}</span>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {(parsed.duplicates.length > 0 || parsed.existing.length > 0) && (
                <div>
                  <div className="eyebrow mb-2">Skipped</div>
                  <div className="max-h-40 divide-y divide-line overflow-y-auto rounded-lg border border-line">
                    {parsed.duplicates.map((r) => (
                      <div key={`d${r.rowNumber}`} className="px-3 py-2 text-sm text-white/75">
                        Row {r.rowNumber}: {nameOf(r)} ({r.mobileNumber}) — same mobile as an earlier row
                      </div>
                    ))}
                    {parsed.existing.map((r) => (
                      <div key={`e${r.rowNumber}`} className="px-3 py-2 text-sm text-white/75">
                        Row {r.rowNumber}: {nameOf(r)} ({r.mobileNumber}) — already registered for this event
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {parsed.ready.length > 0 && (
                <div>
                  <div className="eyebrow mb-2">Preview</div>
                  <div className="max-h-56 overflow-auto rounded-lg border border-line">
                    <table className="data-table text-xs">
                      <thead>
                        <tr>
                          <th>Row</th>
                          <th>Name</th>
                          <th>Type</th>
                          <th>Package</th>
                          <th>ID no.</th>
                          <th>Mobile</th>
                          <th>Payment</th>
                        </tr>
                      </thead>
                      <tbody>
                        {parsed.ready.slice(0, 50).map((r) => (
                          <tr key={r.rowNumber}>
                            <td className="text-muted">{r.rowNumber}</td>
                            <td className="font-medium">{nameOf(r)}</td>
                            <td>
                              <span className="flex items-center gap-2">
                                <span
                                  className="h-3.5 w-3.5 shrink-0 rounded border border-line"
                                  style={{ background: normalizeHex(r.participantTypeColor) ?? DEFAULT_TYPE_COLOR }}
                                />
                                {r.participantType}
                              </span>
                            </td>
                            <td>{packageFor(r.packageName)?.name ?? r.packageName}</td>
                            <td className="font-mono">{r.idNumber || <span className="text-muted">Auto</span>}</td>
                            <td>{r.mobileNumber}</td>
                            <td>{r.paymentMode.toUpperCase() || "—"}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                  {parsed.ready.length > 50 && (
                    <div className="mt-1.5 text-xs text-muted">Showing the first 50 of {parsed.ready.length}.</div>
                  )}
                </div>
              )}
            </>
          )}
        </div>
      )}
    </Modal>
  );
}
