/**
 * Adds Organising Committee members to the ISDR 2026 event.
 *
 * Uses the free "Organising Committee" package (created with dummy entry/exit
 * dates if it is missing). Each person is a registration with participant type
 * "Organising Committee". Names are stored in uppercase. The role after the name
 * is stored in organization (institution). Designation stays empty and every
 * other field is dummy data.
 * An email that is already registered is updated in place.
 *
 * Usage: node scripts/seedOrganisingCommittee.js
 */
const path = require('path');
const crypto = require('crypto');
const dotenv = require('dotenv');
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const connectDB = require('../config/database');
const ManagedEvent = require('../models/ManagedEvent');
const EventRegistration = require('../models/EventRegistration');
const { createParticipantRegistration } = require('../controllers/managedEventController');

const PACKAGE_NAME = 'Organising Committee';
const PARTICIPANT_TYPE = 'Organising Committee';
const TYPE_COLOR = '#9E0A0F';
const DUMMY_DATES = ['2000-01-01', '2000-01-02', '2000-01-03'];
/** Executive council seed already uses these dummy mobiles. */
const RESERVED_MOBILES = new Set(['9700000017', '9700000018', '9700000019']);

const MEMBERS = [
  { name: 'MS. KANNAN', organisation: 'Organising Co-Chairman' },
  { name: 'K. GNANA SHANMUGHAM', organisation: 'Chairman, Scientific Committee' },
  { name: 'RAGAVENDRA JAYESH', organisation: 'Conference Advisor' },
  { name: 'PONNUDURAI ARANGANNAL', organisation: 'Conference Advisor' },
  { name: 'BADRI THIRUVENKATACHARI', organisation: 'Co-Chairman, Scientific Committee' },
  { name: 'N. ARAVINDHA BABU', organisation: 'Treasurer' },
  { name: 'A. VENKATESH', organisation: 'Convener, Registration Committee' },
  { name: 'NALINI ASWATH', organisation: 'Convener, Pre Conference Course Committee' },
  { name: 'M. N PRABHU', organisation: 'Convener, International Relations' },
  { name: 'VIJAY EBENEZER', organisation: 'Convener, Banquet and Cultural Night' },
  { name: 'ANITHA BALAJI', organisation: 'Convener, Reception Committee' },
  { name: 'M. ANITA', organisation: 'Convener, Souvenir Committee' },
  { name: 'T. MANIKANDAN', organisation: 'Convener, Trade' },
  { name: 'SREE DEVI V', organisation: 'Convener, Hospitality Committee' },
  { name: 'GOLD PEARLIN MARY. N', organisation: 'Co-Convener, Student Conference' },
  { name: 'N. GEETHA PRIYA', organisation: 'Convener, Awards Committee' },
  { name: 'S. M. BALAJI', organisation: 'Conference Executive Advisor' },
  { name: 'MAHESH VERMA', organisation: 'Conference Secretary' },
];

/** Dummy mobile for member n, skipping numbers already used by other seeds. */
function dummyMobile(n, taken) {
  let num = Number(n);
  let mobile = `97000000${String(num).padStart(2, '0')}`;
  while (taken.has(mobile)) {
    num += 1;
    mobile = `97000000${String(num).padStart(2, '0')}`;
  }
  taken.add(mobile);
  return mobile;
}

/** Last word is the surname, including a one-letter initial. A single word stays as the first name. */
function splitName(fullName) {
  const parts = String(fullName || '')
    .trim()
    .toUpperCase()
    .split(/\s+/)
    .filter(Boolean);
  if (parts.length <= 1) {
    return { firstName: parts[0] || '', middleName: '', lastName: '' };
  }
  return {
    firstName: parts[0],
    middleName: parts.slice(1, -1).join(' '),
    lastName: parts[parts.length - 1],
  };
}

(async () => {
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

  let pkg = (event.packages || []).find((p) => p.name.toLowerCase() === PACKAGE_NAME.toLowerCase());
  if (!pkg) {
    pkg = {
      id: crypto.randomBytes(6).toString('hex'),
      name: PACKAGE_NAME,
      rate: 0,
      paymentMode: '',
      entryExitDates: DUMMY_DATES,
      inclusions: [],
    };
    event.packages.push(pkg);
    await event.save();
    console.log(`Added package "${PACKAGE_NAME}" (${pkg.id})`);
  } else {
    console.log(`Package "${PACKAGE_NAME}" already exists (${pkg.id})`);
  }

  const existing = await EventRegistration.find({
    eventId: event._id,
    email: /^organisingcommittee\d+@example\.com$/,
  });
  const byEmail = new Map(existing.map((reg) => [String(reg.email || '').toLowerCase(), reg]));

  const takenMobiles = new Set(RESERVED_MOBILES);
  for (let i = 0; i < MEMBERS.length; i += 1) {
    const person = MEMBERS[i];
    const n = String(i + 1).padStart(2, '0');
    const email = `organisingcommittee${n}@example.com`;
    const mobileNumber = dummyMobile(n, takenMobiles);
    const parts = splitName(person.name);
    const storedName = [parts.firstName, parts.middleName, parts.lastName].filter(Boolean).join(' ');
    const reg = byEmail.get(email);
    if (reg) {
      reg.title = 'Dr';
      reg.firstName = parts.firstName;
      reg.middleName = parts.middleName;
      reg.lastName = parts.lastName;
      reg.name = storedName;
      reg.participantType = PARTICIPANT_TYPE;
      reg.participantTypeColor = TYPE_COLOR;
      reg.packageId = pkg.id;
      reg.packageName = pkg.name;
      reg.designation = '';
      reg.institution = person.organisation;
      await reg.save();
      console.log(`Updated ${storedName} (${reg.idNumber})`);
      continue;
    }

    const created = await createParticipantRegistration(event, {
      packageId: pkg.id,
      source: 'bulk',
      profile: {
        title: 'Dr',
        firstName: parts.firstName,
        middleName: parts.middleName,
        lastName: parts.lastName,
        gender: 'other',
        participantType: PARTICIPANT_TYPE,
        participantTypeColor: TYPE_COLOR,
        designation: '',
        institution: person.organisation,
        address: 'Dummy address',
        mobileNumber,
        email,
        foodPreference: 'veg',
      },
    });
    console.log(`Created ${storedName} (${created.idNumber})`);
  }

  const saved = await EventRegistration.find({
    eventId: event._id,
    participantType: PARTICIPANT_TYPE,
    email: /^organisingcommittee\d+@example\.com$/,
  })
    .select('name title designation institution participantType participantTypeColor packageName idNumber')
    .sort({ email: 1 })
    .lean();
  console.log(`\n${saved.length} Organising Committee registration(s) from this seed:`);
  for (const row of saved) {
    console.log(
      `- ${row.idNumber}  ${row.title} ${row.name}  |  ${row.participantType}  |  ${row.participantTypeColor}  |  ${row.packageName}  |  designation="${row.designation}"  |  organisation="${row.institution}"`
    );
  }

  process.exit(0);
})().catch((err) => {
  console.error('Seed failed:', err.message || err);
  process.exit(1);
});
