/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useRef, useState } from "react";
import { AppBar, Button, Field, Icon, Loading, Page, Panel, Spinner, useToast } from "@/components/ui";
import { useAppLayout } from "@/lib/appLayout";
import { get, post } from "@/lib/api";

/** Admin form that uploads the programme PDF shown on the participant Schedule screen. */
export default function ManageSchedulePdf() {
  return useAppLayout() ? <SchedulePdfAdminApp /> : <ManageSchedulePdfWeb />;
}

function useSchedulePdfMeta() {
  const [meta, setMeta] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const load = useCallback(async () => {
    const r = await get("/schedule-pdf");
    if (r.success) {
      setMeta(r);
      setError(null);
    } else setError(r.error || "Could not load the schedule PDF");
  }, []);
  useEffect(() => {
    load();
  }, [load]);
  return { meta, error, reload: load };
}

function SchedulePdfAdminApp() {
  const toast = useToast();
  const fileRef = useRef<HTMLInputElement>(null);
  const { meta, error, reload } = useSchedulePdfMeta();
  const [uploading, setUploading] = useState(false);

  const upload = async (file: File) => {
    setUploading(true);
    const fd = new FormData();
    fd.append("pdf", file);
    const r = await post("/schedule-pdf", fd);
    setUploading(false);
    if (r.success) {
      toast("Schedule PDF updated", "success");
      reload();
    } else toast(r.error || "Upload failed", "error");
  };

  return (
    <div className="min-h-screen bg-bg text-white">
      <AppBar title="Schedule PDF" titleClassName="text-[18px] font-bold" />
      <input
        ref={fileRef}
        type="file"
        accept="application/pdf,.pdf"
        hidden
        onChange={(e) => {
          const f = e.target.files?.[0];
          if (f) upload(f);
          e.target.value = "";
        }}
      />
      {!meta && !error ? (
        <div className="flex justify-center pt-24">
          <Spinner color="#fff" />
        </div>
      ) : (
        <div className="space-y-4 p-4">
          <div className="flex items-center gap-3 rounded-[14px] border border-white/10 bg-card p-3.5">
            <Icon name="picture_as_pdf" size={22} color="#F97316" />
            <div className="min-w-0">
              <div className="truncate text-[13.5px] font-semibold">
                {error || meta?.fileName || "No PDF uploaded yet"}
              </div>
              <div className="text-xs text-muted">
                {meta?.url
                  ? "Showing the Cloudinary PDF on Schedule"
                  : "Upload a PDF to show it on Schedule"}
              </div>
            </div>
          </div>
          <p className="text-[13px] leading-relaxed text-muted">
            Participants see this file when they open Schedule. Choose a PDF to replace it.
          </p>
          <button
            onClick={() => !uploading && fileRef.current?.click()}
            className="flex h-[50px] w-full items-center justify-center gap-2 rounded-[14px] bg-[#3B82F6] text-[15px] font-bold"
          >
            {uploading ? <Spinner size={20} color="#fff" /> : <Icon name="upload_file" size={20} />}
            {uploading ? "Uploading…" : "Upload schedule PDF"}
          </button>
        </div>
      )}
    </div>
  );
}

function ManageSchedulePdfWeb() {
  const toast = useToast();
  const fileRef = useRef<HTMLInputElement>(null);
  const { meta, error, reload } = useSchedulePdfMeta();
  const [uploading, setUploading] = useState(false);

  const upload = async (file: File) => {
    setUploading(true);
    const fd = new FormData();
    fd.append("pdf", file);
    const r = await post("/schedule-pdf", fd);
    setUploading(false);
    if (r.success) {
      toast("Schedule PDF updated. Participants will see it on Schedule.", "success");
      reload();
    } else toast(r.error || "Upload failed", "error");
  };

  return (
    <Page
      title="Schedule PDF"
      subtitle="PDF shown when a participant opens Schedule"
      width={760}
      actions={
        <Button icon="upload_file" onClick={() => fileRef.current?.click()} loading={uploading}>
          Upload PDF
        </Button>
      }
    >
      <input
        ref={fileRef}
        type="file"
        accept="application/pdf,.pdf"
        hidden
        onChange={(e) => {
          const f = e.target.files?.[0];
          if (f) upload(f);
          e.target.value = "";
        }}
      />
      {!meta && !error ? (
        <Loading />
      ) : (
        <Panel title="Programme PDF" icon="picture_as_pdf" iconColor="#F97316">
          <div className="mb-5 flex items-start gap-2.5 rounded-lg border border-accent/20 bg-accent/5 p-3.5 text-sm">
            <Icon name="info" outline size={18} color="#60A5FA" />
            <span className="text-white/70">
              The first Schedule option on the participant app and website opens this PDF from Cloudinary. Upload a
              PDF to publish or replace it.
            </span>
          </div>
          <Field label="Current file">
            <div className="flex h-11 items-center rounded-lg border border-line bg-white/[0.03] px-3 text-sm">
              {error || meta?.fileName || "No PDF uploaded yet"}
            </div>
          </Field>
          <div className="mt-2 text-xs text-muted">
            {meta?.url ? "Loaded from Cloudinary." : "Participants see Schedule only after a PDF is uploaded."}
          </div>
        </Panel>
      )}
    </Page>
  );
}
