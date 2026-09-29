/* eslint-disable @typescript-eslint/no-explicit-any, react-refresh/only-export-components */
import { useEffect, useRef, useState } from "react";
import { Button, Icon, Loading, Page, Spinner, useToast } from "@/components/ui";
import { asset, get } from "@/lib/api";
import { fmtDMon, parseDate } from "@/lib/format";

export const CERT_IMG = asset("certificate_page-0001.jpg");
// Where the name goes on the certificate image, as fractions of its size.
export const NAME_BOX = { left: 0.39, top: 0.395, width: 0.48, height: 0.07 };

/** The certificate image with the name written in. */
export function CertificateImage({ name }: { name: string }) {
  const box = useRef<HTMLDivElement>(null);
  const [w, setW] = useState(0);
  useEffect(() => {
    const el = box.current;
    if (!el) return;
    const ro = new ResizeObserver(() => setW(el.clientWidth));
    ro.observe(el);
    return () => ro.disconnect();
  }, []);
  // The app draws 22pt text on a phone-width image (~360px); scale with the width.
  const size = (22 * w) / 360;
  return (
    <div ref={box} className="relative">
      <img src={CERT_IMG} alt="Certificate" className="block w-full" />
      <div
        className="absolute flex items-center justify-center overflow-hidden"
        style={{
          left: `${NAME_BOX.left * 100}%`,
          top: `${NAME_BOX.top * 100}%`,
          width: `${NAME_BOX.width * 100}%`,
          height: `${NAME_BOX.height * 100}%`,
        }}
      >
        <span className="whitespace-nowrap font-extrabold text-[#1E3A8A]" style={{ fontSize: size }}>
          {name}
        </span>
      </div>
    </div>
  );
}

/** Builds the certificate PDF (842pt wide page, image + name) and saves it. */
export async function downloadCertificatePdf(name: string) {
  const { jsPDF } = await import("jspdf");
  const img = await new Promise<HTMLImageElement>((res, rej) => {
    const i = new Image();
    i.onload = () => res(i);
    i.onerror = rej;
    i.src = CERT_IMG;
  });
  const w = 842;
  const h = (w * img.naturalHeight) / img.naturalWidth;
  const doc = new jsPDF({ orientation: w > h ? "landscape" : "portrait", unit: "pt", format: [w, h] });
  doc.addImage(img, "JPEG", 0, 0, w, h);
  doc.setFont("helvetica", "bold");
  doc.setTextColor(0x1e, 0x3a, 0x8a);
  let size = 22;
  doc.setFontSize(size);
  const maxW = w * NAME_BOX.width;
  while (doc.getTextWidth(name) > maxW && size > 8) doc.setFontSize(--size);
  doc.text(name, w * (NAME_BOX.left + NAME_BOX.width / 2), h * (NAME_BOX.top + NAME_BOX.height / 2), {
    align: "center",
    baseline: "middle",
  });
  doc.save("ISDR2026_Certificate.pdf");
}

/** Participant: day-by-day entry/exit progress and the certificate (locked until done). */
export default function ParticipantCertificate() {
  const toast = useToast();
  const [data, setData] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const [downloading, setDownloading] = useState(false);

  useEffect(() => {
    get("/certificates/me").then((r) => {
      if (r.success) setData(r);
      else setError(r.error || "Could not load the certificate");
    });
  }, []);

  const days: any[] = data?.days ?? [];
  const unlocked = data?.unlocked === true;
  const name = String(data?.name ?? "");
  const done = (d: any) => d?.entryAt != null && d?.exitAt != null;

  const download = async () => {
    setDownloading(true);
    try {
      await downloadCertificatePdf(name);
    } catch (e) {
      toast(`Could not create the PDF: ${e}`, "error");
    }
    setDownloading(false);
  };

  const mark = (ok: boolean, label: string) => (
    <div className="flex items-center justify-center gap-1 text-[10px]" style={{ color: ok ? "#fff" : "#9CA3AF" }}>
      <Icon name={ok ? "check_circle" : "radio_button_unchecked"} size={11} color={ok ? "#22C55E" : "#9CA3AF"} />
      {label}
    </div>
  );

  return (
    <Page
      title="Certificate"
      subtitle={
        unlocked
          ? "Your certificate is ready to download"
          : "Get your entry and exit scanned on all event days to unlock your certificate."
      }
      back={false}
      width={960}
      actions={
        data &&
        unlocked && (
          <Button icon="download" loading={downloading} onClick={download}>
            Download PDF
          </Button>
        )
      }
    >
      {error ? (
        <div className="py-16 text-center text-muted">{error}</div>
      ) : !data ? (
        <Loading />
      ) : (
        <>
          <div className="card px-3 pb-5 pt-5">
            <div className="eyebrow mb-4 pl-3">Attendance</div>
            {days.length === 0 ? (
              <div className="pl-2 text-[12.5px] text-muted">Event dates are not set yet</div>
            ) : (
              <div className="flex items-start">
                {days.map((d, i) => {
                  const complete = done(d);
                  const partial = !complete && d.entryAt != null;
                  const color = complete ? "#22C55E" : partial ? "#F59E0B" : "rgba(255,255,255,0.08)";
                  const date = parseDate(d.date);
                  return (
                    <div key={i} className="flex-1">
                      <div className="flex items-center">
                        <div
                          className="h-[3px] flex-1"
                          style={{
                            background: i === 0 ? "transparent" : complete ? "#22C55E" : "rgba(255,255,255,0.08)",
                          }}
                        />
                        <div
                          className="flex h-[26px] w-[26px] items-center justify-center rounded-full border-2 text-[11px] font-bold"
                          style={{
                            borderColor: color,
                            background: complete || partial ? color : "transparent",
                            color: partial ? "#fff" : "#9CA3AF",
                          }}
                        >
                          {complete ? <Icon name="check" size={16} color="#fff" /> : i + 1}
                        </div>
                        <div
                          className="h-[3px] flex-1"
                          style={{
                            background:
                              i === days.length - 1
                                ? "transparent"
                                : done(days[i + 1])
                                  ? "#22C55E"
                                  : "rgba(255,255,255,0.08)",
                          }}
                        />
                      </div>
                      <div
                        className="mt-1.5 text-center text-[11px] font-semibold"
                        style={{ color: complete ? "#fff" : "#9CA3AF" }}
                      >
                        {date ? fmtDMon(date) : `Day ${i + 1}`}
                      </div>
                      <div className="mt-1 space-y-0.5">
                        {mark(d.entryAt != null, "In")}
                        {mark(d.exitAt != null, "Out")}
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
          <div className="relative mt-5 overflow-hidden rounded-xl border border-line shadow-2xl shadow-black/40">
            {unlocked ? (
              <>
                <CertificateImage name={name} />
                <button
                  title="Download PDF"
                  onClick={download}
                  disabled={downloading}
                  className="absolute bottom-2 right-2 flex h-8 w-8 items-center justify-center rounded-full bg-black/60"
                >
                  {downloading ? <Spinner size={16} color="#fff" /> : <Icon name="download" size={16} />}
                </button>
              </>
            ) : (
              <>
                <div style={{ filter: "blur(8px)" }}>
                  <CertificateImage name={name} />
                </div>
                <div className="absolute inset-0 flex items-center justify-center bg-black/35">
                  <span className="flex rounded-full bg-black/55 p-3.5">
                    <Icon name="lock" size={34} />
                  </span>
                </div>
              </>
            )}
          </div>
        </>
      )}
    </Page>
  );
}
