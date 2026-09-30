import { useEffect, useLayoutEffect, useRef, useState } from "react";
import { asset } from "@/lib/api";

export const CERT_IMG = asset("certificate_page-0001.jpg");
// Where the name goes on the certificate image, as fractions of its size.
export const NAME_BOX = { left: 0.39, top: 0.395, width: 0.48, height: 0.07 };

/** Name height as a share of the name box's height (the rest is breathing room). */
export const NAME_FILL = 0.72;

export type Box = typeof NAME_BOX;
export type Cert = { label: string; img: string; box: Box; fileName: string };

/** Both certificates share the same eligibility (all days scanned, or admin unlock). */
export const CERTIFICATES: Cert[] = [
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
