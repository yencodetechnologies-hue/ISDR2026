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
  useEffect(() => { load(); }, [load]);

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
    if (res.success) { setItems((l) => (l ?? []).filter((x) => idOf(x) !== idOf(e))); toast("Removed", "success"); }
    else toast(res.error || "Could not remove", "error");
  };

  return (
    <Page title="Exhibitors" actions={<Button small icon="add" onClick={() => setAdding(true)}>Add</Button>}>
      {error ? <ErrorState message={error} onRetry={load} /> : !items ? <Loading /> : items.length === 0 ? (
        <Empty icon="storefront" title="No exhibitors yet" action={<Button icon="add" onClick={() => setAdding(true)}>Add Exhibitor</Button>} />
      ) : (
        <div className="space-y-2.5">
          {items.map((e) => (
            <div key={idOf(e)} className="card flex items-center gap-3 p-3.5">
              <Avatar src={e.photoUrl} name={e.name} size={44} />
              <div className="min-w-0 flex-1">
                <div className="truncate font-bold">{e.name}</div>
                {e.stallNumber && <div className="text-xs text-muted">Stall {e.stallNumber}</div>}
              </div>
              <IconButton icon="delete" outline color="#EF4444" title="Remove" onClick={() => remove(e)} />
            </div>
          ))}
        </div>
      )}

      <Modal open={adding} onClose={() => setAdding(false)} title="Add Exhibitor">
        <div className="space-y-3">
          <PhotoInput file={photo} url={null} onFile={setPhoto} label="Logo" />
          <Field label="Name"><Input value={name} onChange={(e) => setName(e.target.value)} placeholder="Exhibitor / company name" /></Field>
          <Field label="Stall Number"><Input value={stallNumber} onChange={(e) => setStallNumber(e.target.value)} placeholder="e.g. A-12" /></Field>
          <Button full loading={saving} onClick={save}>Add Exhibitor</Button>
        </div>
      </Modal>
    </Page>
  );
}
