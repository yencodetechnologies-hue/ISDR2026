/** Stall code such as A1 / B10, parsed from the exhibitor location field. */
export function stallRank(location: unknown) {
  const raw = String(location ?? "").trim().toUpperCase();
  const match = raw.match(/^([A-Z])\s*(\d+)/);
  if (!match) return { letter: "\uffff", num: 9999, code: raw, title: "Other" };
  const letter = match[1];
  const num = Number(match[2]);
  return { letter, num, code: `${letter}${num}`, title: `${letter} Stall` };
}

export function stallCode(location: unknown) {
  return stallRank(location).code;
}

export function sortExhibitors<T extends { location?: string }>(items: T[]) {
  return [...items].sort((a, b) => {
    const left = stallRank(a.location);
    const right = stallRank(b.location);
    if (left.letter !== right.letter) return left.letter < right.letter ? -1 : 1;
    return left.num - right.num;
  });
}

export function groupExhibitors<T extends { location?: string }>(items: T[]) {
  const groups: { title: string; items: T[] }[] = [];
  for (const item of sortExhibitors(items)) {
    const title = stallRank(item.location).title;
    const last = groups[groups.length - 1];
    if (last && last.title === title) last.items.push(item);
    else groups.push({ title, items: [item] });
  }
  return groups;
}
