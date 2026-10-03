/**
 * Adds the IADR office bearers to the ISDR 2026 event.
 *
 * Uses the free "Organising Committee" package (created with dummy entry/exit
 * dates if it is missing). The heading is the participant type. The role under
 * each name is stored in organization (institution). Designation stays empty
 * and every other field is dummy data. "Rev'd Prof" stays in the name because
 * the title field only allows Dr, Mr, Ms, and Prof. An email that is already
 * registered is updated in place.
 *
 * Usage: node scripts/seedIadrOfficeBearers.js
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
const PARTICIPANT_TYPE = 'IADR OFFICE BEARER';
const TYPE_COLOR = '#9E0A0F';
const DUMMY_DATES = ['2000-01-01', '2000-01-02', '2000-01-03'];

const BEARERS = [
  {
    title: 'Dr',
    firstName: 'Christopher',
    middleName: 'H.',
    lastName: 'Fox',
    organisation: 'CEO- IADR',
    email: 'iadrofficebearer01@example.com',
    mobileNumber: '9500000001',
  },
  {
    title: '',
    firstName: "Rev'd Prof Jennifer",
    middleName: 'E',
    lastName: 'Gallagher',
    organisation: 'PRESIDENT- IADR',
    email: 'iadrofficebearer02@example.com',
    mobileNumber: '9500000002',
  },
];

function displayName(person) {
  return [person.firstName, person.middleName, person.lastName].filter(Boolean).join(' ');
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

  const emails = BEARERS.map((person) => person.email);
  const existing = await EventRegistration.find({
    eventId: event._id,
    email: { $in: emails },
  });
  const byEmail = new Map(existing.map((reg) => [String(reg.email || '').toLowerCase(), reg]));

  for (const person of BEARERS) {
    const storedName = displayName(person);
    const reg = byEmail.get(person.email);
    if (reg) {
      reg.title = person.title;
      reg.firstName = person.firstName;
      reg.middleName = person.middleName;
      reg.lastName = person.lastName;
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
        title: person.title,
        firstName: person.firstName,
        middleName: person.middleName,
        lastName: person.lastName,
        gender: 'other',
        participantType: PARTICIPANT_TYPE,
        participantTypeColor: TYPE_COLOR,
        designation: '',
        institution: person.organisation,
        address: 'Dummy address',
        mobileNumber: person.mobileNumber,
        email: person.email,
        foodPreference: 'veg',
      },
    });
    console.log(`Created ${storedName} (${created.idNumber})`);
  }

  const saved = await EventRegistration.find({
    eventId: event._id,
    email: { $in: emails },
  })
    .select('name title designation institution participantType participantTypeColor packageName idNumber email address')
    .sort({ email: 1 })
    .lean();
  console.log(`\n${saved.length} IADR Office Bearer registration(s):`);
  for (const row of saved) {
    console.log(
      `- ${row.idNumber}  ${row.title ? row.title + ' ' : ''}${row.name}  |  ${row.participantType}  |  ${row.participantTypeColor}  |  ${row.packageName}  |  designation="${row.designation}"  |  organisation="${row.institution}"  |  ${row.email}`
    );
  }
  const wrong = saved.filter(
    (row) =>
      row.participantType !== PARTICIPANT_TYPE ||
      row.participantTypeColor !== TYPE_COLOR ||
      String(row.packageName || '').toLowerCase() !== PACKAGE_NAME.toLowerCase() ||
      row.designation
  );
  if (saved.length !== BEARERS.length || wrong.length) {
    throw new Error(`Expected ${BEARERS.length} IADR office bearers on ${PACKAGE_NAME}, found ${saved.length} (${wrong.length} wrong)`);
  }

  process.exit(0);
})().catch((err) => {
  console.error('Seed failed:', err.message || err);
  process.exit(1);
});
