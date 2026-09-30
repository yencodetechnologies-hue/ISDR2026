import { useEffect, useRef, useState } from "react";
import { AppBar, Icon, Page, Spinner } from "@/components/ui";
import { useAppLayout } from "@/lib/appLayout";
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
  const app = useAppLayout();

  // Phone width: the app's BrochurePage — counter chip in the app bar, shimmer until every page is ready.
  if (app)
    return (
      <div className="min-h-screen bg-[#0F172A]">
        <AppBar
          title="Brochure"
          titleClassName="text-[18px] font-bold"
          actions={
            <span className="mr-3 rounded-xl bg-black/25 px-2.5 py-1 text-[13px] font-bold">
              {!done ? (total > 0 ? `${pages.length} / ${total}` : "Loading…") : `${current} / ${pages.length}`}
            </span>
          }
        />
        {error ? (
          <div className="whitespace-pre-line px-6 pt-24 text-center text-white/70">{`Could not open the brochure.
${error}`}</div>
        ) : !done ? (
          <BrochureShimmer rendered={pages.length} total={total} />
        ) : (
          <div ref={list} className="space-y-3.5 px-3 py-4">
            {pages.map((src, i) => (
              <img key={i} data-page={i + 1} src={src} alt={`Page ${i + 1}`} className="w-full rounded-lg" />
            ))}
          </div>
        )}
      </div>
    );

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

/** The app's loading screen: progress card + three shimmering page placeholders. */
function BrochureShimmer({ rendered, total }: { rendered: number; total: number }) {
  const progress = total > 0 ? Math.min(rendered / total, 1) : 0;
  return (
    <div>
      {total > 0 && (
        <div className="mx-4 mt-3 rounded-xl border border-white/10 bg-[#1E293B] px-4 py-3">
          <div className="flex items-center justify-between text-[13px]">
            <span className="font-semibold">Rendering brochure…</span>
            <span className="font-bold text-[#10B981]">
              {rendered} of {total} pages
            </span>
          </div>
          <div className="mt-2.5 h-1.5 overflow-hidden rounded-md bg-white/10">
            <div className="h-full bg-[#10B981] transition-all" style={{ width: `${progress * 100}%` }} />
          </div>
        </div>
      )}
      <div className="space-y-3.5 px-3.5 py-4">
        {[0, 1, 2].map((i) => (
          <div
            key={i}
            className="brochure-shimmer flex aspect-[1/1.414] flex-col items-center justify-center rounded-lg shadow-[0_4px_8px_rgba(0,0,0,0.26)]"
          >
            <Icon name="picture_as_pdf" size={40} color="rgba(255,255,255,0.38)" />
            <div className="mt-3 text-[13px] font-semibold text-white/70">Optimizing &amp; caching high-res pages…</div>
          </div>
        ))}
      </div>
    </div>
  );
}
