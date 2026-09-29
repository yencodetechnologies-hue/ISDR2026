import { useEffect, useRef, useState } from "react";
import { Icon, Page, Spinner } from "@/components/ui";
import { asset } from "@/lib/api";

const PDF = asset("ISDR 36th international conference brochure_compressed.pdf");

/** The conference brochure PDF, rendered page by page (scroll; pinch/ctrl-scroll to zoom). */
export default function Brochure() {
  const [pages, setPages] = useState<string[]>([]);
  const [total, setTotal] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [current, setCurrent] = useState(1);
  const list = useRef<HTMLDivElement>(null);

  useEffect(() => {
    let cancelled = false;
    let destroy: (() => void) | null = null;
    (async () => {
      try {
        const pdfjs = await import("pdfjs-dist");
        pdfjs.GlobalWorkerOptions.workerSrc = "/pdf.worker.min.mjs";
        const task = pdfjs.getDocument({ url: PDF });
        destroy = () => task.destroy();
        const doc = await task.promise;
        if (cancelled) return;
        setTotal(doc.numPages);
        for (let i = 1; i <= doc.numPages; i++) {
          const page = await doc.getPage(i);
          const viewport = page.getViewport({ scale: 1.75 });
          const canvas = document.createElement("canvas");
          canvas.width = viewport.width;
          canvas.height = viewport.height;
          await page.render({ canvas, viewport }).promise;
          if (cancelled) return;
          const url = canvas.toDataURL("image/jpeg", 0.85);
          setPages((p) => [...p, url]);
        }
      } catch (e) {
        if (!cancelled) setError(String((e as Error)?.message ?? e));
      }
    })();
    return () => {
      cancelled = true;
      destroy?.();
    };
  }, []);

  useEffect(() => {
    const el = list.current;
    if (!el) return;
    const io = new IntersectionObserver(
      (entries) => {
        for (const e of entries) if (e.isIntersecting) setCurrent(Number((e.target as HTMLElement).dataset.page));
      },
      { threshold: 0.5 },
    );
    el.querySelectorAll("[data-page]").forEach((n) => io.observe(n));
    return () => io.disconnect();
  }, [pages.length]);

  const done = total > 0 && pages.length === total;

  return (
    <Page
      title="Brochure"
      subtitle="36th ISDR International Conference brochure"
      back={false}
      width={960}
      actions={
        <span className="flex items-center gap-2 rounded-lg border border-line bg-white/[0.03] px-3 py-2 text-sm font-semibold text-white/80">
          <Icon name="description" size={17} outline />
          {done ? `Page ${current} of ${pages.length}` : total ? `Loading ${pages.length} / ${total}` : "Loading…"}
        </span>
      }
    >
      {error ? (
        <div className="py-16 text-center whitespace-pre-line text-muted">{`Could not open the brochure.\n${error}`}</div>
      ) : (
        <div ref={list} className="space-y-5">
          {pages.map((src, i) => (
            <img
              key={i}
              data-page={i + 1}
              src={src}
              alt={`Page ${i + 1}`}
              className="w-full rounded-lg bg-white shadow-2xl shadow-black/40"
            />
          ))}
          {!done && (
            <div className="flex flex-col items-center gap-2 py-10 text-sm text-muted">
              <Spinner />
              Rendering brochure…
            </div>
          )}
        </div>
      )}
    </Page>
  );
}
