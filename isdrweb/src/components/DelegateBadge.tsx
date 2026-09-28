/* eslint-disable @typescript-eslint/no-explicit-any, react-refresh/only-export-components */
import { useEffect, useRef, useState } from "react";
import { QRCodeSVG } from "qrcode.react";
import { asset } from "@/lib/api";

// Template is 1200×1465; the framed badge inside it is 1080×1404 at (60, 25).
const TEMPLATE_W = 1200;
const TEMPLATE_H = 1465;
const CROP_LEFT = 60;
const CROP_TOP = 25;
const BADGE_W = 1080;
const BADGE_H = 1404;
const INK = "#0F172A";

export type BadgeData = {
  name?: string;
  title?: string;
  participantType?: string;
  idNumber?: string;
  designation?: string;
  institution?: string;
  qrCode?: string;
};

const v = (s: any) => String(s ?? "").trim();

/** One line of text shrunk to fit its width. */
function Fit({ text, size, weight, color, width }: { text: string; size: number; weight: number; color: string; width: number }) {
  const ref = useRef<HTMLSpanElement>(null);
  const [scale, setScale] = useState(1);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const w = el.scrollWidth;
    setScale(w > width ? width / w : 1);
  }, [text, size, width]);
  return (
    <div className="flex justify-center overflow-hidden" style={{ width }}>
      <span
        ref={ref}
        className="inline-block whitespace-pre"
        style={{ fontSize: size, fontWeight: weight, color, transform: `scale(${scale})`, lineHeight: 1.2 }}
      >
        {text}
      </span>
    </div>
  );
}

