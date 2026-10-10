/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { AppBar, Icon, Spinner, useConfirm, useToast } from "@/components/ui";
import { AppSpinner } from "@/components/app/AppControls";
import { get, post } from "@/lib/api";
import { exportExcel } from "@/lib/exporter";
import { FeedbackAnswers, type FeedbackQuestion } from "../participant/conferenceFeedback";
import { FeedbackQuestionManager } from "../participant/feedbackQuestionAdmin";
import { certificateReportColumns } from "./certificateReport";

/** Certificate at phone width — the app's AdminCertificatesPage. */
export default function CertificatesApp() {
  const toast = useToast();
  const confirm = useConfirm();
  const [all, setAll] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showUnlocked, setShowUnlocked] = useState(false);
  const [query, setQuery] = useState("");
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [unlocking, setUnlocking] = useState(false);
  const [questions, setQuestions] = useState<FeedbackQuestion[]>([]);
  const [viewing, setViewing] = useState<any | null>(null);
  const [showQuestions, setShowQuestions] = useState(false);
  const [exporting, setExporting] = useState(false);

  const load = useCallback(async () => {
    const r = await get("/certificates");
    setLoading(false);
    if (r.success) {
      setAll(r.participants ?? []);
      setQuestions(r.questions ?? []);
      setError(null);
    } else setError(r.error || "Could not load participants");
  }, []);
  useEffect(() => {
    load();
  }, [load]);

  const q = query.trim().toLowerCase();
  const visible = all.filter(
    (p) =>
      (p.unlocked === true) === showUnlocked &&
      (!q || `${p.name} ${p.idNumber} ${p.mobileNumber}`.toLowerCase().includes(q)),
  );
  const unlockedCount = all.filter((p) => p.unlocked === true).length;

  const unlock = async () => {
    if (
      !(await confirm({
        title: "Unlock certificates",
        message: `Unlock the certificate for ${selected.size} participant(s)?`,
        confirm: "Unlock",
        filled: true,
      }))
    )
      return;
    setUnlocking(true);
    const r = await post("/certificates/unlock", { registrationIds: [...selected] });
    setUnlocking(false);
    toast(r.success ? "Certificates unlocked" : r.error || "Could not unlock");
    if (r.success) {
      setSelected(new Set());
      load();
    }
  };
  const revert = async (p: any) => {
    const earned = p.earned === true;
    if (
      !(await confirm({
        title: "Revert certificate",
        message: earned
          ? `Lock the certificate of ${p.name}? It stays locked even though their scans earned it, until you unlock it again.`
          : `Lock the certificate of ${p.name} again?`,
        confirm: "Revert",
        danger: true,
      }))
    )
      return;
    const r = await post("/certificates/revert", { registrationIds: [p.id] });
    toast(r.success ? "Certificate reverted" : r.error || "Could not revert");
    if (r.success) load();
  };

  const download = async () => {
    if (!visible.length) return toast("Nothing to download");
    setExporting(true);
    try {
      await exportExcel("Certificate report", certificateReportColumns(questions), visible);
    } catch (e) {
      toast(`Could not create the file: ${(e as Error)?.message ?? e}`);
    }
    setExporting(false);
  };

  const toggle = (id: string) =>
    setSelected((s) => {
      const n = new Set(s);
      if (n.has(id)) n.delete(id);
      else n.add(id);
      return n;
    });

  const tab = (label: string, value: boolean, count: number) => (
    <button
      onClick={() => {
        setShowUnlocked(value);
        setSelected(new Set());
      }}
      className="flex-1 rounded-xl py-[11px] text-[13px] font-bold"
      style={{
        background: showUnlocked === value ? "#3B82F6" : "transparent",
        color: showUnlocked === value ? "#fff" : "#9CA3AF",
      }}
    >
      {label} ({count})
    </button>
  );

  return (
    <div className="min-h-screen bg-bg">
      <AppBar
        title={showQuestions ? "Feedback questions" : "Certificate"}
        outfit
        back
        onBack={showQuestions ? () => setShowQuestions(false) : undefined}
        actions={
          showQuestions ? null : (
            <div className="flex items-center">
              <button
                onClick={exporting ? undefined : download}
                className="px-2 text-sm font-semibold text-accent"
              >
                {exporting ? "…" : "Excel"}
              </button>
              <button onClick={() => setShowQuestions(true)} className="px-2 text-sm font-semibold text-accent">
                Questions
              </button>
            </div>
          )
        }
      />
      {showQuestions ? (
        <div className="px-4 pb-8 pt-4">
          <FeedbackQuestionManager onChanged={load} />
        </div>
      ) : loading ? (
        <AppSpinner />
      ) : error ? (
        <div className="pt-40 text-center text-muted">{error}</div>
      ) : (
        <div className={`p-4 ${!showUnlocked && selected.size ? "pb-24" : ""}`}>
          <div className="flex rounded-[14px] border border-line bg-card p-1">
            {tab("Not yet", false, all.length - unlockedCount)}
            {tab("Got certificate", true, unlockedCount)}
          </div>
          <div className="relative mt-3">
            <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2">
              <Icon name="search" color="#9CA3AF" />
            </span>
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search name, ID or mobile"
              className="w-full rounded-[14px] bg-field py-4 pl-12 pr-3 text-base outline-none placeholder:text-muted"
            />
          </div>
          {!showUnlocked && visible.length > 0 ? (
            <div className="flex justify-end">
              <button
                onClick={() =>
                  setSelected((s) => {
                    const ids = visible.map((p) => String(p.id));
                    const n = new Set(s);
                    if (ids.every((i) => n.has(i))) ids.forEach((i) => n.delete(i));
                    else ids.forEach((i) => n.add(i));
                    return n;
                  })
                }
                className="h-10 rounded-full px-3 text-sm font-medium text-accent"
              >
                Select all
              </button>
            </div>
          ) : (
            <div className="h-3" />
          )}
          {visible.length === 0 ? (
            <div className="pt-10 text-center text-muted">No participants</div>
          ) : (
            visible.map((p) => {
              const id = String(p.id);
              const unlocked = p.unlocked === true;
              const earned = p.earned === true;
              const sel = selected.has(id);
              const scanned = Number(p.daysScanned) || 0;
              const total = Number(p.totalDays) || 0;
              const [status, color, icon] = !unlocked
                ? p.revoked === true
                  ? ["Reverted", "#F87171", "undo"]
                  : ["Locked", "#94A3B8", "lock"]
                : earned
                  ? ["Earned by scans", "#22C55E", "qr_code_scanner"]
                  : ["Unlocked by admin", "#F59E0B", "admin_panel_settings"];
              const initials = String(p.name ?? "")
                .trim()
                .split(/\s+/)
                .filter(Boolean)
                .slice(0, 2)
                .map((w) => w[0].toUpperCase())
                .join("");
              return (
                <div
                  key={id}
                  onClick={unlocked ? undefined : () => toggle(id)}
                  className={`mb-3 rounded-[18px] bg-card px-3.5 pb-3 pt-3.5 ${unlocked ? "" : "cursor-pointer"}`}
                  style={{ border: `${sel ? 1.5 : 1}px solid ${sel ? "#3B82F6" : "rgba(255,255,255,0.07)"}` }}
                >
                  <div className="flex items-center">
                    <span
                      className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full border"
                      style={{
                        background: sel ? "#3B82F6" : `${color}26`,
                        borderColor: sel ? "#3B82F6" : `${color}80`,
                      }}
                    >
                      {sel ? (
                        <Icon name="check" size={22} />
                      ) : (
                        <span className="font-outfit text-base font-bold" style={{ color }}>
                          {initials || "?"}
                        </span>
                      )}
                    </span>
                    <div className="ml-3 min-w-0 flex-1">
                      <div className="truncate text-[15px] font-bold">{p.name}</div>
                      <span className="mt-1 inline-block rounded-md bg-white/[0.06] px-[7px] py-0.5 text-[11px] font-semibold text-muted">
                        {p.idNumber}
                      </span>
                    </div>
                    <span
                      className="ml-2 inline-flex shrink-0 items-center gap-1 rounded-full border px-[9px] py-[5px] text-[10.5px] font-bold"
                      style={{ background: `${color}1f`, borderColor: `${color}66`, color }}
                    >
                      <Icon name={icon} size={12} color={color} />
                      {status}
                    </span>
                  </div>
                  <div className="mt-3 flex text-[11.5px]">
                    <span className="text-muted">Days scanned</span>
                    <span className="ml-auto font-bold">
                      {scanned} / {total}
                    </span>
                  </div>
                  <div className="mt-1.5 h-1.5 overflow-hidden rounded bg-white/[0.07]">
                    <div
                      className="h-full"
                      style={{
                        width: `${total ? (scanned / total) * 100 : 0}%`,
                        background: scanned >= total && total > 0 ? "#22C55E" : "#3B82F6",
                      }}
                    />
                  </div>
                  {unlocked && (
                    <>
                      <div className="mt-2.5 h-px bg-white/[0.06]" />
                      <div className="mt-1 flex items-center justify-end gap-1">
                        {p.feedbackSubmitted === true && (
                          <button
                            onClick={() => setViewing(p)}
                            className="inline-flex h-9 items-center gap-1.5 rounded-full px-2.5 text-[12.5px] font-bold text-accent"
                          >
                            <Icon name="rate_review" size={16} color="#3B82F6" />
                            View feedback
                          </button>
                        )}
                        <button
                          onClick={() => revert(p)}
                          className="inline-flex h-9 items-center gap-1.5 rounded-full px-2.5 text-[12.5px] font-bold text-[#F87171]"
                        >
                          <Icon name="undo" size={16} color="#F87171" />
                          Revert certificate
                        </button>
                      </div>
                    </>
                  )}
                  {!unlocked && p.feedbackSubmitted === true && (
                    <div className="mt-2 flex justify-end">
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          setViewing(p);
                        }}
                        className="inline-flex h-9 items-center gap-1.5 rounded-full px-2.5 text-[12.5px] font-bold text-accent"
                      >
                        <Icon name="rate_review" size={16} color="#3B82F6" />
                        View feedback
                      </button>
                    </div>
                  )}
                </div>
              );
            })
          )}
        </div>
      )}
      {!showUnlocked && selected.size > 0 && (
        <div className="fixed inset-x-0 bottom-0 z-30 bg-bg px-4 pb-3 pt-2">
          <button
            onClick={unlocking ? undefined : unlock}
            className="flex h-[50px] w-full items-center justify-center gap-2 rounded-[14px] bg-accent text-[15px] font-bold"
          >
            {unlocking ? <Spinner size={20} color="#fff" /> : <Icon name="lock_open" />}
            Unlock certificate ({selected.size})
          </button>
        </div>
      )}
      {viewing && (
        <div className="fixed inset-0 z-40 flex items-end justify-center bg-black/60" onClick={() => setViewing(null)}>
          <div
            className="max-h-[85vh] w-full overflow-y-auto rounded-t-2xl bg-card px-4 pb-6 pt-4"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="mb-3 flex items-center gap-3">
              <div className="min-w-0 flex-1">
                <div className="truncate text-base font-bold">{viewing.name}</div>
                <div className="text-xs text-muted">Conference feedback</div>
              </div>
              <button onClick={() => setViewing(null)} className="rounded-full p-1 text-muted">
                <Icon name="close" />
              </button>
            </div>
            <FeedbackAnswers questions={questions} answers={viewing.feedback} />
          </div>
        </div>
      )}
    </div>
  );
}
