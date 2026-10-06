/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useRef, useState } from "react";
import { AppBar, Button, Field, Icon, Loading, Page, Panel, Spinner, useToast } from "@/components/ui";
import { useAppLayout } from "@/lib/appLayout";
import { get, post } from "@/lib/api";

/** Admin form that uploads the UG paper and e-poster PDF participants open from home. */
export default function ManageUgPaperPdf() {
  return useAppLayout() ? <UgPaperPdfAdminApp /> : <ManageUgPaperPdfWeb />;
}

function useUgPaperPdfMeta() {
  const [meta, setMeta] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const load = useCallback(async () => {
    const r = await get("/ug-paper-pdf");
    if (r.success) {
      setMeta(r);
      setError(null);
    } else setError(r.error || "Could not load the presentation PDF");
  }, []);
  useEffect(() => {
    load();
  }, [load]);
  return { meta, error, reload: load };
}

function UgPaperPdfAdminApp() {
  const toast = useToast();
  const fileRef = useRef<HTMLInputElement>(null);
  const { meta, error, reload } = useUgPaperPdfMeta();
  const [uploading, setUploading] = useState(false);

  const upload = async (file: File) => {
    setUploading(true);
    const fd = new FormData();
    fd.append("pdf", file);
    const r = await post("/ug-paper-pdf", fd);
    setUploading(false);
    if (r.success) {
      toast("Presentation PDF updated", "success");
      reload();
    } else toast(r.error || "Upload failed", "error");
  };

  return (
    <div className="min-h-screen bg-bg text-white">
      <AppBar title="UG Paper PDF" titleClassName="text-[18px] font-bold" />
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
            <Icon name="picture_as_pdf" size={22} color="#F59E0B" />
              <div className="min-w-0 flex-1">
                <div className="truncate text-[13.5px] font-semibold">
                  {error || meta?.fileName || "No PDF uploaded yet"}
                </div>
                {meta?.url ? (
                  <a
                    href={meta.url}
                    target="_blank"
                    rel="noreferrer"
                    className="mt-1 block break-all text-xs font-medium text-[#93C5FD] underline"
                  >
                    {meta.url}
                  </a>
                ) : (
                  <div className="text-xs text-muted">Upload a PDF to show it on the participant home</div>
                )}
              </div>
          </div>
          <p className="text-[13px] leading-relaxed text-muted">
            Participants open this file from UG Paper and E-Poster Presentation. Choose a PDF to replace it. The
            server compresses the file before it is stored on Cloudinary.
          </p>
          <button
            onClick={() => !uploading && fileRef.current?.click()}
            className="flex h-[50px] w-full items-center justify-center gap-2 rounded-[14px] bg-[#3B82F6] text-[15px] font-bold"
          >
            {uploading ? <Spinner size={20} color="#fff" /> : <Icon name="upload_file" size={20} />}
            {uploading ? "Uploading…" : meta?.url ? "Replace presentation PDF" : "Upload presentation PDF"}
          </button>
        </div>
      )}
    </div>
  );
}

function ManageUgPaperPdfWeb() {
  const toast = useToast();
  const fileRef = useRef<HTMLInputElement>(null);
  const { meta, error, reload } = useUgPaperPdfMeta();
  const [uploading, setUploading] = useState(false);

  const upload = async (file: File) => {
    setUploading(true);
    const fd = new FormData();
    fd.append("pdf", file);
    const r = await post("/ug-paper-pdf", fd);
    setUploading(false);
    if (r.success) {
      toast("Presentation PDF updated. Participants will see it on home.", "success");
      reload();
    } else toast(r.error || "Upload failed", "error");
  };

  return (
    <Page
      title="UG Paper PDF"
      subtitle="PDF shown for UG Paper and E-Poster Presentation"
      width={760}
      actions={
        <Button icon="upload_file" onClick={() => fileRef.current?.click()} loading={uploading}>
          {meta?.url ? "Replace PDF" : "Upload PDF"}
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
        <Panel title="Presentation PDF" icon="picture_as_pdf" iconColor="#F59E0B">
          <div className="mb-5 flex items-start gap-2.5 rounded-lg border border-accent/20 bg-accent/5 p-3.5 text-sm">
            <Icon name="info" outline size={18} color="#60A5FA" />
            <span className="text-white/70">
              The UG Paper and E-Poster Presentation row on the participant home opens this PDF from Cloudinary.
              Upload a PDF to publish it, or upload again to replace it. The file is compressed before upload when
              Ghostscript is available.
            </span>
          </div>
          <Field label="Cloudinary link">
            {meta?.url ? (
              <a
                href={meta.url}
                target="_blank"
                rel="noreferrer"
                className="flex min-h-11 items-center break-all rounded-lg border border-line bg-white/[0.03] px-3 py-2 text-sm text-[#93C5FD] underline"
              >
                {meta.url}
              </a>
            ) : (
              <div className="flex h-11 items-center rounded-lg border border-line bg-white/[0.03] px-3 text-sm text-muted">
                {error || "The link appears here after you upload a PDF"}
              </div>
            )}
          </Field>
          <div className="mt-2 text-xs text-muted">
            {meta?.fileName ? `Current file: ${meta.fileName}` : "Participants see an empty state until a PDF is uploaded."}
          </div>
        </Panel>
      )}
    </Page>
  );
}
