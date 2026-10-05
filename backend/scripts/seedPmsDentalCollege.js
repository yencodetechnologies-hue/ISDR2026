/**
 * Adds PMS College of Dental Science and Research registrations to ISDR 2026.
 *
 * The Delegate sheet (33 people, including those whose original form amount
 * was 8500, 9500, or 10500) is "Other PG 7500", type Delegate, orange banner.
 * The 14 people who appear only on the Student Delegate sheet, all paid 6000,
 * are "Other UG 6000", type Student Delegate, green banner.
 * Names are stored in capitals. Designation is left blank. Organisation is an
 * ISDR26 number, continuing after the highest one already stored. A number
 * already on a person is kept. A mobile or email that is already registered
 * is updated in place. Re-running is safe.
 *
 * Usage: node scripts/seedPmsDentalCollege.js
 */
const path = require('path');
const { execFileSync } = require('child_process');
const dotenv = require('dotenv');
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const connectDB = require('../config/database');
const ManagedEvent = require('../models/ManagedEvent');
const EventRegistration = require('../models/EventRegistration');
const { createParticipantRegistration } = require('../controllers/managedEventController');

const WORKBOOK = 'c:\\Users\\Jeyaram\\Desktop\\PMS DENTAL COLLEGE.xlsx';
const ORG_ID = /^ISDR26-(\d+)$/i;
const STUDENT_PACKAGE = 'Other UG 6000';
const DELEGATE_PACKAGE = 'Other PG 7500';
const STUDENT_COLOR = '#167E5D';
const DELEGATE_COLOR = '#D46D1D';
const TITLES = { dr: 'Dr', mr: 'Mr', mrs: 'Mrs', ms: 'Ms', miss: 'Ms', prof: 'Prof' };

function last10(value) {
  const digits = String(value || '').replace(/\D/g, '');
  return digits.length > 10 ? digits.slice(-10) : digits;
}

function readWorkbook() {
  const py = `
import json, openpyxl
wb = openpyxl.load_workbook(${JSON.stringify(WORKBOOK)}, data_only=True, read_only=True)

def cell(v):
    if v is None:
        return ''
    if isinstance(v, float) and v.is_integer():
        return str(int(v))
    if isinstance(v, int):
        return str(v)
    return str(v).strip()

out = []
for name in wb.sheetnames:
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
            'formId': cell(rec.get('ID')),
            'title': cell(rec.get('Title')),
            'firstName': cell(rec.get('First Name')),
            'middleName': cell(rec.get('Middle Name')),
            'lastName': cell(rec.get('Last Name')),
            'gender': cell(rec.get('Gender')),
            'designation': cell(rec.get('Designation')),
            'address': cell(rec.get('Address')),
            'city': cell(rec.get('City')),
            'mobile': cell(rec.get('Mobile')),
            'email': cell(rec.get('Email')),
            'food': cell(rec.get('Food Preference')),
            'payment': cell(rec.get('Payment Mode')),
            'utr': cell(rec.get('UTR Number')),
            'amount': cell(rec.get('Total Amount')),
        })
wb.close()
print(json.dumps(out))
`;
  const raw = execFileSync('python', ['-c', py], { encoding: 'utf8', maxBuffer: 10 * 1024 * 1024 });
  return JSON.parse(raw);
}

function addressOf(row) {
  const address = row.address.trim();
  const city = row.city.trim();
  if (!city || address.toLowerCase().includes(city.toLowerCase())) return address;
  return [address, city].filter(Boolean).join(', ');
}

function paymentOf(value) {
  const raw = String(value || '').trim().toLowerCase();
  if (!raw) return '';
  if (raw === 'upi' || raw === 'bank transfer') return 'upi';
  throw new Error(`Unsupported payment mode "${value}"`);
}

function foodOf(value) {
  const raw = String(value || '').trim().toLowerCase().replace(/[\s-]+/g, '');
  if (raw === 'nonveg') return 'non-veg';
  if (raw === 'veg') return 'veg';
  throw new Error(`Unsupported food preference "${value}"`);
}

function utrOf(value) {
  const raw = String(value || '').trim();
  if (!raw || /inr/i.test(raw)) return '';
  return raw;
}

