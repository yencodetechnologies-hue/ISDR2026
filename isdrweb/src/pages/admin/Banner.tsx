/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useRef, useState } from "react";
import { Button, Empty, Icon, Loading, Page, Switch, useConfirm, useToast } from "@/components/ui";
import { del, get, post, put } from "@/lib/api";
import { idOf } from "@/lib/format";

export default function ManageBanner() {
  const toast = useToast();
  const confirm = useConfirm();
  const fileRef = useRef<HTMLInputElement>(null);
  const [banner, setBanner] = useState<any>(null);
  const [uploading, setUploading] = useState(false);

  const load = useCallback(async () => {
    const r = await get("/home-banner");
    if (r.success && r.banner) setBanner(r.banner);
  }, []);
  useEffect(() => { load(); }, [load]);

  const toggle = async (enabled: boolean) => {
    const r = await put("/home-banner", { enabled });
    if (r.success) { setBanner((b: any) => ({ ...b, enabled })); toast(enabled ? "Banner enabled" : "Banner disabled"); }
    else toast(r.error || "Failed", "error");
  };

  const addImage = async (file: File) => {
    setUploading(true);
    const fd = new FormData();
    fd.append("image", file);
    const r = await post("/home-banner/images", fd);
    setUploading(false);
    if (r.success) { load(); toast("Image added", "success"); }
    else toast(r.error || "Upload failed", "error");
  };

  const removeImage = async (imgId: string) => {
    if (!(await confirm({ title: "Remove image?", confirm: "Remove", danger: true }))) return;
    const r = await del(`/home-banner/images/${imgId}`);
    if (r.success) { load(); toast("Image removed"); }
    else toast(r.error || "Failed", "error");
  };

  const images: any[] = banner?.images ?? [];
  const enabled = banner?.enabled !== false;

  return (
    <Page title="Home Banner">
      {!banner ? <Loading /> : (
        <div className="space-y-4">
          <div className="card flex items-center justify-between p-4">
            <div>
              <div className="font-bold">Banner Enabled</div>
              <div className="text-xs text-muted">Show banner carousel on participant home</div>
            </div>
            <Switch checked={enabled} onChange={toggle} />
          </div>

          <Button icon="add_photo_alternate" variant="outline" onClick={() => fileRef.current?.click()} loading={uploading}>
            Add Image
          </Button>
          <input ref={fileRef} type="file" accept="image/*" hidden onChange={(e) => { const f = e.target.files?.[0]; if (f) addImage(f); e.target.value = ""; }} />

          {images.length === 0 ? (
            <Empty icon="image" title="No images" subtitle="Add images to show in the home banner carousel." />
          ) : (
            <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-3">
              {images.map((img: any) => (
                <div key={idOf(img)} className="group relative overflow-hidden rounded-xl border border-line">
                  <img src={img.url} alt="" className="h-28 w-full object-cover" />
                  <button
                    onClick={() => removeImage(idOf(img))}
                    className="absolute right-1.5 top-1.5 flex h-7 w-7 items-center justify-center rounded-full bg-black/60 opacity-0 transition group-hover:opacity-100"
                  >
                    <Icon name="close" size={16} />
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </Page>
  );
}
