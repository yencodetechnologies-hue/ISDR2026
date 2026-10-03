/**
 * Adds the ISDR office bearers to the ISDR 2026 event.
 *
 * Ensures a free "Organising Committee" package (dummy entry/exit dates), then
 * creates each bearer with participant type "ISDR Office Bearers". If someone
 * with the same name is already registered, only participant type, package, and
 * designation are updated.
 *
 * Usage: node scripts/seedIsdrOfficeBearers.js
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
const PARTICIPANT_TYPE = 'ISDR Office Bearers';
const TYPE_COLOR = '#9E0A0F';
const DUMMY_DATES = ['2000-01-01', '2000-01-02', '2000-01-03'];

const BEARERS = [
  {
    firstName: 'Ritu',
    middleName: '',
    lastName: 'Duggal',
    organisation: 'Chief & Professor, Department of Orthodontics, CDER, AIIMS, New Delhi',
  },
  {
    firstName: 'Mahesh',
    middleName: '',
    lastName: 'Verma',
    organisation: 'Vice Chancellor, Guru Gobind Singh, Indraprastha University, New Delhi',
  },
  {
    firstName: 'Vijay',
    middleName: '',
    lastName: 'Mathur',
    organisation: 'Professor & Head, Division of Pedodontics & Preventive Dentistry, CDER, AIIMS, New Delhi',
  },
  {
    firstName: 'Deepak',
    middleName: '',
    lastName: 'Chandra',
    organisation:
      'Professor & Head, Department of Orthodontics & Dentofacial Orthopedics, SRM Kattankulathur Dental College & Hospital, Chennai',
  },
  {
    firstName: 'Namita',
    middleName: '',
    lastName: 'Shanbhag',
    organisation: 'Associate Professor, Public Health Dentistry, Government Dental College & Research Institute, Bangalore',
  },
  {
    firstName: 'S.',
    middleName: 'M.',
    lastName: 'Balaji',
    organisation: 'Director, Cranio-Maxillofacial Surgeon, Balaji Dental & Craniofacial Hospital, Chennai',
  },
  {
    firstName: 'Preetha',
    middleName: '',
    lastName: 'Balaji',
    organisation: 'Department of Oral & Maxillofacial Surgery, Balaji Dental & Craniofacial Hospital, Chennai',
  },
  { firstName: 'Anil', middleName: '', lastName: 'Kohli', organisation: 'Former President, DCI, New Delhi' },
  {
    firstName: 'S.',
    middleName: 'Kishore',
    lastName: 'Kumar',
    organisation: 'Vice Principal, Sree Balaji Dental College & Hospital, Chennai',
  },
];

function displayName(person) {
  return [person.firstName, person.middleName, person.lastName].filter(Boolean).join(' ');
}

/** "Dr. S.M. Balaji" and "S. M. Balaji" compare as the same name. */
function nameKey(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/^(dr|mr|ms|prof)\.?\s+/, '')
    .replace(/[.\s]+/g, ' ')
    .trim();
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
  const byName = new Map();
  for (const reg of existing) {
    const key = nameKey(reg.name);
    if (!byName.has(key)) byName.set(key, reg);
  }

  for (let i = 0; i < BEARERS.length; i += 1) {
    const person = BEARERS[i];
    const fullName = displayName(person);
    const reg = byName.get(nameKey(fullName));
    if (reg) {
      reg.participantType = PARTICIPANT_TYPE;
      reg.participantTypeColor = TYPE_COLOR;
      reg.packageId = pkg.id;
      reg.packageName = pkg.name;
      reg.designation = '';
      reg.institution = person.organisation;
      await reg.save();
      console.log(`Updated ${fullName} (${reg.idNumber})`);
      continue;
    }

    const n = String(i + 1).padStart(2, '0');
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
        institution: person.organisation,
        address: 'Dummy address',
        mobileNumber: `90000000${n}`,
        email: `officebearer${n}@example.com`,
        foodPreference: 'veg',
      },
    });
    console.log(`Created ${fullName} (${created.idNumber})`);
  }

  const saved = await EventRegistration.find({
    eventId: event._id,
    participantType: PARTICIPANT_TYPE,
  })
    .select('name designation institution participantTypeColor packageName idNumber')
    .lean();
  console.log(`\n${saved.length} ISDR Office Bearer registration(s):`);
  for (const row of saved) {
    console.log(`- ${row.idNumber}  ${row.name}  |  ${row.institution}  |  ${row.participantTypeColor}  |  designation="${row.designation}"`);
  }

  process.exit(0);
})().catch((err) => {
  console.error('Seed failed:', err.message || err);
  process.exit(1);
});