function classify(rows) {
  const delegates = rows.filter((row) => row.sheet === 'Delegate');
  const delegateIds = new Set(delegates.map((row) => row.formId));
  const students = rows.filter((row) => row.sheet === 'STUDENT DELEGATE' && !delegateIds.has(row.formId));
  if (delegates.length !== 33 || students.length !== 14) {
    throw new Error(`Expected 33 delegates and 14 student delegates, found ${delegates.length} and ${students.length}`);
  }
  const wrongAmount = students.filter((row) => !/6000/.test(row.amount));
  if (wrongAmount.length) {
    throw new Error(`${wrongAmount.length} student-only row(s) are not amount 6000`);
  }

  const people = [
    ...delegates.map((row) => toPerson(row, 'delegate')),
    ...students.map((row) => toPerson(row, 'student')),
  ];

  const seenMobile = new Map();
  const seenEmail = new Map();
  for (const person of people) {
    if (!/^\d{10}$/.test(person.mobileNumber)) {
      throw new Error(`Mobile is not 10 digits for ${person.firstName} ${person.lastName}: ${person.mobileNumber}`);
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(person.email)) {
      throw new Error(`Email is invalid for ${person.firstName} ${person.lastName}: ${person.email}`);
    }
    if (seenMobile.has(person.mobileNumber)) {
      throw new Error(`Duplicate mobile ${person.mobileNumber}`);
    }
    if (seenEmail.has(person.email)) {
      throw new Error(`Duplicate email ${person.email}`);
    }
    seenMobile.set(person.mobileNumber, person);
    seenEmail.set(person.email, person);
  }
  return people;
}

function toPerson(row, kind) {
  const student = kind === 'student';
  const title = TITLES[row.title.trim().toLowerCase().replace(/\.$/, '')];
  if (!title) throw new Error(`Unsupported title "${row.title}" for form ${row.formId}`);
  const gender = row.gender.trim().toLowerCase();
  if (!['male', 'female', 'other'].includes(gender)) {
    throw new Error(`Unsupported gender "${row.gender}" for form ${row.formId}`);
  }
  return {
    packageName: student ? STUDENT_PACKAGE : DELEGATE_PACKAGE,
    title,
    firstName: row.firstName.trim().toUpperCase(),
    middleName: row.middleName.trim().toUpperCase(),
    lastName: row.lastName.trim().toUpperCase(),
    gender,
    participantType: student ? 'Student Delegate' : 'Delegate',
    participantTypeColor: student ? STUDENT_COLOR : DELEGATE_COLOR,
    designation: '',
    institution: '',
    address: addressOf(row),
    mobileNumber: last10(row.mobile),
    email: row.email.trim().toLowerCase(),
    foodPreference: foodOf(row.food),
    paymentMode: paymentOf(row.payment),
    utrNumber: utrOf(row.utr),
  };
}

function storedName(person) {
  return [person.firstName, person.middleName, person.lastName].filter(Boolean).join(' ');
}

function orgLabel(n) {
  return `ISDR26-${n}`;
}

/** Highest ISDR26 organisation number already stored, and every number in use. */
async function loadOrgNumbers() {
  const rows = await EventRegistration.find({ institution: ORG_ID }).select('institution').lean();
  const used = new Set();
  let max = 0;
  for (const row of rows) {
    const n = Number((String(row.institution).match(ORG_ID) || [])[1]);
    if (!Number.isFinite(n)) continue;
    used.add(n);
    if (n > max) max = n;
  }
  return { used, max };
}

function takeNextOrg(state) {
  let n = state.max + 1;
  while (state.used.has(n)) n += 1;
  state.used.add(n);
  state.max = n;
  return orgLabel(n);
}

