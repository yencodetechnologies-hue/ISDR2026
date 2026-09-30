/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { AppBar, Icon, Spinner, useToast } from "@/components/ui";
import { AppSpinner } from "@/components/app/AppControls";
import { asset, get } from "@/lib/api";
import { fmtDMon, parseDate } from "@/lib/format";
import { CertificateImage, downloadCertificatePdf, NAME_BOX } from "./certificateShared";

const CERTIFICATES = [
  {
    label: "CERTIFICATE OF ATTENDANCE",
    img: asset("certificate_page-0001.jpg"),
    box: NAME_BOX,
    fileName: "ISDR2026_Certificate.pdf",
  },
  {
    label: "CE / CME CERTIFICATE",
    img: asset("ce,cme.png"),
    box: { left: 0.43, top: 0.41, width: 0.435, height: 0.06 },
    fileName: "ISDR2026_CE_CME_Certificate.pdf",
  },
];

/**
 * Participant Certificate phone screen matching participant_certificate_page.dart:
 * Attendance progress bar, blurred/locked certificates with lock icon,
 * and download PDF trigger when unlocked.
 */
export default function ParticipantCertificateApp() {
  const toast = useToast();
  const [data, setData] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const [downloading, setDownloading] = useState<string | null>(null);

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

  const days: any[] = data?.days ?? [];
  const unlocked = data?.unlocked === true;
  const name = String(data?.name ?? "");
  const done = (d: any) => d?.entryAt != null && d?.exitAt != null;

  const download = async (cert: (typeof CERTIFICATES)[0]) => {
    setDownloading(cert.fileName);
    try {
      await downloadCertificatePdf(name, cert);
    } catch (e) {
      toast(`Could not create the PDF: ${e}`, "error");
    }
    setDownloading(null);
  };

  const mark = (ok: boolean, label: string) => (
    <div className="flex items-center justify-center gap-1 font-inter text-[10px]" style={{ color: ok ? "#fff" : "#9CA3AF" }}>
      <Icon
        name={ok ? "check_circle" : "radio_button_unchecked"}
        size={11}
        color={ok ? "#22C55E" : "#9CA3AF"}
      />
      <span>{label}</span>
    </div>
  );

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
          {/* Attendance Card */}
          <div className="rounded-[14px] border border-white/10 bg-[#14141F] px-2 pb-3.5 pt-4 shadow-sm">
            <div className="mb-3.5 pl-2 font-inter text-[11px] font-bold tracking-[0.6px] text-muted">
              ATTENDANCE
            </div>
            {days.length === 0 ? (
              <div className="pl-2 font-inter text-[12.5px] text-muted">
                Event dates are not set yet
              </div>
            ) : (
              <div className="flex items-start">
                {days.map((d, i) => {
                  const complete = done(d);
                  const partial = !complete && d.entryAt != null;
                  const color = complete
                    ? "#22C55E"
                    : partial
                    ? "#F59E0B"
                    : "rgba(255,255,255,0.08)";
                  const date = parseDate(d.date);
                  return (
                    <div key={i} className="flex-1">
                      <div className="flex items-center">
                        <div
                          className="h-[3px] flex-1"
                          style={{
                            background:
                              i === 0
                                ? "transparent"
                                : complete
                                ? "#22C55E"
                                : "rgba(255,255,255,0.08)",
                          }}
                        />
                        <div
                          className="flex h-[26px] w-[26px] items-center justify-center rounded-full border-2 font-inter text-[11px] font-bold"
                          style={{
                            borderColor: color,
                            background: complete || partial ? color : "transparent",
                            color: partial ? "#fff" : "#9CA3AF",
                          }}
                        >
                          {complete ? (
                            <Icon name="check" size={16} color="#fff" />
                          ) : (
                            i + 1
                          )}
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
                        className="mt-1.5 text-center font-inter text-[11px] font-semibold"
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

          {/* Certificates */}
          {CERTIFICATES.map((cert) => (
            <div key={cert.fileName} className="mt-4">
              <div className="mb-2 pl-1 font-inter text-[11px] font-bold tracking-[0.6px] text-muted">
                {cert.label}
              </div>
              <div className="relative overflow-hidden rounded-[14px] border border-white/10 shadow-lg shadow-black/40">
                {unlocked ? (
                  <>
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
                  </>
                ) : (
                  <>
                    <div style={{ filter: "blur(8px)" }}>
                      <CertificateImage name={name} img={cert.img} box={cert.box} />
                    </div>
                    <div className="absolute inset-0 flex items-center justify-center bg-black/35">
                      <span className="flex rounded-full bg-black/55 p-3.5">
                        <Icon name="lock" size={34} color="#fff" />
                      </span>
                    </div>
                  </>
                )}
              </div>
            </div>
          ))}

          {/* Footer note if locked */}
          {!unlocked && (
            <div className="mt-3.5 px-2 text-center font-inter text-[12.5px] leading-relaxed text-muted">
              Get your entry and exit scanned on all event days to unlock your certificates.
            </div>
          )}
        </div>
      )}
    </div>
  );
}
