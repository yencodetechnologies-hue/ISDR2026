/* eslint-disable @typescript-eslint/no-explicit-any */
import { CARD_MM_H, CARD_MM_W, type BadgeData } from "@/components/DelegateBadge";

/**
 * List downloads: Excel (.xlsx), PDF and — for lists of people with a QR pass
 * (participants, speakers, admins, event staff) — a ZIP of every QR pass image.
 * The heavy libraries (exceljs, jspdf, jszip, qrcode) load only when used.
 */

export type ExportColumn<T> = {
  header: string;
  value: (row: T) => string | number | null | undefined;
  /** Relative width (Excel characters; PDF share of the page). */
  width?: number;
};

export type QrConfig<T> = {
  /** Text inside the QR (what the scanner reads). */
  code: (row: T) => string;
  /** Pass badge for the ZIP. */
  badge: (row: T) => BadgeData;
  /** File name (without .png) inside the ZIP. */
  fileName: (row: T) => string;
};

const text = (v: unknown) => (v == null ? "" : String(v));
const safeName = (s: string) =>
  s
    .replace(/[\\/:*?"<>|]+/g, "_")
    .replace(/\s+/g, " ")
    .trim() || "file";
const stamp = () => new Date().toISOString().slice(0, 10);

export function saveBlob(blob: Blob, fileName: string) {
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = fileName;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 2000);
}

/** Badge is 1080 × 1404: height = width × PASS_RATIO. */
const PASS_RATIO = 1404 / 1080;

/**
 * The full QR pass (badge) as a JPEG data URL, scaled down to [width] px so a
 * file with hundreds of passes stays small (the QR stays sharp enough to scan).
 */
export async function passDataUrl(data: BadgeData, width = 540) {
  const { renderBadgeBlob } = await import("@/components/DelegateBadge");
  const blob = await renderBadgeBlob(data);
  if (!blob) return null;
  const url = URL.createObjectURL(blob);
  try {
    const img = await new Promise<HTMLImageElement>((res, rej) => {
      const i = new Image();
      i.onload = () => res(i);
      i.onerror = rej;
      i.src = url;
    });
    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = Math.round(width * PASS_RATIO);
    const ctx = canvas.getContext("2d");
    if (!ctx) return null;
    ctx.fillStyle = "#fff";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.imageSmoothingQuality = "high";
    ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
    return canvas.toDataURL("image/jpeg", 0.88);
  } finally {
    URL.revokeObjectURL(url);
  }
}

/* ------------------------------------------------------------------ */
/* Excel                                                               */
/* ------------------------------------------------------------------ */

export async function exportExcel<T>(title: string, columns: ExportColumn<T>[], rows: T[], qr?: QrConfig<T>) {
  const ExcelJS = (await import("exceljs")).default;
  const wb = new ExcelJS.Workbook();
  const ws = wb.addWorksheet(title.slice(0, 31) || "Sheet1");
  const headers = [...columns.map((c) => c.header), ...(qr ? ["QR code", "QR pass"] : [])];
  ws.columns = [
    ...columns.map((c) => ({ width: c.width ?? Math.max(12, c.header.length + 4) })),
    ...(qr ? [{ width: 16 }, { width: 24 }] : []),
  ];
  const head = ws.addRow(headers);
  head.font = { bold: true, color: { argb: "FFFFFFFF" } };
  head.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FF1E3A8A" } };
  head.alignment = { vertical: "middle" };
  ws.views = [{ state: "frozen", ySplit: 1 }];

  for (let i = 0; i < rows.length; i++) {
    const r = rows[i];
    const code = qr ? qr.code(r) : "";
    const row = ws.addRow([...columns.map((c) => text(c.value(r))), ...(qr ? [code] : [])]);
    row.alignment = { vertical: "middle", wrapText: true };
    if (qr && code) {
      const pass = await passDataUrl(qr.badge(r));
      if (pass) {
        const w = 160;
        const h = Math.round(w * PASS_RATIO);
        row.height = h * 0.75 + 6; // points
        const img = wb.addImage({ base64: pass, extension: "jpeg" });
        // Full pass in the "QR pass" column (0-based column index = columns.length + 1).
        ws.addImage(img, { tl: { col: columns.length + 1 + 0.05, row: i + 1 + 0.03 }, ext: { width: w, height: h } });
      }
    }
  }
  const buf = await wb.xlsx.writeBuffer();
  saveBlob(
    new Blob([buf], { type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" }),
    `${safeName(title)}_${stamp()}.xlsx`,
  );
}

/* ------------------------------------------------------------------ */
/* PDF                                                                 */
/* ------------------------------------------------------------------ */

export async function exportPdf<T>(title: string, columns: ExportColumn<T>[], rows: T[], qr?: QrConfig<T>) {
  if (qr) return exportPassesPdf(title, rows, qr);
  const { jsPDF } = await import("jspdf");
  const doc = new jsPDF({ orientation: "landscape", unit: "pt", format: "a4" });
  const pageW = doc.internal.pageSize.getWidth();
  const pageH = doc.internal.pageSize.getHeight();
  const M = 28;
  const pad = 4;
  const fontSize = columns.length > 10 ? 6.5 : columns.length > 7 ? 7.5 : 9;
  const lineH = fontSize * 1.25;

  const weights = columns.map((c) => c.width ?? Math.max(10, c.header.length + 2));
  const totalW = weights.reduce((a, b) => a + b, 0);
  const avail = pageW - M * 2;
  const widths = weights.map((w) => (w / totalW) * avail);

  let y = M;
  const header = () => {
    doc.setFont("helvetica", "bold");
    doc.setFontSize(fontSize);
    const lines = columns.map((c, i) => doc.splitTextToSize(c.header, widths[i] - pad * 2) as string[]);
    const h = Math.max(...lines.map((l) => l.length)) * lineH + pad * 2;
    doc.setFillColor(30, 58, 138);
    doc.rect(M, y, pageW - M * 2, h, "F");
    doc.setTextColor(255, 255, 255);
    let x = M;
    lines.forEach((l, i) => {
      doc.text(l, x + pad, y + pad + fontSize);
      x += widths[i];
    });
    y += h;
    doc.setFont("helvetica", "normal");
    doc.setTextColor(15, 23, 42);
  };

  // Title
  doc.setFont("helvetica", "bold");
  doc.setFontSize(15);
  doc.setTextColor(15, 23, 42);
  doc.text(title, M, y + 12);
  doc.setFont("helvetica", "normal");
  doc.setFontSize(9);
  doc.setTextColor(100, 116, 139);
  doc.text(
    `${rows.length} ${rows.length === 1 ? "row" : "rows"} · Downloaded ${new Date().toLocaleString()}`,
    M,
    y + 26,
  );
  y += 38;
  header();

  for (let i = 0; i < rows.length; i++) {
    const r = rows[i];
    doc.setFontSize(fontSize);
    const cells = columns.map((c, ci) => doc.splitTextToSize(text(c.value(r)), widths[ci] - pad * 2) as string[]);
    const h = Math.max(...cells.map((l) => l.length), 1) * lineH + pad * 2;
    if (y + h > pageH - M) {
      doc.addPage();
      y = M;
      header();
    }
    if (i % 2 === 1) {
      doc.setFillColor(241, 245, 249);
      doc.rect(M, y, pageW - M * 2, h, "F");
    }
    let x = M;
    cells.forEach((l, ci) => {
      doc.text(l, x + pad, y + pad + fontSize);
      x += widths[ci];
    });
    doc.setDrawColor(226, 232, 240);
    doc.line(M, y + h, pageW - M, y + h);
    y += h;
  }
  doc.save(`${safeName(title)}_${stamp()}.pdf`);
}

/** Lists with QR passes: one 100 mm × 130 mm card per page, filling the page. */
async function exportPassesPdf<T>(title: string, rows: T[], qr: QrConfig<T>) {
  const { jsPDF } = await import("jspdf");
  const doc = new jsPDF({
    orientation: "portrait",
    unit: "mm",
    format: [CARD_MM_W, CARD_MM_H],
  });
  const printW = Math.round((CARD_MM_W / 25.4) * 300);
  let n = 0;
  for (const r of rows) {
    if (!qr.code(r)) continue;
    const pass = await passDataUrl(qr.badge(r), printW);
    if (!pass) continue;
    if (n > 0) doc.addPage([CARD_MM_W, CARD_MM_H], "portrait");
    doc.addImage(pass, "JPEG", 0, 0, CARD_MM_W, CARD_MM_H);
    n++;
  }
  if (!n) throw new Error("No QR passes to download");
  doc.save(`${safeName(title)}_QR_passes_${stamp()}.pdf`);
}

/* ------------------------------------------------------------------ */
/* ZIP of QR pass images                                               */
/* ------------------------------------------------------------------ */

export async function exportQrZip<T>(
  title: string,
  rows: T[],
  qr: QrConfig<T>,
  onProgress?: (done: number, total: number) => void,
) {
  const [{ default: JSZip }, { renderBadgeBlob }] = await Promise.all([
    import("jszip"),
    import("@/components/DelegateBadge"),
  ]);
  const zip = new JSZip();
  const used = new Set<string>();
  for (let i = 0; i < rows.length; i++) {
    const r = rows[i];
    const blob = await renderBadgeBlob(qr.badge(r));
    if (blob) {
      let name = safeName(qr.fileName(r));
      for (let n = 2; used.has(name.toLowerCase()); n++) name = `${safeName(qr.fileName(r))} (${n})`;
      used.add(name.toLowerCase());
      zip.file(`${name}.png`, blob);
    }
    onProgress?.(i + 1, rows.length);
  }
  const out = await zip.generateAsync({ type: "blob" });
  saveBlob(out, `${safeName(title)}_QR_passes_${stamp()}.zip`);
}

/** Shared helper: "Title First Middle Last" of a participant registration. */
export const fullNameOf = (r: any) => {
  const parts = [r?.firstName, r?.middleName, r?.lastName]
    .map((x) => String(x ?? "").trim().toUpperCase())
    .filter(Boolean);
  const title = String(r?.title ?? "").trim();
  if (parts.length) return [title, ...parts].filter(Boolean).join(" ");
  return String(r?.name ?? "").trim().toUpperCase();
};
