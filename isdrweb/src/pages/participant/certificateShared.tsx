import { useEffect, useLayoutEffect, useRef, useState } from "react";
import { asset } from "@/lib/api";

export type Box = { left: number; top: number; width: number; height: number };
export type Cert = { key: string; label: string; img: string; box: Box; fileName: string };

/** Name height as a share of the name box's height (the rest is breathing room). */
export const NAME_FILL = 0.72;

// Name sits on the blank line under "This is to Certify that", just above the underline.
const STUDENT_BOX: Box = { left: 0.26, top: 0.508, width: 0.48, height: 0.055 };
const DELEGATE_BOX: Box = { left: 0.252, top: 0.51, width: 0.49, height: 0.055 };

/** Artwork for the two certificates. The API decides which keys a participant receives. */
export const CERTIFICATE_ART: Record<string, Cert> = {
  student: {
    key: "student",
    label: "Student Conference Certificate",
    img: asset("student_conference_certificate.jpg"),
    box: STUDENT_BOX,
    fileName: "ISDR2026_Student_Conference_Certificate.pdf",
  },
  delegate: {
    key: "delegate",
    label: "Delegate Certificate",
    img: asset("delegate_certificate.jpg"),
    box: DELEGATE_BOX,
    fileName: "ISDR2026_Delegate_Certificate.pdf",
  },
};

/** Certificates for this participant, in API order. Missing list falls back to both. */
export function resolveCertificates(data: { certificates?: { key?: string; label?: string; fileName?: string }[] } | null): Cert[] {
  const list = data?.certificates;
  if (!Array.isArray(list)) return Object.values(CERTIFICATE_ART);
  return list.flatMap((c) => {
    const art = c?.key ? CERTIFICATE_ART[c.key] : undefined;
    if (!art) return [];
    return [{ ...art, label: c.label || art.label, fileName: c.fileName || art.fileName }];
  });
}

/** The certificate image with the name written in. */
export function CertificateImage({
  name,
  img,
  box: nameBox,
}: {
  name: string;
  img: string;
  box: Box;
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

  const fontSize = size.h * nameBox.height * NAME_FILL;
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
export async function downloadCertificatePdf(name: string, cert: Cert) {
  const { jsPDF } = await import("jspdf");
  const img = await new Promise<HTMLImageElement>((res, rej) => {
    const i = new Image();
    i.onload = () => res(i);
    i.onerror = rej;
    i.src = cert.img;
  });
  const w = 842;
  const h = (w * img.naturalHeight) / img.naturalWidth;
  const doc = new jsPDF({ orientation: w > h ? "landscape" : "portrait", unit: "pt", format: [w, h] });
  doc.addImage(img, /\.png$/i.test(cert.img) ? "PNG" : "JPEG", 0, 0, w, h);
  doc.setFont("helvetica", "bold");
  doc.setTextColor(0x1e, 0x3a, 0x8a);
  const box = cert.box;
  let size = Math.round(h * box.height * NAME_FILL);
  doc.setFontSize(size);
  const maxW = w * box.width;
  while (doc.getTextWidth(name) > maxW && size > 8) doc.setFontSize(--size);
  doc.text(name, w * (box.left + box.width / 2), h * (box.top + box.height / 2), {
    align: "center",
    baseline: "middle",
  });
  doc.save(cert.fileName);
}
