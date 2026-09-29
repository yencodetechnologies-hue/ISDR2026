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
  useConfirm,
  useToast,
} from "@/components/ui";
import { del, formData, get, post } from "@/lib/api";
import ExportMenu from "@/components/ExportMenu";
import { idOf } from "@/lib/format";

export default function ManageExhibitors() {
  const toast = useToast();
  const confirm = useConfirm();
  const [items, setItems] = useState<any[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [adding, setAdding] = useState(false);
  const [name, setName] = useState("");
  const [stallNumber, setStallNumber] = useState("");
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
    if (!name.trim()) return toast("Enter the exhibitor name", "error");
    setSaving(true);
    const fd = formData({ name: name.trim(), stallNumber: stallNumber.trim() }, { photo });
    const res = await post("/exhibitors", fd);
    setSaving(false);
    if (!res.success) return toast(res.error || "Could not add exhibitor", "error");
    toast("Exhibitor added", "success");
    setAdding(false);
    setName("");
    setStallNumber("");
    setPhoto(null);
    load();
  };

  const remove = async (e: any) => {
    if (!(await confirm({ title: `Remove ${e.name}?`, confirm: "Remove", danger: true }))) return;
    const res = await del(`/exhibitors/${idOf(e)}`);
    if (res.success) {
      setItems((l) => (l ?? []).filter((x) => idOf(x) !== idOf(e)));
      toast("Removed", "success");
    } else toast(res.error || "Could not remove", "error");
  };

  return (
    <Page
      title="Exhibitors"
      subtitle={items ? `${items.length} ${items.length === 1 ? "exhibitor" : "exhibitors"}` : undefined}
      actions={
        <div className="flex flex-wrap gap-2">
          <ExportMenu
            title="Exhibitors"
            rows={items}
            columns={[
              { header: "Name", value: (e: any) => e.name, width: 30 },
              { header: "Stall number", value: (e: any) => e.stallNumber, width: 14 },
            ]}
          />
          <Button icon="add" onClick={() => setAdding(true)}>
            Add Exhibitor
          </Button>
        </div>
      }
    >
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
          {items.map((e) => (
            <div key={idOf(e)} className="card group relative overflow-hidden">
              <div className="flex h-32 items-center justify-center bg-field">
                {e.photoUrl ? (
                  <img src={e.photoUrl} alt="" className="h-full w-full object-cover" />
                ) : (
                  <Avatar name={e.name} size={56} />
                )}
              </div>
              <div className="flex items-center gap-2 p-4">
                <div className="min-w-0 flex-1">
                  <div className="truncate font-semibold">{e.name}</div>
                  <div className="text-xs text-muted">
                    {e.stallNumber ? `Stall ${e.stallNumber}` : "No stall number"}
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
          <PhotoInput file={photo} url={null} onFile={setPhoto} label="Logo" />
          <Field label="Name">
            <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="Exhibitor / company name" />
          </Field>
          <Field label="Stall Number">
            <Input value={stallNumber} onChange={(e) => setStallNumber(e.target.value)} placeholder="e.g. A-12" />
          </Field>
        </div>
      </Modal>
    </Page>
  );
}
