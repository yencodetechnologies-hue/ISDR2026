/**
 * Start an html5-qrcode scanner on `elementId`.
 * Prefers the main wide back camera. Ultra-wide and telephoto lenses on
 * iPhone make a badge QR too small to decode quickly. Safari has no native
 * barcode detector, so the scan is QR-only, unmirrored, and at 720p.
 * The scan box is never larger than the live viewfinder.
 */
export type QrCamera = {
  stop: () => Promise<void>;
  applyVideoConstraints: (constraints: MediaTrackConstraints) => Promise<void>;
};

const BACK = /back|rear|environment/i;
const NOT_WIDE = /ultra|telephoto|depth/i;

type Camera = { id: string; label: string };
type Html5QrcodeModule = typeof import("html5-qrcode");

function scanBox(viewfinderWidth: number, viewfinderHeight: number) {
  const edge = Math.floor(Math.min(viewfinderWidth, viewfinderHeight, 300));
  const size = Math.max(0, Math.min(edge, viewfinderWidth - 1, viewfinderHeight - 1));
  return { width: size, height: size };
}

/** iPhone, iPod, and iPadOS (which reports a desktop Macintosh user agent). */
function isIos() {
  const ua = navigator.userAgent || "";
  if (/iPhone|iPad|iPod/i.test(ua)) return true;
  return navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1;
}

function cameraRank(camera: Camera) {
  const label = camera.label || "";
  const back = BACK.test(label);
  if (back && !NOT_WIDE.test(label)) return 0;
  if (!label) return 1;
  if (back) return 2;
  return 3;
}

function cameraOrder(cameras: Camera[]) {
  return cameras.filter((camera) => camera.id).sort((a, b) => cameraRank(a) - cameraRank(b));
}

async function release(scanner: { stop: () => Promise<void>; clear: () => void }) {
  try {
    await scanner.stop();
  } catch {
    /* start failed before the camera was running */
  }
  try {
    scanner.clear();
  } catch {
    /* element already empty */
  }
}

async function lockContinuousFocus(elementId: string) {
  const video = document.getElementById(elementId)?.querySelector("video");
  const stream = video?.srcObject;
  if (!(stream instanceof MediaStream)) return;
  const track = stream.getVideoTracks()[0];
  if (!track) return;
  try {
    await track.applyConstraints({
      advanced: [{ focusMode: "continuous" } as MediaTrackConstraintSet],
    });
  } catch {
    /* focus mode not supported */
  }
}

/**
 * html5-qrcode uses `videoConstraints` alone when it is set, and drops the
 * camera id / facingMode passed to `start`. The selected camera has to be
 * inside these constraints or iPhone opens whichever lens is first.
 */
function videoConstraintsFor(camera: string | MediaTrackConstraints, focus: boolean): MediaTrackConstraints {
  const selected: MediaTrackConstraints = typeof camera === "string" ? { deviceId: { exact: camera } } : camera;
  const constraints: MediaTrackConstraints = {
    ...selected,
    width: { ideal: 1280 },
    height: { ideal: 720 },
  };
  if (focus) constraints.advanced = [{ focusMode: "continuous" } as MediaTrackConstraintSet];
  return constraints;
}

async function listedCameras(Html5Qrcode: Html5QrcodeModule["Html5Qrcode"]) {
  try {
    return cameraOrder(await Html5Qrcode.getCameras()).map((camera) => camera.id);
  } catch {
    return [] as string[];
  }
}

export async function startQrCamera(
  elementId: string,
  onCode: (text: string) => void,
  isCancelled?: () => boolean,
): Promise<QrCamera | null> {
  const { Html5Qrcode, Html5QrcodeSupportedFormats } = await import("html5-qrcode");
  if (isCancelled?.()) return null;

  // On iPhone, facingMode opens the main wide camera and avoids the extra
  // permission stream that getCameras() starts before the real scan.
  const attempts: Array<string | MediaTrackConstraints> = isIos()
    ? [{ facingMode: "environment" }]
    : await listedCameras(Html5Qrcode);
  if (isCancelled?.()) return null;
  if (!attempts.length) attempts.push({ facingMode: "environment" }, { facingMode: "user" });

  const scannerConfig = {
    verbose: false,
    formatsToSupport: [Html5QrcodeSupportedFormats.QR_CODE],
    experimentalFeatures: { useBarCodeDetectorIfSupported: true },
  };

  let lastError: unknown;
  const tryStart = async (camera: string | MediaTrackConstraints) => {
    if (isCancelled?.()) return null;
    const scanner = new Html5Qrcode(elementId, scannerConfig);
    const onDecode = (text: string) => {
      if (text.trim()) onCode(text);
    };
    try {
      try {
        await scanner.start(camera, {
          fps: 15,
          qrbox: scanBox,
          disableFlip: true,
          videoConstraints: videoConstraintsFor(camera, true),
        }, onDecode, () => {});
      } catch (error) {
        // A device that rejects continuous focus should still open.
        if (isCancelled?.()) throw error;
        await scanner.start(camera, {
          fps: 15,
          qrbox: scanBox,
          disableFlip: true,
          videoConstraints: videoConstraintsFor(camera, false),
        }, onDecode, () => {});
      }
      if (isCancelled?.()) {
        await release(scanner);
        return null;
      }
      await lockContinuousFocus(elementId);
      return {
        stop: () => release(scanner),
        applyVideoConstraints: (constraints: MediaTrackConstraints) => scanner.applyVideoConstraints(constraints),
      };
    } catch (error) {
      lastError = error;
      await release(scanner);
      return undefined;
    }
  };

  for (const camera of attempts) {
    const started = await tryStart(camera);
    if (started !== undefined) return started;
  }

  if (isIos()) {
    for (const camera of await listedCameras(Html5Qrcode)) {
      const started = await tryStart(camera);
      if (started !== undefined) return started;
    }
  }

  throw lastError ?? new Error("Camera not available");
}
