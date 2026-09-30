/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useRef, useState } from "react";
import { AppBar, Icon, Spinner, useConfirm, useToast } from "@/components/ui";
import { AppFab, AppSpinner, AppSwitch } from "@/components/app/AppControls";
import { AppTickerStrap } from "@/components/app/AppHome";
import { AppTextField } from "@/components/app/AppForm";
import { tickerTextFromLines } from "@/components/widgets";
import { del, formData, get, post, put } from "@/lib/api";
import { idOf } from "@/lib/format";

const Eyebrow = ({ children }: { children: React.ReactNode }) => (
  <div className="text-[11px] font-bold tracking-[0.6px] text-muted">{children}</div>
);

/** Filled 50px button that dims (35%) when disabled — the app's FilledButton. */
function FilledBtn({
  label,
  onClick,
  disabled,
  loading,
}: {
  label: string;
  onClick: () => void;
  disabled?: boolean;
  loading?: boolean;
}) {
  const off = disabled || loading;
  return (
    <button
      onClick={off ? undefined : onClick}
      className="flex h-[50px] w-full items-center justify-center rounded-[14px] text-[15px] font-bold"
      style={{ background: off && !loading ? "rgba(59,130,246,0.35)" : "#3B82F6" }}
    >
      {loading ? <Spinner size={20} color="#fff" /> : label}
    </button>
  );
}

/** SwitchListTile inside a dark card. */
function SwitchTile({
  title,
  subtitle,
  value,
  onChange,
  disabled,
}: {
  title: string;
  subtitle: string;
  value: boolean;
  onChange: (v: boolean) => void;
  disabled?: boolean;
}) {
  return (
    <label className="flex cursor-pointer items-center rounded-[14px] border border-line bg-card px-4 py-3">
      <div className="min-w-0 flex-1">
        <div className="text-[14.5px] font-semibold">{title}</div>
        <div className="text-xs text-muted">{subtitle}</div>
      </div>
      <AppSwitch checked={value} disabled={disabled} activeThumb="#fff" onChange={onChange} />
    </label>
  );
}

/* ------------------------------------------------------------------ */
/* YouTube Live / Live Photo — ManageYoutubeLivePage / ManageLivePhotoPage */
/* ------------------------------------------------------------------ */

