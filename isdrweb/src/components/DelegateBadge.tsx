/* eslint-disable @typescript-eslint/no-explicit-any, react-refresh/only-export-components */
import { useEffect, useRef, useState } from "react";
import { QRCodeSVG } from "qrcode.react";
import { asset } from "@/lib/api";

// Template "ID CARD 4_page-0001.jpg" (591×768) is the whole 100×130 mm card, drawn at 1080×1404.
const TEMPLATE = "ID CARD 4_page-0001.jpg";
const TEMPLATE_W = 1080;
const TEMPLATE_H = 1404;
const CROP_LEFT = 0;
const CROP_TOP = 0;
const BADGE_W = 1080;
const BADGE_H = 1404;
const INK = "#0F172A";
// Name and the institution line (ISDR26-####) on every pass.
const NAME_INK = "#2E3192";
// Content sits between the conference header and the "Hosted by" logo.
const TEXT = { left: 110, top: 562, width: 860 };
const CX = TEXT.left + TEXT.width / 2;
const QR_BOX = { left: 400, top: 740, size: 280 };
// Banner behind the participant type, coloured per participant; spans the white panel edge to edge.
export const DEFAULT_TYPE_COLOR = "#167E5D";
const BANNER = { left: 61, top: 440, width: 949, height: 96 };