/** Participant badge on the delegate badge template: type, name, designation, institution, QR, spaced ID. */
export default function DelegateBadge({ data, innerRef }: { data: BadgeData; innerRef?: React.Ref<HTMLDivElement> }) {
  const box = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(0);
  useEffect(() => {
    const el = box.current;
    if (!el) return;
    const ro = new ResizeObserver(() => setScale(el.clientWidth / BADGE_W));
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  const displayName = [v(data.title), v(data.name)].filter(Boolean).join(" ");
  const typeLabel = (v(data.participantType) || "Delegate").toUpperCase();
  const idNumber = v(data.idNumber);
  const qr = v(data.qrCode);

  return (
    <div ref={box} className="relative w-full overflow-hidden rounded-xl" style={{ aspectRatio: `${BADGE_W} / ${BADGE_H}` }}>
      <div
        ref={innerRef}
        className="absolute left-0 top-0 origin-top-left"
        style={{ width: BADGE_W, height: BADGE_H, transform: `scale(${scale})`, visibility: scale ? "visible" : "hidden" }}
      >
        <div className="absolute" style={{ left: -CROP_LEFT, top: -CROP_TOP, width: TEMPLATE_W, height: TEMPLATE_H }}>
          <img src={asset("delegate_badge_template.png")} alt="" className="absolute inset-0 h-full w-full" />
          <div className="absolute flex items-center" style={{ left: 150, top: 422, width: 888, height: 100 }}>
            <Fit text={typeLabel} size={64} weight={800} color="#fff" width={888} />
          </div>
          <div className="absolute flex flex-col items-center" style={{ left: 150, top: 550, width: 888 }}>
            {displayName && (
              <div style={{ marginBottom: 16 }}>
                <Fit text={displayName} size={56} weight={800} color={INK} width={888} />
              </div>
            )}
            {v(data.designation) && (
              <div style={{ marginBottom: 12 }}>
                <Fit text={v(data.designation)} size={42} weight={700} color={INK} width={888} />
              </div>
            )}
            {v(data.institution) && (
              <div className="line-clamp-2 text-center" style={{ fontSize: 38, fontWeight: 700, color: INK, lineHeight: 1.25 }}>
                {v(data.institution)}
              </div>
            )}
          </div>
          {qr && (
            <div className="absolute bg-white p-1" style={{ left: 440, top: 830, width: 320, height: 320 }}>
              <QRCodeSVG value={qr} size={312} bgColor="#FFFFFF" fgColor="#000000" level="L" />
            </div>
          )}
          {idNumber && (
            <div
              className="absolute text-center"
              style={{
                left: 0,
                top: 1160,
                width: TEMPLATE_W,
                fontSize: 52,
                fontWeight: 800,
                color: INK,
                fontFamily: "ui-monospace, Consolas, monospace",
              }}
            >
              {idNumber.split("").join(" ")}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function loadImage(src: string) {
  return new Promise<HTMLImageElement>((resolve, reject) => {
    const img = new Image();
    img.crossOrigin = "anonymous";
    img.onload = () => resolve(img);
    img.onerror = reject;
    img.src = src;
  });
}

/**
 * Saves the badge as a PNG: the template and text are redrawn on a canvas
 * with the badge layout; the QR comes from the rendered badge's SVG.
 */
export async function downloadBadgePng(container: HTMLElement | null, data: BadgeData) {
  const OX = -CROP_LEFT;
  const OY = -CROP_TOP;
  const canvas = document.createElement("canvas");
  canvas.width = BADGE_W;
  canvas.height = BADGE_H;
  const ctx = canvas.getContext("2d");
  if (!ctx) return false;
  const family = getComputedStyle(document.body).fontFamily || "sans-serif";
  ctx.drawImage(await loadImage(asset("delegate_badge_template.png")), OX, OY, TEMPLATE_W, TEMPLATE_H);

  const fit = (text: string, size: number, weight: number, color: string, cx: number, cy: number, maxW: number, mono = false) => {
    ctx.font = `${weight} ${size}px ${mono ? "ui-monospace, Consolas, monospace" : family}`;
    ctx.fillStyle = color;
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    const w = ctx.measureText(text).width;
    const s = w > maxW ? maxW / w : 1;
    ctx.save();
    ctx.translate(cx, cy);
    ctx.scale(s, s);
    ctx.fillText(text, 0, 0);
    ctx.restore();
  };

  const name = [v(data.title), v(data.name)].filter(Boolean).join(" ");
  fit((v(data.participantType) || "Delegate").toUpperCase(), 64, 800, "#fff", OX + 594, OY + 472, 888);
  let y = OY + 550;
  if (name) {
    fit(name, 56, 800, INK, OX + 594, y + 56 * 0.6, 888);
    y += 56 * 1.2 + 16;
  }
  if (v(data.designation)) {
    fit(v(data.designation), 42, 700, INK, OX + 594, y + 42 * 0.6, 888);
    y += 42 * 1.2 + 12;
  }
  if (v(data.institution)) {
    ctx.font = `700 38px ${family}`;
    ctx.fillStyle = INK;
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    const lines: string[] = [];
    let cur = "";
    for (const w of v(data.institution).split(/\s+/)) {
      const t = cur ? `${cur} ${w}` : w;
      if (ctx.measureText(t).width > 888 && cur) {
        lines.push(cur);
        cur = w;
      } else cur = t;
    }
    if (cur) lines.push(cur);
    lines.slice(0, 2).forEach((l, i) => ctx.fillText(i === 1 && lines.length > 2 ? `${l}…` : l, OX + 594, y + 38 * 1.25 * (i + 0.5), 888));
  }
  const svg = container?.querySelector("svg");
  if (svg && v(data.qrCode)) {
    ctx.fillStyle = "#fff";
    ctx.fillRect(OX + 440, OY + 830, 320, 320);
    const url = URL.createObjectURL(new Blob([new XMLSerializer().serializeToString(svg)], { type: "image/svg+xml" }));
    try {
      ctx.drawImage(await loadImage(url), OX + 444, OY + 834, 312, 312);
    } finally {
      URL.revokeObjectURL(url);
    }
  }
  if (v(data.idNumber)) fit(v(data.idNumber).split("").join(" "), 52, 800, INK, OX + 600, OY + 1191, TEMPLATE_W, true);

  const blob = await new Promise<Blob | null>((res) => canvas.toBlob(res, "image/png"));
  if (!blob) return false;
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = `badge_${v(data.idNumber) || "qr"}.png`;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  return true;
}
