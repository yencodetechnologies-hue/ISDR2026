/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import {
  Avatar,
  Button,
  Empty,
  ErrorState,
  Field,
  IconButton,
  Input,
  Loading,
  Modal,
  Page,
  PhotoInput,
  SearchBox,
  useConfirm,
  useToast,
} from "@/components/ui";
import { del, formData, get, post } from "@/lib/api";
import { FilterSelect, matches } from "@/components/ListFilters";
import ExportMenu from "@/components/ExportMenu";
import { idOf } from "@/lib/format";
import { useAppLayout } from "@/lib/appLayout";
import { ExhibitorsListApp } from "./ExhibitorsApp";

export default function ManageExhibitors() {
  // Phone width: the mobile app's screen.
  return useAppLayout() ? <ExhibitorsListApp /> : <ManageExhibitorsWeb />;
}

function ManageExhibitorsWeb() {
  const toast = useToast();
  const confirm = useConfirm();
  const [items, setItems] = useState<any[] | null>(null);
  const [search, setSearch] = useState("");
  const [categoryFilter, setCategoryFilter] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [adding, setAdding] = useState(false);
  const [shopName, setShopName] = useState("");
  const [category, setCategory] = useState("");
  const [location, setLocation] = useState("");
  const [photo, setPhoto] = useState<File | null>(null);
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    const res = await get("/exhibitors");
    if (!res.success) return setError(res.error || "Could not load exhibitors");
    setItems(res.exhibitors ?? []);
  }, []);
  useEffect(() => {
    load();
  }, [load]);

  const save = async () => {
    if (!shopName.trim()) return toast("Enter the shop name", "error");
    if (!category.trim()) return toast("Enter the category", "error");
    if (!location.trim()) return toast("Enter the location", "error");
    setSaving(true);
    const fd = formData({ shopName: shopName.trim(), category: category.trim(), location: location.trim() }, { photo });
    const res = await post("/exhibitors", fd);
    setSaving(false);
    if (!res.success) return toast(res.error || "Could not add exhibitor", "error");
    toast("Exhibitor added", "success");
    setAdding(false);
    setShopName("");
    setCategory("");
    setLocation("");
    setPhoto(null);
    load();
  };

  const remove = async (e: any) => {
    if (!(await confirm({ title: `Remove ${e.shopName}?`, confirm: "Remove", danger: true }))) return;
    const res = await del(`/exhibitors/${idOf(e)}`);
    if (res.success) {
      setItems((l) => (l ?? []).filter((x) => idOf(x) !== idOf(e)));
      toast("Removed", "success");
    } else toast(res.error || "Could not remove", "error");
  };

  const shownItems = (items ?? []).filter(
    (e) =>
      matches(e, search) && (!categoryFilter || String(e.category ?? "") === categoryFilter),
  );
  const categories = [...new Set((items ?? []).map((e) => String(e.category ?? "").trim()).filter(Boolean))].sort();

  return (
    <Page
      title="Exhibitors"
      subtitle={items ? `${items.length} ${items.length === 1 ? "exhibitor" : "exhibitors"}` : undefined}
      actions={
        <div className="flex flex-wrap gap-2">
          <ExportMenu
            title="Exhibitors"
            rows={shownItems}
            columns={[
              { header: "Shop name", value: (e: any) => e.shopName, width: 30 },
              { header: "Category", value: (e: any) => e.category, width: 20 },
              { header: "Location", value: (e: any) => e.location, width: 20 },
            ]}
          />
          <Button icon="add" onClick={() => setAdding(true)}>
            Add Exhibitor
          </Button>
        </div>
      }
    >
      {items && items.length > 0 && (
        <div className="mb-4 flex flex-wrap items-center gap-3">
          <div className="w-full sm:w-80">
            <SearchBox value={search} onChange={setSearch} placeholder="Search shop, category or location…" />
          </div>
          <FilterSelect
            label="categories"
            value={categoryFilter}
            onChange={setCategoryFilter}
            options={categories.map((c) => ({ value: c, label: c }))}
          />
        </div>
      )}
      {items && items.length > 0 && shownItems.length === 0 && (
        <div className="mb-4 rounded-xl border border-line px-5 py-8 text-center text-sm text-muted">
          No results match your search / filters.
        </div>
      )}
      {error ? (
        <ErrorState message={error} onRetry={load} />
      ) : !items ? (
        <Loading />
      ) : items.length === 0 ? (
        <Empty
          icon="storefront"
          title="No exhibitors yet"
          action={
            <Button icon="add" onClick={() => setAdding(true)}>
              Add Exhibitor
            </Button>
          }
        />
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {shownItems.map((e) => (
            <div key={idOf(e)} className="card group relative overflow-hidden">
              <div className="flex h-32 items-center justify-center bg-field">
                {e.photo ? (
                  <img src={e.photo} alt="" className="h-full w-full object-cover" />
                ) : (
                  <Avatar name={e.shopName} size={56} />
                )}
              </div>
              <div className="flex items-center gap-2 p-4">
                <div className="min-w-0 flex-1">
                  <div className="truncate font-semibold">{e.shopName}</div>
                  <div className="truncate text-xs text-muted">
                    {[e.category, e.location].filter(Boolean).join(" · ")}
                  </div>
                </div>
                <IconButton icon="delete" outline color="#EF4444" title="Remove" onClick={() => remove(e)} />
              </div>
            </div>
          ))}
        </div>
      )}

      <Modal
        open={adding}
        onClose={() => setAdding(false)}
        title="Add Exhibitor"
        footer={
          <>
            <Button variant="outline" onClick={() => setAdding(false)}>
              Cancel
            </Button>
            <Button loading={saving} onClick={save}>
              Add Exhibitor
            </Button>
          </>
        }
      >
        <div className="space-y-4">
          <PhotoInput file={photo} url={null} onFile={setPhoto} label="Photo" />
          <Field label="Shop Name">
            <Input value={shopName} onChange={(e) => setShopName(e.target.value)} placeholder="Shop / company name" />
          </Field>
          <Field label="Category">
            <Input value={category} onChange={(e) => setCategory(e.target.value)} placeholder="e.g. Dental equipment" />
          </Field>
          <Field label="Location">
            <Input icon="location_on" value={location} onChange={(e) => setLocation(e.target.value)} placeholder="e.g. Hall B, Stall 12" />
          </Field>
        </div>
      </Modal>
    </Page>
  );
}
