/* eslint-disable @typescript-eslint/no-explicit-any, react-refresh/only-export-components */
import { useEffect, useState } from "react";
import { Button, Icon, Loading, Page, Spinner, useToast } from "@/components/ui";
import { get, post } from "@/lib/api";
import { useAppLayout } from "@/lib/appLayout";
import ParticipantCertificateApp from "./ParticipantCertificateApp";
import { ConferenceFeedbackForm, type FeedbackQuestion } from "./conferenceFeedback";

import {
  CertificateImage,
  downloadCertificatePdf,
  resolveCertificates,
  type Cert,
} from "./certificateShared";

export { CertificateImage, downloadCertificatePdf };

/** Participant certificate. Feedback is shown until it is submitted, then the certificate can be downloaded. */
export default function ParticipantCertificate() {
  return useAppLayout() ? <ParticipantCertificateApp /> : <ParticipantCertificateWeb />;
}

function ParticipantCertificateWeb() {
  const toast = useToast();
  const [data, setData] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  // fileName of the certificate whose PDF is being built, if any.
  const [downloading, setDownloading] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const load = () => {
    get("/certificates/me").then((r) => {
      if (r.success) setData(r);
      else setError(r.error || "Could not load the certificate");
    });
  };
  useEffect(() => {
    load();
  }, []);

  const revoked = data?.revoked === true;
  const feedbackSubmitted = data?.feedbackSubmitted === true;
  const questions: FeedbackQuestion[] = data?.questions ?? [];
  const name = String(data?.name ?? "");
  const certificates = resolveCertificates(data);

  const submitFeedback = async (answers: Record<string, string>) => {
    setSubmitting(true);
    const r = await post("/certificates/feedback", { answers });
    if (r.success) load();
    else toast(r.error || "Could not submit feedback", "error");
    setSubmitting(false);
  };

  const download = async (cert: Cert) => {
    setDownloading(cert.fileName);
    try {
      await downloadCertificatePdf(name, cert);
    } catch (e) {
      toast(`Could not create the PDF: ${e}`, "error");
    }
    setDownloading(null);
  };

  return (
    <Page
      title="Certificate"
      subtitle={
        revoked
          ? "Your certificates are not available yet."
          : feedbackSubmitted
            ? "Your certificates are ready to download"
            : "Share your feedback to download your certificate"
      }
      back={false}
      width={960}
    >
      {error ? (
        <div className="py-16 text-center text-muted">{error}</div>
      ) : !data ? (
        <Loading />
      ) : (
        <>
          {revoked ? (
            <div className="py-10 text-center text-[12.5px] text-muted">Your certificates are not available yet.</div>
          ) : !feedbackSubmitted ? (
            <ConferenceFeedbackForm questions={questions} submitting={submitting} onSubmit={submitFeedback} />
          ) : (
            certificates.map((cert) => (
              <div key={cert.fileName} className="mt-6 first:mt-0">
                <div className="mb-2 flex items-center gap-3">
                  <div className="eyebrow flex-1 pl-1">{cert.label}</div>
                  <Button
                    small
                    variant="outline"
                    icon="download"
                    loading={downloading === cert.fileName}
                    disabled={!!downloading}
                    onClick={() => download(cert)}
                  >
                    Download PDF
                  </Button>
                </div>
                <div className="relative overflow-hidden rounded-xl border border-line shadow-2xl shadow-black/40">
                  <CertificateImage name={name} img={cert.img} box={cert.box} />
                  <button
                    title="Download PDF"
                    onClick={() => download(cert)}
                    disabled={!!downloading}
                    className="absolute bottom-2 right-2 flex h-8 w-8 items-center justify-center rounded-full bg-black/60"
                  >
                    {downloading === cert.fileName ? (
                      <Spinner size={16} color="#fff" />
                    ) : (
                      <Icon name="download" size={16} />
                    )}
                  </button>
                </div>
              </div>
            ))
          )}
        </>
      )}
    </Page>
  );
}
