/**
 * Sets postgraduate students from the IADR ID card workbook to participant
 * type "Delegate" with the delegate banner colour, on the ISDR 2026 event.
 *
 * Only the four PG sheets are read. People are matched by the last 10 digits
 * of their mobile. Undergraduate rows are not touched. The script stops
 * before writing if any PG mobile is missing, or if a match sits on an
 * undergraduate package.
 *
 * Usage: node scripts/fixPgDelegateTypes.js
 */
const path = require('path');
const { execFileSync } = require('child_process');
const dotenv = require('dotenv');
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const connectDB = require('../config/database');
const ManagedEvent = require('../models/ManagedEvent');
const EventRegistration = require('../models/EventRegistration');

const WORKBOOK = 'c:\\Users\\Jeyaram\\Desktop\\IADR ID CARD STUDENTS.xlsx';
const PG_SHEETS = ['6000RS SBDCH PG', '9500RS OTHER PG', '7500RS OTHER PG', '4500RS OTHER PG'];
const PARTICIPANT_TYPE = 'Delegate';
const TYPE_COLOR = '#006344';
const UG_PACKAGES = new Set(['SBDCH UG 2000', 'SBDCH UG 3500', 'Other UG 2000', 'Other UG 6000']);

function last10(value) {
  const digits = String(value || '').replace(/\D/g, '');
  return digits.length > 10 ? digits.slice(-10) : digits;
}

function readPgRows() {
  const py = `
import json, openpyxl
wb = openpyxl.load_workbook(${JSON.stringify(WORKBOOK)}, data_only=True, read_only=True)
wanted = set(${JSON.stringify(PG_SHEETS)})
out = []
for name in wb.sheetnames:
    if name not in wanted:
        continue
    ws = wb[name]
    rows = list(ws.iter_rows(values_only=True))
    header_i = next(i for i, r in enumerate(rows[:5]) if r and r[0] == 'ID')
    headers = [str(h).strip() if h else '' for h in rows[header_i]]
    for r in rows[header_i + 1:]:
        if not r or r[0] is None:
            continue
        rec = {headers[i]: r[i] for i in range(min(len(headers), len(r))) if headers[i]}
        out.append({
            'sheet': name,
            'formId': rec.get('ID'),
            'name': ' '.join(str(rec.get(k) or '').strip() for k in ('First Name', 'Middle Name', 'Last Name')).strip(),
            'mobile': str(rec.get('Mobile') or '').strip(),
            'type': str(rec.get('Type') or '').strip(),
        })
wb.close()
print(json.dumps(out))
`;
  const raw = execFileSync('python', ['-c', py], { encoding: 'utf8', maxBuffer: 10 * 1024 * 1024 });
  return JSON.parse(raw);
}

(async () => {
  const rows = readPgRows();
  const badType = rows.filter((row) => row.type !== PARTICIPANT_TYPE);
  if (badType.length) {
    console.error(`Refusing: ${badType.length} PG row(s) are not type "${PARTICIPANT_TYPE}" in the workbook.`);
    process.exit(1);
  }
  console.log(`Workbook PG rows: ${rows.length}`);

  await connectDB();
  const event = await ManagedEvent.findOne({ title: 'ISDR 2026' }).select('_id title').lean();
  if (!event) {
    console.error('ISDR 2026 event was not found.');
    process.exit(1);
  }

  const regs = await EventRegistration.find({ eventId: event._id })
    .select('name mobileNumber participantType participantTypeColor packageName idNumber')
    .lean();
  const byMobile = new Map();
  for (const reg of regs) {
    const mobile = last10(reg.mobileNumber);
    if (mobile) byMobile.set(mobile, reg);
  }

  const missing = [];
  const onUgPackage = [];
  const matched = [];
  for (const row of rows) {
    const reg = byMobile.get(last10(row.mobile));
    if (!reg) {
      missing.push(row);
      continue;
    }
    if (UG_PACKAGES.has(reg.packageName)) {
      onUgPackage.push({ ...row, idNumber: reg.idNumber, packageName: reg.packageName });
      continue;
    }
    matched.push(reg);
  }

  if (missing.length || onUgPackage.length) {
    if (missing.length) {
      console.error(`Missing ${missing.length} PG mobile(s):`);
      for (const row of missing) console.error(`- ${row.sheet} #${row.formId} ${row.name} ${row.mobile}`);
    }
    if (onUgPackage.length) {
      console.error(`Matched an undergraduate package (${onUgPackage.length}):`);
      for (const row of onUgPackage) console.error(`- ${row.sheet} ${row.name} ${row.idNumber} ${row.packageName}`);
    }
    console.error('No records were updated.');
    process.exit(1);
  }

  const ids = matched.map((reg) => reg._id);
  const result = await EventRegistration.updateMany(
    { _id: { $in: ids }, eventId: event._id },
    { $set: { participantType: PARTICIPANT_TYPE, participantTypeColor: TYPE_COLOR } }
  );

  const after = await EventRegistration.find({ _id: { $in: ids } })
    .select('participantType participantTypeColor')
    .lean();
  const wrong = after.filter(
    (reg) => reg.participantType !== PARTICIPANT_TYPE || reg.participantTypeColor !== TYPE_COLOR
  );

  console.log(`Matched: ${matched.length}`);
  console.log(`Updated: ${result.modifiedCount} (already correct: ${matched.length - result.modifiedCount})`);
  if (wrong.length) {
    console.error(`${wrong.length} row(s) are still not Delegate / ${TYPE_COLOR}.`);
    process.exit(1);
  }
  console.log(`Confirmed ${after.length} postgraduate registrations are ${PARTICIPANT_TYPE} ${TYPE_COLOR}.`);
  process.exit(0);
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
