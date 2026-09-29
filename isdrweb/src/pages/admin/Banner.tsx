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
  useEffect(() => {
    load();
  }, [load]);

  const toggle = async (enabled: boolean) => {
    const r = await put("/home-banner", { enabled });
    if (r.success) {
      setBanner((b: any) => ({ ...b, enabled }));
      toast(enabled ? "Banner enabled" : "Banner disabled");
    } else toast(r.error || "Failed", "error");
  };

  const addImage = async (file: File) => {
    setUploading(true);
    const fd = new FormData();
    fd.append("image", file);
    const r = await post("/home-banner/images", fd);
    setUploading(false);
    if (r.success) {
      load();
      toast("Image added", "success");
    } else toast(r.error || "Upload failed", "error");
  };

  const removeImage = async (imgId: string) => {
    if (!(await confirm({ title: "Remove image?", confirm: "Remove", danger: true }))) return;
    const r = await del(`/home-banner/images/${imgId}`);
    if (r.success) {
      load();
      toast("Image removed");
    } else toast(r.error || "Failed", "error");
  };

  const images: any[] = banner?.images ?? [];
  const enabled = banner?.enabled !== false;

  return (
    <Page
      title="Home Banner"
      subtitle="Images shown in the home page carousel"
      actions={
        <Button icon="add_photo_alternate" onClick={() => fileRef.current?.click()} loading={uploading}>
          Add Image
        </Button>
      }
    >
      <input
        ref={fileRef}
        type="file"
        accept="image/*"
        hidden
        onChange={(e) => {
          const f = e.target.files?.[0];
          if (f) addImage(f);
          e.target.value = "";
        }}
      />
      {!banner ? (
        <Loading />
      ) : (
        <div className="space-y-5">
          <div className="card flex items-center justify-between gap-4 px-5 py-4">
            <div className="flex items-center gap-3">
              <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-[#EC4899]/15">
                <Icon name="view_carousel" size={19} color="#EC4899" />
              </span>
              <div>
                <div className="font-semibold">Banner Enabled</div>
                <div className="text-xs text-muted">Show banner carousel on participant home</div>
              </div>
            </div>
            <Switch checked={enabled} onChange={toggle} />
          </div>

          {images.length === 0 ? (
            <Empty icon="image" title="No images" subtitle="Add images to show in the home banner carousel." />
          ) : (
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {images.map((img: any, i: number) => (
                <div key={idOf(img)} className="card group relative overflow-hidden">
                  <img src={img.url} alt="" className="aspect-[16/7] w-full object-cover" />
                  <div className="flex items-center justify-between px-4 py-2.5">
                    <span className="text-xs font-semibold text-muted">Slide {i + 1}</span>
                    <Button
                      small
                      variant="ghost"
                      icon="delete"
                      className="!text-[#F87171]"
                      onClick={() => removeImage(idOf(img))}
                    >
                      Remove
                    </Button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </Page>
  );
}
