/**
 * Sets Executive Council members on the ISDR 2026 event.
 *
 * Uses the free "Organising Committee" package and the Organising Committee
 * banner colour. People who already have a real registration on that package
 * keep their name, email, mobile, and organisation; only participant type and
 * banner colour change. Dr. S. Bhuminathan's designation becomes
 * "Organising Secretary". Anyone not already registered is created with dummy
 * contact data. Dummy invited-speaker rows are not touched. Re-running does
 * not insert a second copy of the same email.
 *
 * Usage: node scripts/seedExecutiveCouncil.js
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
const PARTICIPANT_TYPE = 'Executive Council Members';
const TYPE_COLOR = '#D46D1D';
const DUMMY_DATES = ['2000-01-01', '2000-01-02', '2000-01-03'];

function hasWord(name, word) {
  return new RegExp(`\\b${word}\\b`, 'i').test(name);
}

/** Existing real registrations on the Organising Committee package. */
const EXISTING = [
  { label: 'Dr. S. Bhuminathan', test: (name) => hasWord(name, 'bhuminathan'), designation: 'Organising Secretary' },
  { label: 'Dr. S. Mahalaxmi', test: (name) => hasWord(name, 'mahalakshmi') || hasWord(name, 'mahalaxmi') },
  { label: 'Dr. Deenadayalan .P', test: (name) => hasWord(name, 'deenadayalan') },
  { label: 'Dr. N. Gopi Chander', test: (name) => hasWord(name, 'gopi') && hasWord(name, 'chander') },
  { label: 'Dr. Harsh Priya', test: (name) => hasWord(name, 'harsh') && hasWord(name, 'priya') },
  { label: 'Dr. Jaideep Mahendra', test: (name) => hasWord(name, 'jaideep') },
  { label: 'Dr. Puneet Batra', test: (name) => hasWord(name, 'puneet') },
  {
    label: 'Dr. D. Gopalakrishnan',
    test: (name) => hasWord(name, 'gopalakrishnan') || (hasWord(name, 'gopal') && hasWord(name, 'krishnan')),
  },
  { label: 'Dr. Nitika Monga', test: (name) => hasWord(name, 'nitika') },
];

/** Not registered yet. Contact fields are dummy data. Mobiles skip numbers already used by other seeds. */
const CREATE = [
  { firstName: 'P.', middleName: 'S.', lastName: 'Thaha', mobileNumber: '9700000017' },
  { firstName: 'Jacob', middleName: '', lastName: 'Raja', mobileNumber: '9700000018' },
  { firstName: 'Shantanu', middleName: '', lastName: 'Choudhari', mobileNumber: '9700000019' },
];

function onPackage(reg, pkg) {
  return (
    String(reg.packageId || '') === String(pkg.id) ||
    String(reg.packageName || '').toLowerCase() === PACKAGE_NAME.toLowerCase()
  );
}

function isDummyEmail(email) {
  return /@example\.com$/i.test(String(email || ''));
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

  const existing = await EventRegistration.find({ eventId: event._id });
  const realOnPackage = existing.filter((reg) => onPackage(reg, pkg) && !isDummyEmail(reg.email));

  for (const person of EXISTING) {
    const found = realOnPackage.filter((reg) => person.test(String(reg.name || '')));
    if (found.length !== 1) {
      const listed = found.map((reg) => `${reg.idNumber} ${reg.name}`).join(', ') || '(none)';
      throw new Error(`Expected one real registration for ${person.label}, found ${found.length}: ${listed}`);
    }
    const reg = found[0];
    reg.participantType = PARTICIPANT_TYPE;
    reg.participantTypeColor = TYPE_COLOR;
    if (person.designation) reg.designation = person.designation;
    await reg.save();
    console.log(`Updated ${person.label} → ${reg.idNumber} ${reg.name}`);
  }

  for (let i = 0; i < CREATE.length; i += 1) {
    const person = CREATE[i];
    const n = String(i + 1).padStart(2, '0');
    const email = `executivecouncil${n}@example.com`;
    const fullName = [person.firstName, person.middleName, person.lastName].filter(Boolean).join(' ');
    const already = existing.find((reg) => String(reg.email || '').toLowerCase() === email);
    if (already) {
      already.participantType = PARTICIPANT_TYPE;
      already.participantTypeColor = TYPE_COLOR;
      await already.save();
      console.log(`Updated ${fullName} (${already.idNumber}, ${email} already registered)`);
      continue;
    }
    const created = await createParticipantRegistration(event, {
      packageId: pkg.id,
      source: 'bulk',
      profile: {
        title: 'Dr',
        firstName: person.firstName,
        middleName: person.middleName,
        lastName: person.lastName,
        gender: 'other',
        participantType: PARTICIPANT_TYPE,
        participantTypeColor: TYPE_COLOR,
        designation: '',
        institution: '',
        address: 'Dummy address',
        mobileNumber: person.mobileNumber,
        email,
        foodPreference: 'veg',
      },
    });
    console.log(`Created ${fullName} (${created.idNumber})`);
  }

  const saved = await EventRegistration.find({
    eventId: event._id,
    participantType: PARTICIPANT_TYPE,
  })
    .select('name designation institution participantType participantTypeColor packageName idNumber email')
    .sort({ idNumber: 1 })
    .lean();
  console.log(`\n${saved.length} Executive Council Member registration(s):`);
  for (const row of saved) {
    console.log(
      `- ${row.idNumber}  ${row.name}  |  ${row.participantTypeColor}  |  ${row.packageName}  |  designation="${row.designation}"  |  ${row.email}`
    );
  }
  const wrong = saved.filter((row) => row.participantTypeColor !== TYPE_COLOR);
  if (saved.length !== EXISTING.length + CREATE.length || wrong.length) {
    throw new Error(`Expected ${EXISTING.length + CREATE.length} rows on ${TYPE_COLOR}, found ${saved.length} (${wrong.length} wrong colour)`);
  }

  process.exit(0);
})().catch((err) => {
  console.error('Seed failed:', err.message || err);
  process.exit(1);
});
