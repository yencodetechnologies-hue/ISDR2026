/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { AppBar, Icon, Spinner, useConfirm, useToast } from "@/components/ui";
import { AppSpinner } from "@/components/app/AppControls";
import { del, get, post } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { idOf, parseDate } from "@/lib/format";

const MON = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
function fmt(iso: any) {
  const d = parseDate(iso);
  if (!d) return "";
  const h = d.getHours();
  return `${d.getDate()} ${MON[d.getMonth()]}, ${h % 12 || 12}:${String(d.getMinutes()).padStart(2, "0")} ${h < 12 ? "AM" : "PM"}`;
}

/** A feed photo: spinner while loading, "tap to retry" if it fails. */
function FeedImage({ url }: { url: string }) {
  const [state, setState] = useState<"loading" | "ok" | "error">("loading");
  const [attempt, setAttempt] = useState(0);
  return (
    <div className="relative h-full w-full bg-field">
      {state !== "error" && (
        <img
          key={attempt}
          src={attempt ? `${url}${url.includes("?") ? "&" : "?"}r=${attempt}` : url}
          alt=""
          onLoad={() => setState("ok")}
          onError={() => setState("error")}
          className="h-full w-full object-cover"
        />
      )}
      {state === "loading" && (
        <div className="absolute inset-0 flex items-center justify-center">
          <Spinner size={26} color="#fff" />
        </div>
      )}
      {state === "error" && (
        <button
          onClick={() => {
            setState("loading");
            setAttempt((a) => a + 1);
          }}
          className="absolute inset-0 flex flex-col items-center justify-center gap-1.5 text-xs text-muted"
        >
          <Icon name="refresh" color="#9CA3AF" />
          Tap to retry
        </button>
      )}
    </div>
  );
}

/** Feed at phone width — the app's ParticipantFeedPage (admin: view + delete, no posting). */
export default function FeedApp() {
  const { user } = useAuth();
  const admin = user?.userType === "apartment";
  const navigate = useNavigate();
  const toast = useToast();
  const confirm = useConfirm();
  const [posts, setPosts] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [sharing, setSharing] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    const r = await get("/feed-posts");
    setLoading(false);
    setError(r.success ? null : r.error || "Could not load the feed");
    if (r.success) setPosts(r.posts ?? []);
  }, []);
  useEffect(() => {
    load();
  }, [load]);

  const like = async (p: any) => {
    const id = idOf(p);
    const was = p.liked === true;
    const count = Number(p.likeCount) || 0;
    setPosts((l) => l.map((x) => (idOf(x) === id ? { ...x, liked: !was, likeCount: count + (was ? -1 : 1) } : x)));
    const r = await post(`/feed-posts/${id}/like`);
    setPosts((l) =>
      l.map((x) =>
        idOf(x) === id
          ? r.success
            ? { ...x, liked: r.liked === true, likeCount: Number(r.likeCount) || 0 }
            : { ...x, liked: was, likeCount: count }
          : x,
      ),
    );
  };
  const share = async (p: any) => {
    const url = String(p.imageUrl ?? "");
    if (!url || sharing) return;
    setSharing(idOf(p));
    const name = String(p.participantName ?? "");
    const text = name ? `${name} at ISDR 2026` : "From the ISDR 2026 feed";
    try {
      const blob = await (await fetch(url)).blob();
      const file = new File([blob], `isdr_feed_${idOf(p)}.jpg`, { type: "image/jpeg" });
      if (navigator.canShare?.({ files: [file] })) await navigator.share({ files: [file], text });
      else {
        const a = document.createElement("a");
        a.href = URL.createObjectURL(blob);
        a.download = file.name;
        a.click();
        setTimeout(() => URL.revokeObjectURL(a.href), 2000);
      }
    } catch {
      toast("Could not share this photo");
    }
    setSharing(null);
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
    const r = await del(`/feed-posts/${idOf(p)}`);
    if (r.success) {
      setPosts((l) => l.filter((x) => idOf(x) !== idOf(p)));
      toast("Post deleted");
    } else toast(r.error || "Could not delete");
  };

  return (
    <div className="min-h-screen bg-bg">
      <AppBar title="Feed" outfit />
      {loading ? (
        <AppSpinner />
      ) : error && posts.length === 0 ? (
        <div className="flex flex-col items-center px-6 pt-[124px] text-center">
          <Icon name="cloud_off" size={40} color="#9CA3AF" />
          <div className="mt-2.5 text-[13px] text-muted">{error}</div>
          <button
            onClick={load}
            className="mt-3.5 inline-flex h-10 items-center gap-2 rounded-full border border-[#8E8E98] px-4 text-sm font-medium text-accent"
          >
            <Icon name="refresh" size={18} />
            Retry
          </button>
        </div>
      ) : posts.length === 0 ? (
        <div className="flex flex-col items-center pt-[124px] text-center">
          <Icon name="dynamic_feed" size={40} color="#9CA3AF" />
          <div className="mt-2.5 text-[13px] text-muted">No posts yet</div>
        </div>
      ) : (
        <div className="space-y-3 p-3">
          {posts.map((p) => {
            const liked = p.liked === true;
            const time = fmt(p.createdAt);
            return (
              <div key={idOf(p)} className="overflow-hidden rounded-[14px] border border-line bg-card">
                <div className="aspect-square">
                  {p.imageUrl ? <FeedImage url={p.imageUrl} /> : <div className="h-full w-full bg-field" />}
                </div>
                <div className="flex items-center py-1.5 pl-2.5 pr-1">
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-xs font-bold">{p.participantName}</div>
                    {time && <div className="text-[10px] text-muted">{time}</div>}
                  </div>
                  <button onClick={() => like(p)} className="flex items-center gap-1 rounded-full px-2 py-1.5">
                    <Icon name="favorite" outline={!liked} size={22} color={liked ? "#EF4444" : "#9CA3AF"} />
                    <span className="text-[13px] font-semibold" style={{ color: liked ? "#EF4444" : "#9CA3AF" }}>
                      {Number(p.likeCount) || 0}
                    </span>
                  </button>
                  <button
                    onClick={() => share(p)}
                    title="Share"
                    className="flex h-10 w-10 items-center justify-center rounded-full"
                  >
                    {sharing === idOf(p) ? (
                      <Spinner size={18} color="#fff" />
                    ) : (
                      <Icon name="share" size={21} color="#9CA3AF" />
                    )}
                  </button>
                  {(p.canDelete === true || p.mine === true) && (
                    <button
                      onClick={() => remove(p)}
                      title="Delete"
                      className="flex h-10 w-10 items-center justify-center rounded-full"
                    >
                      <Icon name="delete" outline size={21} color="#F87171" />
                    </button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}
      {!admin && (
        <button
          onClick={() => navigate("/feed/camera")}
          aria-label="Take a selfie"
          className="fixed bottom-4 right-4 z-30 flex h-[60px] w-[60px] items-center justify-center rounded-full bg-gradient-to-br from-[#8B5CF6] via-[#2563EB] to-[#E1306C] shadow-[0_6px_14px_rgba(139,92,246,0.45)]"
        >
          <Icon name="camera_enhance" size={26} />
          <span className="absolute right-2.5 top-2.5">
            <Icon name="auto_awesome" size={12} color="rgba(255,255,255,0.9)" />
          </span>
        </button>
      )}
    </div>
  );
}