(async () => {
  const people = classify(readWorkbook());
  console.log(`Workbook people: ${people.length}`);

  await connectDB();

  const events = await ManagedEvent.find({ title: /isdr/i });
  const matches = events.filter((event) => /2026/.test(event.title));
  const exact = matches.filter((event) => event.title.trim().toLowerCase() === 'isdr 2026');
  const chosen = exact.length === 1 ? exact : matches;
  if (chosen.length !== 1) {
    const listed = (matches.length ? matches : events).map((event) => event.title).join(', ') || '(none)';
    throw new Error(`Expected one ISDR 2026 event, found ${matches.length}: ${listed}`);
  }
  const event = chosen[0];
  console.log(`Event: ${event.title} (${event._id})`);

  const packages = new Map();
  for (const name of [STUDENT_PACKAGE, DELEGATE_PACKAGE]) {
    const pkg = (event.packages || []).find((p) => p.name.toLowerCase() === name.toLowerCase());
    if (!pkg) throw new Error(`Package "${name}" was not found on this event`);
    packages.set(name, pkg);
    console.log(`Package "${pkg.name}" (${pkg.id})`);
  }

  const orgNumbers = await loadOrgNumbers();
  console.log(`Next organisation number: ${orgLabel(orgNumbers.max + 1)}`);

  for (const person of people) {
    const pkg = packages.get(person.packageName);
    const name = storedName(person);
    const byMobile = await EventRegistration.findOne({
      eventId: event._id,
      mobileNumber: person.mobileNumber,
    });
    const byEmail = await EventRegistration.findOne({
      eventId: event._id,
      email: person.email,
    });
    if (byMobile && byEmail && String(byMobile._id) !== String(byEmail._id)) {
      throw new Error(`Mobile and email match different registrations for ${name}`);
    }
    const existing = byMobile || byEmail;
    const kept = String(existing?.institution || '').match(ORG_ID);
    person.institution = kept ? orgLabel(Number(kept[1])) : takeNextOrg(orgNumbers);

    if (existing) {
      existing.title = person.title;
      existing.firstName = person.firstName;
      existing.middleName = person.middleName;
      existing.lastName = person.lastName;
      existing.name = name;
      existing.gender = person.gender;
      existing.participantType = person.participantType;
      existing.participantTypeColor = person.participantTypeColor;
      existing.designation = person.designation;
      existing.institution = person.institution;
      existing.address = person.address;
      existing.mobileNumber = person.mobileNumber;
      existing.email = person.email;
      existing.foodPreference = person.foodPreference;
      existing.paymentMode = person.paymentMode;
      existing.utrNumber = person.utrNumber;
      existing.packageId = pkg.id;
      existing.packageName = pkg.name;
      await existing.save();
      console.log(`Updated ${person.title} ${name} (${existing.idNumber})  ${person.institution}  ${person.participantType}  ${person.packageName}`);
      continue;
    }

    const created = await createParticipantRegistration(event, {
      packageId: pkg.id,
      source: 'bulk',
      profile: {
        title: person.title,
        firstName: person.firstName,
        middleName: person.middleName,
        lastName: person.lastName,
        gender: person.gender,
        participantType: person.participantType,
        participantTypeColor: person.participantTypeColor,
        designation: person.designation,
        institution: person.institution,
        address: person.address,
        mobileNumber: person.mobileNumber,
        email: person.email,
        foodPreference: person.foodPreference,
        paymentMode: person.paymentMode,
        utrNumber: person.utrNumber,
      },
    });
    console.log(`Created ${person.title} ${name} (${created.idNumber})  ${person.institution}  ${person.participantType}  ${person.packageName}`);
  }

  const saved = await EventRegistration.find({
    eventId: event._id,
    $or: people.map((person) => ({ email: person.email })),
  })
    .select('name title designation institution participantType participantTypeColor packageName idNumber email mobileNumber paymentMode utrNumber')
    .lean();

  const expected = new Map(people.map((person) => [person.email, person]));
  const wrong = [];
  for (const row of saved) {
    const person = expected.get(row.email);
    if (!person) {
      wrong.push(`${row.email} was not in the workbook`);
      continue;
    }
    if (
      row.participantType !== person.participantType ||
      row.participantTypeColor !== person.participantTypeColor ||
      row.packageName !== person.packageName ||
      row.mobileNumber !== person.mobileNumber ||
      row.institution !== person.institution
    ) {
      wrong.push(
        `${row.idNumber} ${row.email} is ${row.participantType} ${row.participantTypeColor} ${row.packageName} ${row.institution}`
      );
    }
  }

  const orgIds = saved.map((row) => row.institution);
  if (new Set(orgIds).size !== orgIds.length || orgIds.some((id) => !ORG_ID.test(id))) {
    throw new Error('Organisation IDs are missing or duplicated');
  }

  const students = saved.filter((row) => row.participantType === 'Student Delegate' && row.packageName === STUDENT_PACKAGE);
  const delegates = saved.filter((row) => row.participantType === 'Delegate' && row.packageName === DELEGATE_PACKAGE);

  console.log(`\n${saved.length} PMS registration(s): ${students.length} student delegates, ${delegates.length} delegates`);
  for (const row of saved) {
    console.log(
      `- ${row.idNumber}  ${row.title} ${row.name}  |  ${row.institution}  |  ${row.participantType}  |  ${row.participantTypeColor}  |  ${row.packageName}  |  ${row.mobileNumber}  |  ${row.email}`
    );
  }
  if (saved.length !== people.length || students.length !== 14 || delegates.length !== 33 || wrong.length) {
    if (wrong.length) console.error(wrong.join('\n'));
    throw new Error(`Expected 14 student delegates and 33 delegates, found ${students.length} and ${delegates.length}`);
  }

  process.exit(0);
})().catch((err) => {
  console.error('Seed failed:', err.message || err);
  process.exit(1);
});
