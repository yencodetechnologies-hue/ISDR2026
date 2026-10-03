/* eslint-disable @typescript-eslint/no-explicit-any */
import { fullNameOf, type ExportColumn, type QrConfig } from "@/lib/exporter";
import { cap } from "@/lib/format";

/** Participants download: every form field, claims, and the QR pass. */
export const PARTICIPANT_EXPORT_COLUMNS: ExportColumn<any>[] = [
  { header: "ID no.", value: (r) => r.idNumber, width: 10 },
  { header: "Name", value: (r) => fullNameOf(r), width: 22 },
  { header: "Participant type", value: (r) => r.participantType, width: 12 },
  { header: "Package", value: (r) => r.packageName, width: 14 },
  { header: "Gender", value: (r) => cap(r.gender ?? ""), width: 8 },
  { header: "Designation", value: (r) => r.designation, width: 14 },
  { header: "Organization", value: (r) => r.institution, width: 20 },
  { header: "Mobile no.", value: (r) => r.mobileNumber, width: 13 },
  { header: "Email", value: (r) => r.email, width: 22 },
  { header: "Food preference", value: (r) => r.foodPreference, width: 10 },
  { header: "Payment mode", value: (r) => String(r.paymentMode ?? "").toUpperCase(), width: 10 },
  { header: "UTR no.", value: (r) => r.utrNumber, width: 12 },
  { header: "Address", value: (r) => r.address, width: 20 },
  { header: "Status", value: (r) => cap(String(r.status ?? "registered").replace("_", " ")), width: 11 },
  {
    header: "Claimed inclusions",
    value: (r) => (r.claimedInclusions ?? []).map((c: any) => c.inclusionName).join(", "),
    width: 20,
  },
];

export const PARTICIPANT_QR: QrConfig<any> = {
  code: (r) => String(r.qrCode || r.idNumber || ""),
  badge: (r) => ({
    name: r.name,
    title: r.title,
    participantType: r.participantType,
    participantTypeColor: r.participantTypeColor,
    idNumber: r.idNumber,
    designation: r.designation,
    institution: r.institution,
    qrCode: r.qrCode || r.idNumber,
  }),
  fileName: (r) => {
    const id = r.idNumber || "SPOT";
    const name = fullNameOf(r);
    return name ? `${id} - ${name}` : id;
  },
};
