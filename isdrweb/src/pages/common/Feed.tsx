/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  Avatar,
  Button,
  Empty,
  ErrorState,
  IconButton,
  Loading,
  Page,
  Spinner,
  useConfirm,
  useToast,
} from "@/components/ui";
import { asset, del, get, post } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { fmtShortDateTime, idOf, parseDate } from "@/lib/format";

/** Feed of event selfies: like, share, delete own (admin: delete any, no camera button). */
export function Feed() {
  const { user } = useAuth();
  const adminMode = user?.userType === "apartment";
  const navigate = useNavigate();
  const toast = useToast();
  const confirm = useConfirm();
  const [posts, setPosts] = useState<any[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [sharing, setSharing] = useState<string | null>(null);

  const load = useCallback(async () => {
    const res = await get("/feed-posts");
    if (!res.success) return setError(res.error || "Could not load feed");
    setError(null);
    setPosts(res.posts ?? []);
  }, []);
  useEffect(() => {
    load();
  }, [load]);

  const like = async (p: any) => {
    const id = idOf(p);
    const was = p.liked === true;
    const count = Number(p.likeCount) || 0;
    const patch = (x: any) => setPosts((l) => (l ?? []).map((q) => (idOf(q) === id ? { ...q, ...x } : q)));
    patch({ liked: !was, likeCount: count + (was ? -1 : 1) });
    const res = await post(`/feed-posts/${id}/like`);
    if (res.success) patch({ liked: res.liked === true, likeCount: Number(res.likeCount) || 0 });
    else patch({ liked: was, likeCount: count });
  };

  const remove = async (p: any) => {
    if (
      !(await confirm({
        title: "Delete post?",
        message: "This photo will be removed from the feed.",
        confirm: "Delete",
        danger: true,
      }))
    )
      return;
    const res = await del(`/feed-posts/${idOf(p)}`);
    if (res.success) {
      setPosts((l) => (l ?? []).filter((q) => idOf(q) !== idOf(p)));
      toast("Post deleted", "success");
    } else toast(res.error || "Could not delete", "error");
  };

  const share = async (p: any) => {
    const url = String(p.imageUrl ?? "");
    if (!url) return;
    setSharing(idOf(p));
    try {
      const blob = await (await fetch(url)).blob();
      const file = new File([blob], "isdr2026.png", { type: blob.type || "image/png" });
      const text = `ISDR 2026${p.participantName ? ` — ${p.participantName}` : ""}`;
      if (navigator.canShare?.({ files: [file] })) await navigator.share({ files: [file], text });
      else {
        const a = document.createElement("a");
        a.href = URL.createObjectURL(blob);
        a.download = "isdr2026.png";
        a.click();
        setTimeout(() => URL.revokeObjectURL(a.href), 1000);
      }
    } catch (e) {
      if ((e as Error)?.name !== "AbortError") toast("Could not share this photo", "error");
    }
    setSharing(null);
  };

  return (
    <Page
      title="Feed"
      subtitle="Selfies from the conference"
      back={false}
      actions={
        !adminMode && (
          <Button
            icon="photo_camera"
            onClick={() => navigate("/feed/camera")}
            className="!bg-gradient-to-r from-pink-500 to-orange-400"
          >
            Take a Selfie
          </Button>
        )
      }
    >
      {error ? (
        <ErrorState message={error} onRetry={load} />
      ) : !posts ? (
        <Loading />
      ) : posts.length === 0 ? (
        <Empty
          icon="photo_camera"
          title="No posts yet"
          subtitle={adminMode ? undefined : "Click Take a Selfie to share the first one."}
        />
      ) : (
        <div className="grid gap-5 sm:grid-cols-2 xl:grid-cols-3">
          {posts.map((p) => (
            <div key={idOf(p)} className="card overflow-hidden">
              <div className="flex items-center gap-2.5 px-4 py-3">
                <Avatar src={p.participantPhoto} name={p.participantName} size={34} />
                <div className="min-w-0 flex-1">
                  <div className="truncate text-sm font-semibold">{p.participantName || "Participant"}</div>
                  <div className="text-[11px] text-muted">{fmtShortDateTime(parseDate(p.createdAt))}</div>
                </div>
              </div>
              {p.imageUrl && (
                <img src={p.imageUrl} alt="" loading="lazy" className="aspect-square w-full bg-field object-cover" />
              )}
              <div className="flex items-center gap-1 px-2 py-1.5">
                <IconButton
                  icon="favorite"
                  outline={!p.liked}
                  color={p.liked ? "#EF4444" : "#fff"}
                  title="Like"
                  onClick={() => like(p)}
                />
                <span className="text-sm font-semibold">{Number(p.likeCount) || 0}</span>
                <span className="flex-1" />
                {sharing === idOf(p) ? (
                  <span className="flex h-10 w-10 items-center justify-center">
                    <Spinner size={18} />
                  </span>
                ) : (
                  <IconButton icon="share" title="Share" onClick={() => share(p)} />
                )}
                {(p.canDelete === true || p.mine === true) && (
                  <IconButton icon="delete" outline color="#EF4444" title="Delete" onClick={() => remove(p)} />
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </Page>
  );
}

/** Front-camera selfie with the event banner overlaid; Retake / Post. */
export function SelfieCamera() {
  const navigate = useNavigate();
  const toast = useToast();
  const video = useRef<HTMLVideoElement>(null);
  const [error, setError] = useState<string | null>(null);
  const [shot, setShot] = useState<Blob | null>(null);
  const [shotUrl, setShotUrl] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    let stream: MediaStream | null = null;
    navigator.mediaDevices
      ?.getUserMedia({ video: { facingMode: "user", width: { ideal: 1280 }, height: { ideal: 1280 } }, audio: false })
      .then((s) => {
        stream = s;
        if (video.current) video.current.srcObject = s;
      })
      .catch(() => setError("Camera not available. Allow camera access to take a selfie."));
    if (!navigator.mediaDevices) setError("Camera not available on this device.");
    return () => stream?.getTracks().forEach((t) => t.stop());
  }, []);

  useEffect(() => {
    if (!shot) {
      setShotUrl(null);
      return;
    }
    const u = URL.createObjectURL(shot);
    setShotUrl(u);
    return () => URL.revokeObjectURL(u);
  }, [shot]);

  const capture = async () => {
    const v = video.current;
    if (!v || !v.videoWidth) return;
    setBusy(true);
    const size = Math.min(v.videoWidth, v.videoHeight);
    const out = 1080;
    const canvas = document.createElement("canvas");
    canvas.width = out;
    canvas.height = out;
    const ctx = canvas.getContext("2d")!;
    // Mirror like the preview, crop to a centred square.
    ctx.translate(out, 0);
    ctx.scale(-1, 1);
    ctx.drawImage(v, (v.videoWidth - size) / 2, (v.videoHeight - size) / 2, size, size, 0, 0, out, out);
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    try {
      const banner = await new Promise<HTMLImageElement>((res, rej) => {
        const img = new Image();
        img.onload = () => res(img);
        img.onerror = rej;
        img.src = asset("Camera_banner_gemini.png");
      });
      const h = (banner.height / banner.width) * out;
      ctx.drawImage(banner, 0, out - h, out, h);
    } catch {
      /* banner missing */
    }
    canvas.toBlob((b) => {
      setShot(b);
      setBusy(false);
    }, "image/png");
  };

  const postIt = async () => {
    if (!shot) return;
    setBusy(true);
    const fd = new FormData();
    fd.append("photo", shot, "selfie.png");
    const res = await post("/feed-posts", fd);
    setBusy(false);
    if (res.success) navigate(-1);
    else toast(res.error || "Failed to post", "error");
  };

  return (
    <div className="fixed inset-0 flex flex-col bg-black">
      <div className="flex items-center gap-2 p-3">
        <IconButton icon="close" title="Close" onClick={() => navigate(-1)} />
        <span className="font-semibold">Take a Selfie</span>
      </div>
      <div className="flex flex-1 items-center justify-center p-2">
        <div className="relative aspect-square w-full max-w-[min(90vw,70vh)] overflow-hidden rounded-xl bg-[#111]">
          {error ? (
            <div className="flex h-full items-center justify-center p-6 text-center text-sm text-white/70">{error}</div>
          ) : shotUrl ? (
            <img src={shotUrl} alt="" className="h-full w-full object-cover" />
          ) : (
            <>
              <video ref={video} autoPlay playsInline muted className="h-full w-full -scale-x-100 object-cover" />
              <img src={asset("Camera_banner_gemini.png")} alt="" className="absolute inset-x-0 bottom-0 w-full" />
            </>
          )}
        </div>
      </div>
      <div className="flex items-center justify-center gap-4 p-6">
        {shot ? (
          <>
            <Button variant="outline" icon="refresh" disabled={busy} onClick={() => setShot(null)}>
              Retake
            </Button>
            <Button icon="send" loading={busy} onClick={postIt}>
              Post
            </Button>
          </>
        ) : (
          <button
            disabled={!!error || busy}
            onClick={capture}
            className="h-18 w-18 rounded-full border-4 border-white bg-white/20 disabled:opacity-40"
            style={{ width: 72, height: 72 }}
            title="Capture"
          />
        )}
      </div>
    </div>
  );
}
