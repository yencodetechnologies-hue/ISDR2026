/* eslint-disable @typescript-eslint/no-explicit-any */
export type AwardRecipient = { rank: number; name: string };

/** Turns typed rank/name rows into recipients. Blank names are skipped. */
export function manualRecipients(
  rows: { rank: string; name: string }[],
): { recipients: AwardRecipient[] } | { error: string } {
  const recipients: AwardRecipient[] = [];
  for (const row of rows) {
    const name = row.name.trim();
    if (!name) continue;
    const rank = Number(row.rank);
    if (!Number.isInteger(rank) || rank < 1) return { error: "Each recipient needs a rank of 1 or more" };
    if (name.length > 200) return { error: "A name is too long" };
    recipients.push({ rank, name });
  }
  if (!recipients.length) return { error: "Enter a name" };
  if (recipients.length > 20) return { error: "At most 20 recipients" };
  return { recipients };
}

/** Category order from the results sheet. First appearance wins in the combined list. */
const CONSOLIDATED_ORDER = [5, 4, 8, 6, 7, 3, 11, 12];

export function recipientsOf(winners: Record<string, any>, n: number): AwardRecipient[] {
  const row = winners[String(n)];
  if (!row || typeof row !== "object") return [];
  if (Array.isArray(row.recipients) && row.recipients.length) {
    return row.recipients
      .map((r: any) => ({ rank: Number(r.rank) || 1, name: String(r.name || "").trim() }))
      .filter((r: AwardRecipient) => r.name);
  }
  const name = String(row.name || "").trim();
  return name ? [{ rank: 1, name }] : [];
}

/** Unique recipients, presentation order, one line per person. */
export function consolidatedNames(winners: Record<string, any>): string[] {
  const seen = new Set<string>();
  const names: string[] = [];
  const add = (rows: AwardRecipient[]) => {
    for (const r of rows) {
      const key = r.name.toLowerCase();
      if (seen.has(key)) continue;
      seen.add(key);
      names.push(r.name);
    }
  };
  for (const n of CONSOLIDATED_ORDER) add(recipientsOf(winners, n));
  for (const key of Object.keys(winners)) {
    const n = Number(key);
    if (!Number.isInteger(n) || CONSOLIDATED_ORDER.includes(n)) continue;
    add(recipientsOf(winners, n));
  }
  return names;
}
