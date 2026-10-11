/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { AppBar, Icon, Spinner, useToast } from "@/components/ui";
import { AppSpinner } from "@/components/app/AppControls";
import { get, post } from "@/lib/api";
import { CertificateImage, downloadCertificatePdf, resolveCertificates } from "./certificateShared";
import { ConferenceFeedbackForm, type FeedbackQuestion } from "./conferenceFeedback";

/**
 * Participant Certificate phone screen matching participant_certificate_page.dart:
 * Feedback questions until they are submitted, then the certificate with download.
 */
export default function ParticipantCertificateApp() {
  const toast = useToast();
  const [data, setData] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const [downloading, setDownloading] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const load = useCallback(async () => {
    const r = await get("/certificates/me");
    if (r.success) {
      setData(r);
      setError(null);
    } else {
      setError(r.error || "Could not load the certificate");
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const revoked = data?.revoked === true;
  const feedbackSubmitted = data?.feedbackSubmitted === true;
  const questions: FeedbackQuestion[] = data?.questions ?? [];
  const name = String(data?.name ?? "");
  const certificates = resolveCertificates(data);

  const submitFeedback = async (answers: Record<string, string>) => {
    setSubmitting(true);
    const r = await post("/certificates/feedback", { answers });
    if (r.success) await load();
    else toast(r.error || "Could not submit feedback", "error");
    setSubmitting(false);
  };

  const download = async (cert: (typeof certificates)[0]) => {
    setDownloading(cert.fileName);
    try {
      await downloadCertificatePdf(name, cert);
    } catch (e) {
      toast(`Could not create the PDF: ${e}`, "error");
    }
    setDownloading(null);
  };

  return (
    <div className="min-h-screen bg-bg">
      <AppBar title="Certificate" outfit />
      {data === null && !error ? (
        <AppSpinner />
      ) : error ? (
        <div className="flex flex-col items-center px-6 py-20 text-center">
          <Icon name="error_outline" size={40} color="#9CA3AF" />
          <div className="mt-3 font-inter text-sm text-muted">{error}</div>
        </div>
      ) : (
        <div className="px-4 pb-8 pt-4">
          {revoked ? (
            <div className="px-2 py-10 text-center font-inter text-[12.5px] leading-relaxed text-muted">
              Your certificates are not available yet.
            </div>
          ) : !feedbackSubmitted ? (
            <ConferenceFeedbackForm questions={questions} submitting={submitting} onSubmit={submitFeedback} />
          ) : (
            certificates.map((cert) => (
              <div key={cert.fileName} className="mt-4 first:mt-0">
                <div className="mb-2 pl-1 font-inter text-[11px] font-bold tracking-[0.6px] text-muted">
                  {cert.label}
                </div>
                <div className="relative overflow-hidden rounded-[14px] border border-white/10 shadow-lg shadow-black/40">
                  <CertificateImage name={name} img={cert.img} box={cert.box} />
                  <button
                    title="Download PDF"
                    onClick={() => download(cert)}
                    disabled={!!downloading}
                    className="absolute bottom-2 right-2 flex h-8 w-8 items-center justify-center rounded-full bg-black/60 shadow active:bg-black/80"
                  >
                    {downloading === cert.fileName ? (
                      <Spinner size={16} color="#fff" />
                    ) : (
                      <Icon name="download" size={16} color="#fff" />
                    )}
                  </button>
                </div>
              </div>
            ))
          )}
        </div>
      )}
    </div>
  );
}
