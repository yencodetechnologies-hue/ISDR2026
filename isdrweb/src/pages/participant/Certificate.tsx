/* eslint-disable @typescript-eslint/no-explicit-any, react-refresh/only-export-components */
import { useEffect, useLayoutEffect, useRef, useState } from "react";
import { Button, Icon, Loading, Page, Spinner, useToast } from "@/components/ui";
import { asset, get } from "@/lib/api";
import { fmtDMon, parseDate } from "@/lib/format";

export const CERT_IMG = asset("certificate_page-0001.jpg");
// Where the name goes on the certificate image, as fractions of its size.
export const NAME_BOX = { left: 0.39, top: 0.395, width: 0.48, height: 0.07 };

/** Name height as a share of the name box's height (the rest is breathing room). */
const NAME_FILL = 0.72;

type Box = typeof NAME_BOX;
type Cert = { label: string; img: string; box: Box; fileName: string };

/** Both certificates share the same eligibility (all days scanned, or admin unlock). */
const CERTIFICATES: Cert[] = [
  { label: "Certificate of Attendance", img: CERT_IMG, box: NAME_BOX, fileName: "ISDR2026_Certificate.pdf" },
  // Name on the blank line under "This is to Certify that".
  {
    label: "CE / CME Certificate",
    img: asset("ce,cme.png"),
    box: { left: 0.43, top: 0.41, width: 0.435, height: 0.06 },
    fileName: "ISDR2026_CE_CME_Certificate.pdf",
  },
];

/** The certificate image with the name written in. */
export function CertificateImage({
  name,
  img = CERT_IMG,
  box: nameBox = NAME_BOX,
}: {
  name: string;
  img?: string;
  box?: Box;
}) {
  const box = useRef<HTMLDivElement>(null);
  const text = useRef<HTMLSpanElement>(null);
  const [size, setSize] = useState({ w: 0, h: 0 });
  const [shrink, setShrink] = useState(1);
  useEffect(() => {
    const el = box.current;
    if (!el) return;
    const ro = new ResizeObserver(() => setSize({ w: el.clientWidth, h: el.clientHeight }));
    ro.observe(el);
    return () => ro.disconnect();
  }, []);
  // The name fills most of the name box's height (so it never overflows it) ...
  const fontSize = size.h * nameBox.height * NAME_FILL;
  // ... and long names are shrunk to fit the box's width.
  useLayoutEffect(() => {
    const t = text.current;
    const boxW = size.w * nameBox.width;
    if (!t || !boxW) return;
    const natural = t.scrollWidth;
    setShrink(natural > boxW ? boxW / natural : 1);
  }, [name, fontSize, size.w, nameBox.width]);
  return (
    <div ref={box} className="relative">
      <img src={img} alt="Certificate" className="block w-full" />
      <div
        className="absolute flex items-center justify-center overflow-hidden"
        style={{
          left: `${nameBox.left * 100}%`,
          top: `${nameBox.top * 100}%`,
          width: `${nameBox.width * 100}%`,
          height: `${nameBox.height * 100}%`,
        }}
      >
        <span
          ref={text}
          className="whitespace-nowrap font-extrabold leading-none text-[#1E3A8A]"
          style={{ fontSize, transform: `scale(${shrink})` }}
        >
          {name}
        </span>
      </div>
    </div>
  );
}

/** Builds the certificate PDF (842pt wide page, image + name) and saves it. */
export async function downloadCertificatePdf(
  name: string,
  { img: src = CERT_IMG, box = NAME_BOX, fileName = "ISDR2026_Certificate.pdf" }: Partial<Cert> = {},
) {
  const { jsPDF } = await import("jspdf");
  const img = await new Promise<HTMLImageElement>((res, rej) => {
    const i = new Image();
    i.onload = () => res(i);
    i.onerror = rej;
    i.src = src;
  });
  const w = 842;
  const h = (w * img.naturalHeight) / img.naturalWidth;
  const doc = new jsPDF({ orientation: w > h ? "landscape" : "portrait", unit: "pt", format: [w, h] });
  doc.addImage(img, /\.png$/i.test(src) ? "PNG" : "JPEG", 0, 0, w, h);
  doc.setFont("helvetica", "bold");
  doc.setTextColor(0x1e, 0x3a, 0x8a);
  // Same sizing as on screen: most of the name box's height, shrunk to its width.
  let size = Math.round(h * box.height * NAME_FILL);
  doc.setFontSize(size);
  const maxW = w * box.width;
  while (doc.getTextWidth(name) > maxW && size > 8) doc.setFontSize(--size);
  doc.text(name, w * (box.left + box.width / 2), h * (box.top + box.height / 2), {
    align: "center",
    baseline: "middle",
  });
  doc.save(fileName);
}

/** Participant: day-by-day entry/exit progress and the certificate (locked until done). */
export default function ParticipantCertificate() {
  const toast = useToast();
  const [data, setData] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  // fileName of the certificate whose PDF is being built, if any.
  const [downloading, setDownloading] = useState<string | null>(null);

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

  const download = async (cert: Cert) => {
    setDownloading(cert.fileName);
    try {
      await downloadCertificatePdf(name, cert);
    } catch (e) {
      toast(`Could not create the PDF: ${e}`, "error");
    }
    setDownloading(null);
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
          ? "Your certificates are ready to download"
          : "Get your entry and exit scanned on all event days to unlock your certificates."
      }
      back={false}
      width={960}
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
          {CERTIFICATES.map((cert) => (
            <div key={cert.fileName} className="mt-6">
              <div className="mb-2 flex items-center gap-3">
                <div className="eyebrow flex-1 pl-1">{cert.label}</div>
                {unlocked && (
                  <Button
                    small
                    variant="outline"
                    icon="download"
                    loading={downloading === cert.fileName}
                    disabled={!!downloading}
                    onClick={() => download(cert)}
                  >
                    Download PDF
                  </Button>
                )}
              </div>
              <div className="relative overflow-hidden rounded-xl border border-line shadow-2xl shadow-black/40">
                {unlocked ? (
                  <>
                    <CertificateImage name={name} img={cert.img} box={cert.box} />
                    <button
                      title="Download PDF"
                      onClick={() => download(cert)}
                      disabled={!!downloading}
                      className="absolute bottom-2 right-2 flex h-8 w-8 items-center justify-center rounded-full bg-black/60"
                    >
                      {downloading === cert.fileName ? (
                        <Spinner size={16} color="#fff" />
                      ) : (
                        <Icon name="download" size={16} />
                      )}
                    </button>
                  </>
                ) : (
                  <>
                    <div style={{ filter: "blur(8px)" }}>
                      <CertificateImage name={name} img={cert.img} box={cert.box} />
                    </div>
                    <div className="absolute inset-0 flex items-center justify-center bg-black/35">
                      <span className="flex rounded-full bg-black/55 p-3.5">
                        <Icon name="lock" size={34} />
                      </span>
                    </div>
                  </>
                )}
              </div>
            </div>
          ))}
        </>
      )}
    </Page>
  );
}
