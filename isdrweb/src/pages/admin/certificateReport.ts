/* eslint-disable @typescript-eslint/no-explicit-any */
import type { ExportColumn } from "@/lib/exporter";
import { fullNameOf } from "@/lib/exporter";
import { cap } from "@/lib/format";
import { shownParticipantType } from "./participantExport";
import type { FeedbackQuestion } from "../participant/conferenceFeedback";

export function certificateStatusLabel(c: any) {
  if (c?.revoked === true || c?.certificateRevoked === true) return "Revoked";
  if (c?.unlocked === true || c?.certificateUnlocked === true) return "Unlocked";
  return "Locked";
}

function feedbackTime(iso: unknown) {
  if (!iso) return "";
  const d = new Date(String(iso));
  if (Number.isNaN(d.getTime())) return "";
  return d.toLocaleString("en-IN", {
    timeZone: "Asia/Kolkata",
    day: "numeric",
    month: "short",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  });
}

/** Student profile, certificate status, and one column per current feedback question. */
export function certificateReportColumns(questions: FeedbackQuestion[]): ExportColumn<any>[] {
  return [
    { header: "ID no.", value: (r) => r.idNumber, width: 12 },
    { header: "Name", value: (r) => fullNameOf(r) || r.name, width: 26 },
    { header: "Participant type", value: (r) => shownParticipantType(r), width: 16 },
    { header: "Package", value: (r) => r.packageName, width: 18 },
    { header: "Gender", value: (r) => cap(r.gender ?? ""), width: 10 },
    { header: "Designation", value: (r) => r.designation, width: 16 },
    { header: "Organization", value: (r) => r.institution, width: 24 },
    { header: "Mobile no.", value: (r) => r.mobileNumber, width: 14 },
    { header: "Email", value: (r) => r.email, width: 26 },
    { header: "Food preference", value: (r) => r.foodPreference, width: 14 },
    { header: "Address", value: (r) => r.address, width: 28 },
    {
      header: "Days scanned",
      value: (r) => (r.totalDays != null ? `${r.daysScanned ?? 0} / ${r.totalDays}` : ""),
      width: 14,
    },
    { header: "Certificate status", value: (r) => certificateStatusLabel(r), width: 16 },
    { header: "Feedback submitted", value: (r) => (r.feedbackSubmitted ? "Yes" : "No"), width: 16 },
    { header: "Feedback submitted at", value: (r) => feedbackTime(r.conferenceFeedbackAt), width: 22 },
    ...questions.map((q) => ({
      header: `${q.number}. ${q.prompt}`,
      value: (r: any) => r.feedback?.[q.id] || "",
      width: q.type === "text" ? 36 : 22,
    })),
  ];
}