export function LinkSettingApp({ kind }: { kind: "youtube" | "photo" }) {
  const toast = useToast();
  const yt = kind === "youtube";
  const path = yt ? "/youtube-live" : "/live-photo";
  const [loading, setLoading] = useState(true);
  const [saved, setSaved] = useState("");
  const [link, setLink] = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    get(path).then((r) => {
      setLoading(false);
      const url = String(r.url ?? r.live?.url ?? "");
      setSaved(url);
      setLink(url);
      if (!r.success) toast(r.error || "Could not load the link");
    });
  }, [path, toast]);

  const save = async (url: string) => {
    setSaving(true);
    const r = await put(path, { url });
    setSaving(false);
    if (r.success) {
      const u = String(r.url ?? "");
      setSaved(u);
      setLink(u);
      toast(
        yt
          ? u
            ? "YouTube live link saved"
            : "YouTube live removed"
          : u
            ? "Live photo link saved"
            : "Live photo link removed",
      );
    } else toast(r.error || "Could not save");
  };

  const changed = link.trim() !== saved;
  return (
    <div className="min-h-screen bg-bg">
      <AppBar title={yt ? "YouTube Live" : "Live Photo"} outfit />
      {loading ? (
        <AppSpinner />
      ) : (
        <div className="p-4">
          <div className="flex items-center rounded-[14px] border border-line bg-card p-3.5">
            <Icon
              name={yt ? "live_tv" : "photo_camera"}
              outline={!saved}
              size={yt ? 24 : 26}
              color={saved ? (yt ? "#FF0000" : "#E11D48") : "#9CA3AF"}
            />
            <div className="ml-3 min-w-0 flex-1">
              {yt ? (
                <div className="text-[13.5px] font-semibold">
                  {saved ? "Showing on the participant home" : "Not showing — no link set"}
                </div>
              ) : (
                <>
                  <div className="text-[13.5px] font-bold">
                    {saved ? "Active — Showing across all roles" : "Not showing — no link set"}
                  </div>
                  <div className="mt-0.5 text-[11.5px] text-muted">
                    Displays &quot;Get your live photo&quot; button below the button grid
                  </div>
                </>
              )}
            </div>
          </div>
          <div className="mt-5">
            <Eyebrow>{yt ? "YOUTUBE LINK" : "LIVE PHOTO LINK"}</Eyebrow>
          </div>
          <div className="mt-2">
            <AppTextField
              label={yt ? "Paste the YouTube link" : "Paste live photo gallery link (Google Photos, Drive, etc.)"}
              icon="link"
              type="url"
              value={link}
              onChange={setLink}
              fill="#1E1E2A"
              outer="#0A0A12"
              iconColor="#60A5FA"
              radius={14}
            />
          </div>
          <div className="mt-5">
            <FilledBtn
              label="Save Link"
              loading={saving}
              disabled={!changed || !link.trim()}
              onClick={() => save(link.trim())}
            />
          </div>
          {saved && (
            <button
              disabled={saving}
              onClick={() => save("")}
              className="mx-auto mt-2.5 flex h-10 items-center gap-2 rounded-full px-3 text-sm font-semibold text-[#F87171]"
            >
              <Icon name="delete" outline color="#F87171" />
              {yt ? "Remove YouTube Live" : "Remove Live Photo Link"}
            </button>
          )}
        </div>
      )}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Banner — ManageBannerPage                                           */
/* ------------------------------------------------------------------ */

export function BannerApp() {
  const toast = useToast();
  const confirm = useConfirm();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [enabled, setEnabled] = useState(true);
  const [images, setImages] = useState<any[]>([]);
  const [busy, setBusy] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  const apply = (r: any) => {
    if (!r.success || !r.banner) return false;
    setEnabled(r.banner.enabled !== false);
    setImages(r.banner.images ?? []);
    return true;
  };
  const load = useCallback(async () => {
    const r = await get("/home-banner");
    setLoading(false);
    setError(apply(r) ? null : r.error || "Could not load the banner");
  }, []);
  useEffect(() => {
    load();
  }, [load]);

  const toggle = async (v: boolean) => {
    const prev = enabled;
    setEnabled(v);
    setBusy(true);
    const r = await put("/home-banner", { enabled: v });
    setBusy(false);
    if (!apply(r)) {
      setEnabled(prev);
      toast(r.error || "Could not update");
    }
  };
  const add = async (file: File) => {
    setBusy(true);
    const r = await post("/home-banner/images", formData({}, { image: file }));
    setBusy(false);
    if (!apply(r)) toast(r.error || "Could not add image");
  };
  const remove = async (img: any) => {
    if (
      !(await confirm({
        title: "Delete image?",
        message: "It will be removed from the participant home banner.",
        confirm: "Delete",
        danger: true,
      }))
    )
      return;
    const r = await del(`/home-banner/images/${idOf(img)}`);
    if (!apply(r)) toast(r.error || "Could not delete");
  };

  return (
    <div className="min-h-screen bg-bg">
      <AppBar title="Banner" outfit />
      {loading ? (
        <AppSpinner />
      ) : (
        <div className="px-4 pb-24 pt-2">
          {error ? (
            <div className="whitespace-pre-line pt-[120px] text-center text-muted">{`${error}\nPull down to try again.`}</div>
          ) : (
            <>
              <SwitchTile
                title="Show banner"
                subtitle={enabled ? "On — scrolling on the participant home" : "Off — hidden from participants"}
                value={enabled}
                disabled={busy}
                onChange={toggle}
              />
              <div className="mt-[18px]">
                <Eyebrow>{images.length ? `IMAGES · ${images.length}` : "IMAGES"}</Eyebrow>
              </div>
              <div className="mt-2.5">
                {images.length === 0 ? (
                  <div className="flex flex-col items-center py-10 text-center">
                    <Icon name="photo_library" outline size={44} color="#9CA3AF" />
                    <div className="mt-2.5 whitespace-pre-line text-[13px] text-muted">
                      {'No images yet.\nTap "Add Image" to add one.'}
                    </div>
                  </div>
                ) : (
                  images.map((img, i) => (
                    <div
                      key={idOf(img)}
                      className="relative mb-3 overflow-hidden rounded-[14px] border border-line bg-card"
                    >
                      <img src={img.url} alt="" className="aspect-[16/7] w-full object-cover" />
                      <span className="absolute left-2 top-2 rounded-full bg-black/55 px-2 py-[3px] text-[11px] font-bold">
                        {i + 1}
                      </span>
                      <button
                        onClick={() => remove(img)}
                        title="Delete"
                        className="absolute right-1.5 top-1.5 flex h-12 w-12 items-center justify-center rounded-full bg-black/55"
                      >
                        <Icon name="delete" outline color="#F87171" />
                      </button>
                    </div>
                  ))
                )}
              </div>
            </>
          )}
        </div>
      )}
      {!loading && !error && (
        <>
          <AppFab
            icon={busy ? "progress_activity" : "add_photo_alternate"}
            label="Add Image"
            onClick={() => !busy && fileRef.current?.click()}
          />
          <input
            ref={fileRef}
            type="file"
            accept="image/*"
            hidden
            onChange={(e) => {
              const f = e.target.files?.[0];
              if (f) add(f);
              e.target.value = "";
            }}
          />
        </>
      )}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* News Ticker — ManageNewsTickerPage                                   */
/* ------------------------------------------------------------------ */

export function TickerApp() {
  const toast = useToast();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [enabled, setEnabled] = useState(true);
  const [saved, setSaved] = useState("");
  const [text, setText] = useState("");
  const [switching, setSwitching] = useState(false);
  const [saving, setSaving] = useState(false);
  const [focused, setFocused] = useState(false);

  const apply = (r: any, setTextToo = false) => {
    if (!r.success || !r.ticker) return false;
    setEnabled(r.ticker.enabled !== false);
    const t = String(r.ticker.text ?? "");
    setSaved(t);
    if (setTextToo) setText(t);
    return true;
  };
  useEffect(() => {
    get("/news-ticker").then((r) => {
      setLoading(false);
      setError(apply(r, true) ? null : r.error || "Could not load the news ticker");
    });
  }, []);

  const toggle = async (v: boolean) => {
    const prev = enabled;
    setEnabled(v);
    setSwitching(true);
    const r = await put("/news-ticker", { enabled: v });
    setSwitching(false);
    if (!apply(r)) {
      setEnabled(prev);
      toast(r.error || "Could not update");
    }
  };
  const save = async () => {
    if (!tickerTextFromLines(text)) return toast("Enter the ticker text");
    setSaving(true);
    const r = await put("/news-ticker", { text });
    setSaving(false);
    if (apply(r, true)) toast("News ticker updated");
    else toast(r.error || "Could not save");
  };

  const preview = tickerTextFromLines(text);
  const changed = text.trim() !== saved.trim();
  return (
    <div className="min-h-screen bg-bg">
      <AppBar title="News Ticker" outfit />
      {loading ? (
        <AppSpinner />
      ) : error ? (
        <div className="p-6 pt-40 text-center text-muted">{error}</div>
      ) : (
        <div className="p-4">
          <SwitchTile
            title="Show news ticker"
            subtitle={
              enabled ? "On — scrolling on the participant and event staff homes" : "Off — hidden from everyone"
            }
            value={enabled}
            disabled={switching}
            onChange={toggle}
          />
          <div className="mt-5">
            <Eyebrow>TICKER TEXT</Eyebrow>
          </div>
          <textarea
            value={text}
            maxLength={2000}
            rows={4}
            placeholder="One message per line"
            onFocus={() => setFocused(true)}
            onBlur={() => setFocused(false)}
            onChange={(e) => setText(e.target.value)}
            className="mt-2 block max-h-[260px] min-h-[112px] w-full resize-y rounded-[14px] bg-field px-3.5 py-4 text-sm outline-none placeholder:text-muted"
            style={{ boxShadow: `inset 0 0 0 1px ${focused ? "#3B82F6" : "rgba(255,255,255,0.08)"}` }}
          />
          <div className="mt-1 flex justify-between px-3 text-[11.5px] text-muted">
            <span>Each line is shown as a separate message, divided by •</span>
            <span className="ml-2 shrink-0">{text.length}/2000</span>
          </div>
          <div className="mt-4">
            <Eyebrow>PREVIEW</Eyebrow>
          </div>
          <div className="mt-2">
            {preview ? (
              <AppTickerStrap text={preview} />
            ) : (
              <div className="text-[12.5px] text-muted">Nothing to show yet</div>
            )}
          </div>
          <div className="mt-6">
            <FilledBtn label={changed ? "Save Text" : "Saved"} loading={saving} disabled={!changed} onClick={save} />
          </div>
        </div>
      )}
    </div>
  );
}