/** '#RRGGBB' / 'RRGGBB' → '#RRGGBB'; null when it isn't a valid 6-digit hex. */
export function normalizeHex(hex: string | undefined | null): string | null {
  const h = String(hex ?? "")
    .trim()
    .replace(/^#/, "");
  return /^[0-9a-fA-F]{6}$/.test(h) ? `#${h.toUpperCase()}` : null;
}

export type BadgeData = {
  name?: string;
  title?: string;
  participantType?: string;
  participantTypeColor?: string;
  idNumber?: string;
  designation?: string;
  institution?: string;
  qrCode?: string;
};

const v = (s: any) => String(s ?? "").trim();

// Speakers' passes read "INVITED SPEAKER" on #9E0A0F.
const SPEAKER_COLOR = "#9E0A0F";
function typeOf(data: BadgeData) {
  const t = v(data.participantType) || "Delegate";
  const speaker = /^(invited\s+)?speaker$/i.test(t);
  return {
    label: (speaker ? "Invited Speaker" : t).toUpperCase(),
    color: normalizeHex(data.participantTypeColor) ?? (speaker ? SPEAKER_COLOR : DEFAULT_TYPE_COLOR),
  };
}

/** One line of text shrunk to fit its width. */
function Fit({
  text,
  size,
  weight,
  color,
  width,
}: {
  text: string;
  size: number;
  weight: number;
  color: string;
  width: number;
}) {
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

/** Participant badge on the QR pass template: type, name, designation, institution, QR (no ID code). */
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
  const { label: typeLabel, color: typeColor } = typeOf(data);
  const qr = v(data.qrCode);

  return (
    <div
      ref={box}
      className="relative w-full overflow-hidden rounded-xl"
      style={{ aspectRatio: `${BADGE_W} / ${BADGE_H}` }}
    >
      <div
        ref={innerRef}
        className="absolute left-0 top-0 origin-top-left"
        style={{
          width: BADGE_W,
          height: BADGE_H,
          transform: `scale(${scale})`,
          visibility: scale ? "visible" : "hidden",
        }}
      >
        <div className="absolute" style={{ left: -CROP_LEFT, top: -CROP_TOP, width: TEMPLATE_W, height: TEMPLATE_H }}>
          <img src={asset(TEMPLATE)} alt="" className="absolute inset-0 h-full w-full" />
          <div className="absolute" style={{ ...BANNER, background: typeColor }} />
          <div className="absolute flex items-center" style={{ left: BANNER.left + 30, top: BANNER.top, width: BANNER.width - 60, height: BANNER.height }}>
            <Fit text={typeLabel} size={60} weight={800} color="#fff" width={BANNER.width - 60} />
          </div>
          <div className="absolute flex flex-col items-center" style={TEXT}>
            {displayName && (
              <div style={{ marginBottom: 16 }}>
                <Fit text={displayName} size={56} weight={800} color={NAME_INK} width={TEXT.width} />
              </div>
            )}
            {v(data.designation) && (
              <div style={{ marginBottom: 12 }}>
                <Fit text={v(data.designation)} size={42} weight={700} color={INK} width={TEXT.width} />
              </div>
            )}
            {v(data.institution) && (
              <div
                className="line-clamp-2 text-center"
                style={{ fontSize: 38, fontWeight: 700, color: NAME_INK, lineHeight: 1.25 }}
              >
                {v(data.institution)}
              </div>
            )}
          </div>
          {qr && (
            <div className="absolute bg-white p-1" style={{ left: QR_BOX.left, top: QR_BOX.top, width: QR_BOX.size, height: QR_BOX.size }}>
              <QRCodeSVG value={qr} size={QR_BOX.size - 8} bgColor="#FFFFFF" fgColor="#000000" level="L" />
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

/** The badge template, loaded once (the ZIP export draws many badges). */
let templateImage: Promise<HTMLImageElement> | null = null;

/**
 * Draws the badge as a PNG: the template and text are redrawn on a canvas with
 * the badge layout. The QR comes from the rendered badge's SVG when [container]
 * is given, otherwise it is generated from data.qrCode.
 */
export async function renderBadgeBlob(data: BadgeData, container: HTMLElement | null = null) {
  const OX = -CROP_LEFT;
  const OY = -CROP_TOP;
  const canvas = document.createElement("canvas");
  canvas.width = BADGE_W;
  canvas.height = BADGE_H;
  const ctx = canvas.getContext("2d");
  if (!ctx) return null;
  const family = getComputedStyle(document.body).fontFamily || "sans-serif";
  templateImage ??= loadImage(asset(TEMPLATE)).catch((e) => {
    templateImage = null; // try again next time
    throw e;
  });
  ctx.drawImage(await templateImage, OX, OY, TEMPLATE_W, TEMPLATE_H);

  const fit = (
    text: string,
    size: number,
    weight: number,
    color: string,
    cx: number,
    cy: number,
    maxW: number,
  ) => {
    ctx.font = `${weight} ${size}px ${family}`;
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
  const type = typeOf(data);
  ctx.fillStyle = type.color;
  ctx.fillRect(OX + BANNER.left, OY + BANNER.top, BANNER.width, BANNER.height);
  fit(type.label, 60, 800, "#fff", OX + CX, OY + BANNER.top + BANNER.height / 2, BANNER.width - 60);
  let y = OY + TEXT.top;
  if (name) {
    fit(name, 56, 800, NAME_INK, OX + CX, y + 56 * 0.6, TEXT.width);
    y += 56 * 1.2 + 16;
  }
  if (v(data.designation)) {
    fit(v(data.designation), 42, 700, INK, OX + CX, y + 42 * 0.6, TEXT.width);
    y += 42 * 1.2 + 12;
  }
  if (v(data.institution)) {
    ctx.font = `700 38px ${family}`;
    ctx.fillStyle = NAME_INK;
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    const lines: string[] = [];
    let cur = "";
    for (const w of v(data.institution).split(/\s+/)) {
      const t = cur ? `${cur} ${w}` : w;
      if (ctx.measureText(t).width > TEXT.width && cur) {
        lines.push(cur);
        cur = w;
      } else cur = t;
    }
    if (cur) lines.push(cur);
    lines
      .slice(0, 2)
      .forEach((l, i) =>
        ctx.fillText(i === 1 && lines.length > 2 ? `${l}…` : l, OX + CX, y + 38 * 1.25 * (i + 0.5), TEXT.width),
      );
  }
  const svg = container?.querySelector("svg");
  if (v(data.qrCode)) {
    ctx.fillStyle = "#fff";
    ctx.fillRect(OX + QR_BOX.left, OY + QR_BOX.top, QR_BOX.size, QR_BOX.size);
    if (svg) {
      const url = URL.createObjectURL(
        new Blob([new XMLSerializer().serializeToString(svg)], { type: "image/svg+xml" }),
      );
      try {
        ctx.drawImage(await loadImage(url), OX + QR_BOX.left + 4, OY + QR_BOX.top + 4, QR_BOX.size - 8, QR_BOX.size - 8);
      } finally {
        URL.revokeObjectURL(url);
      }
    } else {
      const QR = await import("qrcode");
      const url = await QR.toDataURL(v(data.qrCode), { margin: 0, width: 624 });
      ctx.drawImage(await loadImage(url), OX + QR_BOX.left + 4, OY + QR_BOX.top + 4, QR_BOX.size - 8, QR_BOX.size - 8);
    }
  }

  return new Promise<Blob | null>((res) => canvas.toBlob(res, "image/png"));
}

/** Saves the badge as a PNG (QR taken from the rendered badge in [container]). */
export async function downloadBadgePng(container: HTMLElement | null, data: BadgeData) {
  const blob = await renderBadgeBlob(data, container);
  if (!blob) return false;
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = `badge_${v(data.idNumber) || "qr"}.png`;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  return true;
}
