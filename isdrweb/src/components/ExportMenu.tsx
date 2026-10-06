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
  loadRows,
  columns,
  qr,
  small,
}: {
  title: string;
  rows?: T[] | null | undefined;
  /** Fetches the rows when a format is chosen, so the list page does not download them up front. */
  loadRows?: () => Promise<T[]>;
  columns: ExportColumn<T>[];
  qr?: QrConfig<T>;
  small?: boolean;
}) {
  const toast = useToast();
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState<string | null>(null);
  const [pos, setPos] = useState<{ left: number; top?: number; bottom?: number } | null>(null);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const close = (e: MouseEvent) => {
      if (!ref.current?.contains(e.target as Node)) setOpen(false);
    };
    // The menu is fixed to the screen, so close it rather than let it drift on scroll / resize.
    const shut = () => setOpen(false);
    document.addEventListener("mousedown", close);
    window.addEventListener("scroll", shut, true);
    window.addEventListener("resize", shut);
    return () => {
      document.removeEventListener("mousedown", close);
      window.removeEventListener("scroll", shut, true);
      window.removeEventListener("resize", shut);
    };
  }, [open]);

  // Opens below the button (above when there's no room), aligned to its right edge unless that would
  // run off the left of the screen — fixed positioning so cards with overflow-hidden can't clip it.
  const toggle = () => {
    if (open) return setOpen(false);
    const r = ref.current?.getBoundingClientRect();
    if (r) {
      const width = 256;
      const menuHeight = qr ? 200 : 140;
      const left = Math.max(8, Math.min(r.right - width >= 8 ? r.right - width : r.left, window.innerWidth - width - 8));
      setPos(
        window.innerHeight - r.bottom < menuHeight + 16 && r.top > menuHeight + 16
          ? { left, bottom: window.innerHeight - r.top + 8 }
          : { left, top: r.bottom + 8 },
      );
    }
    setOpen(true);
  };

  const run = async (kind: "excel" | "pdf" | "zip") => {
    setOpen(false);
    setBusy(kind);
    let list = rows ?? [];
    try {
      if (loadRows) list = (await loadRows()) ?? [];
      if (!list.length) {
        setBusy(null);
        return toast("Nothing to download", "error");
      }
      if (kind === "zip") setBusy(`0 / ${list.length}`);
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
        disabled={!!busy || (!loadRows && !rows)}
        onClick={toggle}
      >
        {busy && busy.includes("/") ? `Zipping ${busy}` : "Download"}
      </Button>
      {open && pos && (
        <div
          className="animate-fade fixed z-[100] w-64 overflow-hidden rounded-xl border border-line bg-field py-1.5 shadow-2xl"
          style={pos}
        >
          {item("excel", "table_view", "Excel (.xlsx)", qr ? "With QR pass images" : "Spreadsheet")}
          {item("pdf", "picture_as_pdf", "PDF", qr ? "100 × 130 mm ID card, one per page" : "Printable table")}
          {qr && item("zip", "folder_zip", "ZIP of QR passes", "100 × 130 mm PNG, 300 dpi")}
        </div>
      )}
    </div>
  );
}
