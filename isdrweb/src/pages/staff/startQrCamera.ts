/**
 * Start an html5-qrcode scanner on `elementId`.
 * Prefers a back / rear camera (the app's scanner), then any other camera
 * so a laptop webcam still works. The scan box is never larger than the
 * live viewfinder.
 */
export type QrCamera = {
  stop: () => Promise<void>;
  applyVideoConstraints: (constraints: MediaTrackConstraints) => Promise<void>;
};

const BACK = /back|rear|environment/i;

type Camera = { id: string; label: string };

function scanBox(viewfinderWidth: number, viewfinderHeight: number) {
  const edge = Math.floor(Math.min(viewfinderWidth, viewfinderHeight, 300));
  const size = Math.max(0, Math.min(edge, viewfinderWidth - 1, viewfinderHeight - 1));
  return { width: size, height: size };
}

function cameraOrder(cameras: Camera[]) {
  const back: Camera[] = [];
  const other: Camera[] = [];
  for (const camera of cameras) {
    if (camera.id && BACK.test(camera.label)) back.push(camera);
    else if (camera.id) other.push(camera);
  }
  return [...back, ...other];
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

export async function startQrCamera(
  elementId: string,
  onCode: (text: string) => void,
  isCancelled?: () => boolean,
): Promise<QrCamera | null> {
  const { Html5Qrcode } = await import("html5-qrcode");
  if (isCancelled?.()) return null;

  let cameras: Camera[] = [];
  try {
    cameras = await Html5Qrcode.getCameras();
  } catch {
    cameras = [];
  }
  if (isCancelled?.()) return null;

  const attempts: Array<string | MediaTrackConstraints> = cameraOrder(cameras).map((camera) => camera.id);
  if (!attempts.length) attempts.push({ facingMode: "environment" }, { facingMode: "user" });

  const config = { fps: 10, qrbox: scanBox };
  let lastError: unknown;
  for (const camera of attempts) {
    if (isCancelled?.()) return null;
    const scanner = new Html5Qrcode(elementId, /* verbose */ false);
    try {
      await scanner.start(
        camera,
        config,
        (text: string) => {
          if (text.trim()) onCode(text);
        },
        () => {},
      );
      if (isCancelled?.()) {
        await release(scanner);
        return null;
      }
      return {
        stop: () => release(scanner),
        applyVideoConstraints: (constraints) => scanner.applyVideoConstraints(constraints),
      };
    } catch (error) {
      lastError = error;
      await release(scanner);
    }
  }
  throw lastError ?? new Error("Camera not available");
}
