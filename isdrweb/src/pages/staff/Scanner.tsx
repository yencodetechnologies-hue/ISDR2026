/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useRef, useState } from "react";
import { Button, Icon, Input, Modal, Spinner } from "@/components/ui";
import type { ApiResult } from "@/lib/api";
import { fmtDate } from "@/lib/format";
import { startQrCamera } from "./startQrCamera";

const AUTO_NEXT_SECONDS = 3;

/**
 * Scan a participant QR (camera) or type their ID number, then show
 * ACCESS GRANTED / ALREADY CLAIMED / ACCESS DENIED. Reopens the scanner for
 * the next participant after 3 s — same as the app's ClaimInclusionScannerPage.
 */
export function ScannerModal({
  heading,
  name,
  itemLabel,
  successText,
  event,
  submit,
  onSuccess,
  onClose,
}: {
  heading: string;
  name: string;
  itemLabel: string;
  successText: string;
  event: any;
  submit: (code: { qrData?: string; idNumber?: string }) => Promise<ApiResult>;
  onSuccess?: () => void;
  onClose: () => void;
}) {
  const [mode, setMode] = useState<"qr" | "id">("qr");
  const [code, setCode] = useState("");
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState<ApiResult | null>(null);
  const [left, setLeft] = useState(0);
  const [camError, setCamError] = useState<string | null>(null);
  const scanner = useRef<any>(null);
  const handled = useRef(false);
  const regionId = "qr-region";

  const run = useCallback(
    async (c: { qrData?: string; idNumber?: string }) => {
      if (handled.current) return;
      handled.current = true;
      setBusy(true);
      const res = await submit(c);
      setBusy(false);
      setResult(res);
      if (res.success) onSuccess?.();
      setLeft(AUTO_NEXT_SECONDS);
    },
    [submit, onSuccess],
  );

  // Camera scanner while in QR mode and no result is showing.
  useEffect(() => {
    if (mode !== "qr" || result) return;
    let cancelled = false;
    handled.current = false;
    setCamError(null);
    (async () => {
      try {
        const cam = await startQrCamera(regionId, (text) => run({ qrData: text }), () => cancelled);
        if (!cam || cancelled) {
          await cam?.stop();
          return;
        }
        scanner.current = cam;
      } catch {
        if (!cancelled) setCamError("Camera not available. Allow camera access, or switch to Manual Code.");
      }
    })();
    return () => {
      cancelled = true;
      const cam = scanner.current;
      scanner.current = null;
      cam?.stop();
    };
  }, [mode, result, run]);

  // Auto-next countdown after a result.
  useEffect(() => {
    if (!result) return;
    if (left <= 0) {
      setResult(null);
      setCode("");
      setMode("qr");
      return;
    }
    const t = setTimeout(() => setLeft((s) => s - 1), 1000);
    return () => clearTimeout(t);
  }, [result, left]);

  const reset = () => {
    setLeft(0);
    setResult(null);
    setCode("");
    setMode("qr");
  };

  const success = result?.success === true;
  const reg: any = result?.registration && typeof result.registration === "object" ? result.registration : null;
  const used = !!result && !success && result.alreadyClaimed === true && !!reg;
  const denied = !!result && !success && !used;
  const r = reg ?? {};
  const pkg = (event?.packages ?? []).find(
    (p: any) => String(p.id) === String(r.packageId) || p.name === r.packageName,
  );
  const rate = Number(pkg?.rate) || 0;
  const packageText = r.packageName
    ? pkg
      ? `${r.packageName} — ${rate === 0 ? "Free" : `₹${rate}`}`
      : r.packageName
    : "";
  const tone = denied ? "#FCA5A5" : used ? "#FCD34D" : "#86EFAC";
  const bg = denied ? "rgba(239,68,68,0.15)" : used ? "rgba(245,158,11,0.15)" : "rgba(34,197,94,0.15)";
  const line = (label: string, value: string) =>
    value ? (
      <div className="flex gap-3 py-0.5 text-sm">
        <span className="w-28 shrink-0 font-semibold text-muted">{label}</span>
        <span className="font-bold">{value}</span>
      </div>
    ) : null;

  return (
    <Modal
      open
      onClose={onClose}
      title={
        <span>
          {heading} · {name}
        </span>
      }
      width={520}
    >
      {result ? (
        <div>
          <div className="rounded-2xl border-2 p-5" style={{ borderColor: tone, background: bg }}>
            <div className="flex items-center gap-2.5 text-lg font-black" style={{ color: tone }}>
              <Icon name={denied ? "cancel" : used ? "schedule" : "check_circle"} size={28} />
              {denied ? "ACCESS DENIED" : used ? "ALREADY CLAIMED" : "ACCESS GRANTED"}
            </div>
            <div className="my-3 border-t border-white/10" />
            {r.name && (
              <div className="mb-2 text-xl font-black" style={{ color: tone }}>
                {String(r.name).toUpperCase()}
              </div>
            )}
            {line("ID Number", String(r.idNumber ?? (reg ? "Spot" : "")))}
            {line("Type", reg && !/^spot register$/i.test(String(r.packageName || "")) ? String(r.participantType || "") : "")}
            {line("Package", packageText)}
            {line("Date", fmtDate(new Date()))}
            {line("Venue", String(event?.venue ?? ""))}
            {line(itemLabel, name)}
            <div className="mt-3 rounded-lg bg-black/20 px-3 py-2.5 text-sm font-semibold" style={{ color: tone }}>
              {denied
                ? String(result.error || result.message || "") || "This participant is not eligible for this benefit."
                : used
                  ? "This entitlement has already been redeemed."
                  : successText}
            </div>
          </div>
          <Button full icon="qr_code_scanner" className="mt-4 py-3" onClick={reset}>
            {left > 0 ? `Scan Next Participant (${left})` : "Scan Next Participant"}
          </Button>
          <button type="button" onClick={onClose} className="mx-auto mt-2.5 block h-10 rounded-full px-4 text-sm text-white/70">
            Done &amp; Go Back
          </button>
        </div>
      ) : (
        <div>
          <div className="mb-4 grid grid-cols-2 gap-1 rounded-lg bg-field p-1">
            {(["qr", "id"] as const).map((m) => (
              <button
                key={m}
                onClick={() => setMode(m)}
                className={`flex items-center justify-center gap-1.5 rounded-md py-2 text-sm font-semibold ${mode === m ? "bg-accent text-white" : "text-muted hover:text-white"}`}
              >
                <Icon name={m === "qr" ? "qr_code_scanner" : "keyboard"} size={18} />
                {m === "qr" ? "Scan QR" : "Manual Code"}
              </button>
            ))}
          </div>
          {mode === "qr" ? (
            <div>
              <div className="relative mx-auto aspect-square w-full max-w-[360px] overflow-hidden rounded-xl bg-black">
                <div id={regionId} className="h-full w-full" />
                {busy && (
                  <div className="absolute inset-0 flex items-center justify-center bg-black/60">
                    <Spinner />
                  </div>
                )}
                {camError && (
                  <div className="absolute inset-0 flex items-center justify-center p-6 text-center text-sm text-white/75">
                    {camError}
                  </div>
                )}
              </div>
              <div className="mt-3 text-center text-sm text-muted">Align QR code inside frame to claim</div>
            </div>
          ) : (
            <form
              onSubmit={(e) => {
                e.preventDefault();
                if (code.trim()) {
                  handled.current = false;
                  run({ idNumber: code.trim() });
                }
              }}
            >
              <div className="label">ENTER ID NUMBER</div>
              <Input
                autoFocus
                value={code}
                maxLength={25}
                onChange={(e) => setCode(e.target.value.toUpperCase())}
                placeholder="e.g. 1001"
                className="text-center font-mono tracking-[3px]"
              />
              <Button type="submit" full loading={busy} disabled={!code.trim()} className="mt-4 py-3">
                {busy ? "Verifying..." : `Verify & Claim ${name}`}
              </Button>
            </form>
          )}
        </div>
      )}
    </Modal>
  );
}
