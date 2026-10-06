/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import { AppBar, Icon, Spinner, useConfirm, useToast } from "@/components/ui";
import { AppFab, AppSpinner } from "@/components/app/AppControls";
import { AppTextField } from "@/components/app/AppForm";
import { del, formData, get, post } from "@/lib/api";
import { groupExhibitors, stallCode } from "@/lib/exhibitors";
import { idOf } from "@/lib/format";

const dark = {
  fill: "#1E1E2A",
  outer: "#0A0A12",
  border: "rgba(255,255,255,0.08)",
  focus: "#3B82F6",
  iconColor: "#60A5FA",
  radius: 14,
};

/** Exhibitors at phone width — the app's ManageExhibitorsPage. */
export function ExhibitorsListApp() {
  const navigate = useNavigate();
  const toast = useToast();
  const confirm = useConfirm();
  const [items, setItems] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    const r = await get("/exhibitors");
    setLoading(false);
    if (r.success) {
      setError(null);
      setItems(r.exhibitors ?? []);
    } else setError(r.error || "Could not load exhibitors");
  }, []);
  useEffect(() => {
    load();
  }, [load]);

  const remove = async (e: any) => {
    if (
      !(await confirm({
        title: "Delete exhibitor?",
        message: `${e.shopName ?? e.name ?? ""} will be removed from the participant home.`,
        confirm: "Delete",
        danger: true,
      }))
    )
      return;
    const r = await del(`/exhibitors/${idOf(e)}`);
    if (r.success) setItems((l) => l.filter((x) => idOf(x) !== idOf(e)));
    else toast(r.error || "Could not delete");
  };

  return (
    <div className="min-h-screen bg-bg">
      <AppBar title="Exhibitors" outfit />
      <div className="px-4 pb-24 pt-2">
        {loading ? (
          <AppSpinner />
        ) : error || items.length === 0 ? (
          <div className="flex flex-col items-center pt-[120px] text-center">
            <Icon name="storefront" size={44} color="#9CA3AF" />
            <div className="mt-3 font-outfit text-[17px] font-bold">{error ?? "No exhibitors yet"}</div>
            <div className="mt-1 text-[12.5px] text-muted">
              {error ? "Pull down to try again." : "Added exhibitors show on the participant home."}
            </div>
          </div>
        ) : (
          groupExhibitors(items).map((group) => (
            <div key={group.title} className="mb-4">
              <div className="mb-2 flex items-center gap-2">
                <div className="font-outfit text-[13px] font-bold uppercase tracking-wide text-muted">{group.title}</div>
                <span className="text-[11px] text-muted">{group.items.length}</span>
              </div>
              {group.items.map((e) => {
                const photo = String(e.photo ?? e.photoUrl ?? "");
                return (
                  <div
                    key={idOf(e)}
                    className="mb-2.5 flex items-center rounded-[14px] border border-line bg-card py-2.5 pl-3 pr-1"
                  >
                    <span className="flex h-[52px] w-[52px] shrink-0 items-center justify-center overflow-hidden rounded-xl bg-field">
                      {photo ? (
                        <img src={photo} alt="" className="h-full w-full object-cover" />
                      ) : (
                        <Icon name="storefront" color="#60A5FA" />
                      )}
                    </span>
                    <div className="ml-3 min-w-0 flex-1">
                      <div className="font-outfit text-[15px] font-bold">{e.shopName ?? e.name ?? ""}</div>
                      <div className="mt-0.5 text-xs text-[#60A5FA]">{e.category ?? ""}</div>
                      <div className="mt-0.5 flex items-center gap-[3px] text-xs text-muted">
                        <Icon name="location_on" outline size={13} color="#9CA3AF" />
                        <span className="truncate">{stallCode(e.location ?? e.stallNumber)}</span>
                      </div>
                    </div>
                    <button
                      title="Delete"
                      onClick={() => remove(e)}
                      className="flex h-12 w-12 items-center justify-center rounded-full active:bg-white/10"
                    >
                      <Icon name="delete" outline color="#F87171" />
                    </button>
                  </div>
                );
              })}
            </div>
          ))
        )}
      </div>
      <AppFab icon="add_business" label="Add Exhibitor" onClick={() => navigate("/admin/exhibitors/new")} />
    </div>
  );
}

/** Add Exhibitor — the app's AddExhibitorPage (photo, shop name, category, location). */
export function ExhibitorFormApp() {
  const navigate = useNavigate();
  const toast = useToast();
  const [shopName, setShopName] = useState("");
  const [category, setCategory] = useState("");
  const [location, setLocation] = useState("");
  const [photo, setPhoto] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [saving, setSaving] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!photo) return setPreview(null);
    const u = URL.createObjectURL(photo);
    setPreview(u);
    return () => URL.revokeObjectURL(u);
  }, [photo]);

  const save = async () => {
    const e: Record<string, string> = {};
    if (!shopName.trim()) e.shopName = "Enter the shop name";
    if (!category.trim()) e.category = "Enter the category";
    if (!location.trim()) e.location = "Enter the stall, e.g. A1";
    setErrors(e);
    if (Object.keys(e).length) return;
    setSaving(true);
    const r = await post(
      "/exhibitors",
      formData({ shopName: shopName.trim(), category: category.trim(), location: location.trim() }, { photo }),
    );
    setSaving(false);
    if (r.success) navigate(-1);
    else toast(r.error || "Could not add exhibitor");
  };

  return (
    <div className="min-h-screen bg-bg">
      <AppBar title="Add Exhibitor" outfit />
      <div className="p-4">
        <div className="flex justify-center">
          <button onClick={() => fileRef.current?.click()} className="relative">
            <span className="flex h-[110px] w-[110px] items-center justify-center overflow-hidden rounded-[18px] bg-field">
              {preview ? (
                <img src={preview} alt="" className="h-full w-full object-cover" />
              ) : (
                <Icon name="storefront" size={44} color="#60A5FA" />
              )}
            </span>
            <span className="absolute bottom-1 right-1 rounded-full bg-accent p-[7px]">
              <Icon name="photo_camera" size={16} />
            </span>
          </button>
          <input
            ref={fileRef}
            type="file"
            accept="image/*"
            hidden
            onChange={(e) => {
              const f = e.target.files?.[0];
              if (f) setPhoto(f);
              e.target.value = "";
            }}
          />
        </div>
        <div className="mt-1.5 text-center text-xs text-muted">Photo (optional)</div>
        <div className="mt-4 space-y-3">
          <AppTextField
            {...dark}
            label="Shop name"
            icon="storefront"
            value={shopName}
            onChange={setShopName}
            error={errors.shopName}
          />
          <AppTextField
            {...dark}
            label="Category"
            icon="category"
            value={category}
            onChange={setCategory}
            error={errors.category}
          />
          <AppTextField
            {...dark}
            label="Stall"
            icon="location_on"
            value={location}
            onChange={setLocation}
            error={errors.location}
          />
        </div>
        <button
          onClick={saving ? undefined : save}
          className="mt-5 flex h-[50px] w-full items-center justify-center rounded-[14px] bg-accent text-[15px] font-bold"
        >
          {saving ? <Spinner size={22} color="#fff" /> : "Save Exhibitor"}
        </button>
      </div>
    </div>
  );
}
