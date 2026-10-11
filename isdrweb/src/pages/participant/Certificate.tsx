/* eslint-disable @typescript-eslint/no-explicit-any, react-refresh/only-export-components */
import { useEffect, useState } from "react";
import { Button, Icon, Loading, Page, Spinner, useToast } from "@/components/ui";
import { get, post } from "@/lib/api";
import { fmtDMon, parseDate } from "@/lib/format";
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

/** Participant: day-by-day entry/exit progress and the certificates. */
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

  const days: any[] = data?.days ?? [];
  const revoked = data?.revoked === true;
  const feedbackSubmitted = data?.feedbackSubmitted === true;
  const unlocked = !revoked && feedbackSubmitted;
  const questions: FeedbackQuestion[] = data?.questions ?? [];
  const name = String(data?.name ?? "");
  const certificates = resolveCertificates(data);
  const done = (d: any) => d?.entryAt != null && d?.exitAt != null;

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

  const mark = (ok: boolean, label: string) => (
    <div className="flex items-center justify-center gap-1 text-[10px]" style={{ color: ok ? "#fff" : "#9CA3AF" }}>
      <Icon name={ok ? "check_circle" : "radio_button_unchecked"} size={11} color={ok ? "#22C55E" : "#9CA3AF"} />
      {label}
    </div>
  );

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
          <div className="card px-3 pb-5 pt-5">
            <div className="eyebrow mb-4 pl-3">Attendance</div>
            {days.length === 0 ? (
              <div className="pl-2 text-[12.5px] text-muted">Event dates are not set yet</div>
            ) : (
              <div className="flex items-start">
                {days.map((d, i) => {
                  const complete = done(d);
                  const partial = !complete && d.entryAt != null;
                  const color = complete ? "#22C55E" : partial ? "#F59E0B" : "rgba(255,255,255,0.08)";
                  const date = parseDate(d.date);
                  return (
                    <div key={i} className="flex-1">
                      <div className="flex items-center">
                        <div
                          className="h-[3px] flex-1"
                          style={{
                            background: i === 0 ? "transparent" : complete ? "#22C55E" : "rgba(255,255,255,0.08)",
                          }}
                        />
                        <div
                          className="flex h-[26px] w-[26px] items-center justify-center rounded-full border-2 text-[11px] font-bold"
                          style={{
                            borderColor: color,
                            background: complete || partial ? color : "transparent",
                            color: partial ? "#fff" : "#9CA3AF",
                          }}
                        >
                          {complete ? <Icon name="check" size={16} color="#fff" /> : i + 1}
                        </div>
                        <div
                          className="h-[3px] flex-1"
                          style={{
                            background:
                              i === days.length - 1
                                ? "transparent"
                                : done(days[i + 1])
                                  ? "#22C55E"
                                  : "rgba(255,255,255,0.08)",
                          }}
                        />
                      </div>
                      <div
                        className="mt-1.5 text-center text-[11px] font-semibold"
                        style={{ color: complete ? "#fff" : "#9CA3AF" }}
                      >
                        {date ? fmtDMon(date) : `Day ${i + 1}`}
                      </div>
                      <div className="mt-1 space-y-0.5">
                        {mark(d.entryAt != null, "In")}
                        {mark(d.exitAt != null, "Out")}
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
          {!revoked && !feedbackSubmitted ? (
            <ConferenceFeedbackForm questions={questions} submitting={submitting} onSubmit={submitFeedback} />
          ) : certificates.map((cert) => (
            <div key={cert.fileName} className="mt-6">
              <div className="mb-2 flex items-center gap-3">
                <div className="eyebrow flex-1 pl-1">{cert.label}</div>
                {unlocked && (
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
                )}
              </div>
              <div className="relative overflow-hidden rounded-xl border border-line shadow-2xl shadow-black/40">
                {unlocked ? (
                  <>
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
                  </>
                ) : (
                  <>
                    <div style={{ filter: "blur(8px)" }}>
                      <CertificateImage name={name} img={cert.img} box={cert.box} />
                    </div>
                    <div className="absolute inset-0 flex items-center justify-center bg-black/35">
                      <span className="flex rounded-full bg-black/55 p-3.5">
                        <Icon name="lock" size={34} />
                      </span>
                    </div>
                  </>
                )}
              </div>
            </div>
          ))}
        </>
      )}
    </Page>
  );
}
