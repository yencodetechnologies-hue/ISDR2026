import { useEffect, useRef, useState } from "react";
import { Button, Icon, useToast } from "@/components/ui";
import { exportExcel, exportPdf, exportQrZip, type ExportColumn, type QrConfig } from "@/lib/exporter";

/**
 * "Download" button with Excel / PDF (and, for lists with QR passes, a ZIP of
 * every pass image). Downloads the rows currently shown (after search / filter).
 */
export default function ExportMenu<T>({
  title,
  rows,
  columns,
  qr,
  small,
}: {
  title: string;
  rows: T[] | null | undefined;
  columns: ExportColumn<T>[];
  qr?: QrConfig<T>;
  small?: boolean;
}) {
  const toast = useToast();
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState<string | null>(null);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const close = (e: MouseEvent) => {
      if (!ref.current?.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", close);
    return () => document.removeEventListener("mousedown", close);
  }, [open]);

  const run = async (kind: "excel" | "pdf" | "zip") => {
    setOpen(false);
    const list = rows ?? [];
    if (!list.length) return toast("Nothing to download", "error");
    setBusy(kind === "zip" ? `0 / ${list.length}` : kind);
    try {
      if (kind === "excel") await exportExcel(title, columns, list, qr);
      else if (kind === "pdf") await exportPdf(title, columns, list, qr);
      else if (qr) await exportQrZip(title, list, qr, (d, t) => setBusy(`${d} / ${t}`));
    } catch (e) {
      toast(`Could not create the file: ${(e as Error)?.message ?? e}`, "error");
    }
    setBusy(null);
  };

  const item = (kind: "excel" | "pdf" | "zip", icon: string, label: string, sub: string) => (
    <button
      onClick={() => run(kind)}
      className="flex w-full items-center gap-3 px-3.5 py-2.5 text-left text-sm hover:bg-white/5"
    >
      <Icon name={icon} size={19} color={kind === "excel" ? "#22C55E" : kind === "pdf" ? "#EF4444" : "#F59E0B"} />
      <span>
        <span className="block font-medium">{label}</span>
        <span className="block text-xs text-muted">{sub}</span>
      </span>
    </button>
  );

  return (
    <div ref={ref} className="relative">
      <Button
        variant="outline"
        small={small}
        icon="download"
        loading={!!busy}
        disabled={!!busy || !rows}
        onClick={() => setOpen((o) => !o)}
      >
        {busy && busy.includes("/") ? `Zipping ${busy}` : "Download"}
      </Button>
      {open && (
        <div className="animate-fade absolute right-0 top-full z-50 mt-2 w-64 overflow-hidden rounded-xl border border-line bg-field py-1.5 shadow-2xl">
          {item("excel", "table_view", "Excel (.xlsx)", qr ? "With QR pass images" : "Spreadsheet")}
          {item("pdf", "picture_as_pdf", "PDF", qr ? "Table with QR passes" : "Printable table")}
          {qr && item("zip", "folder_zip", "ZIP of QR passes", "Every pass as a PNG image")}
        </div>
      )}
    </div>
  );
}
