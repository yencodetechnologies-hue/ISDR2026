/**
 * Adds 25 Event Organizer registrations to the ISDR 2026 event.
 *
 * Uses the free "Event Organizer" package (created with dummy entry/exit
 * dates if it is missing). Each person is participant type "Event Organizer"
 * with the blue banner. A temporary name is required to create the row, then
 * the name is cleared so the badge, list, and QR payload have no name.
 * Email and mobile stay internal so this script can be re-run. An email that
 * is already registered is updated in place.
 *
 * Usage: node scripts/seedEventOrganizers.js
 */
const path = require('path');
const crypto = require('crypto');
const dotenv = require('dotenv');
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const connectDB = require('../config/database');
const ManagedEvent = require('../models/ManagedEvent');
const EventRegistration = require('../models/EventRegistration');
const { createParticipantRegistration } = require('../controllers/managedEventController');

const PACKAGE_NAME = 'Event Organizer';
const PARTICIPANT_TYPE = 'Event Organizer';
const TYPE_COLOR = '#1D4ED8';
const COUNT = 25;
const DUMMY_DATES = ['2000-01-01', '2000-01-02', '2000-01-03'];

function slot(n) {
  const nn = String(n).padStart(2, '0');
  return {
    email: `eventorganizer${nn}@example.com`,
    mobileNumber: `96100000${nn}`,
    // Temporary, only so the required name field can be saved. Cleared after.
    firstName: 'EVENT',
    middleName: 'ORGANIZER',
    lastName: nn,
    name: `EVENT ORGANIZER ${nn}`,
  };
}

/** Drops the printed name. updateOne skips the required-name check. */
async function clearPrintedName(reg, event) {
  const qrCode = JSON.stringify({
    type: 'event_ticket',
    registrationId: reg._id.toString(),
    eventId: event._id.toString(),
    idNumber: reg.idNumber,
    name: '',
    mobileNumber: reg.mobileNumber,
    otp: reg.otp,
  });
  await EventRegistration.updateOne(
    { _id: reg._id },
    {
      $set: {
        title: '',
        firstName: '',
        middleName: '',
        lastName: '',
        name: '',
        designation: '',
        institution: '',
        qrCode,
      },
    }
  );
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
    email: /^eventorganizer\d+@example\.com$/,
  });
  const byEmail = new Map(existing.map((reg) => [String(reg.email || '').toLowerCase(), reg]));

  for (let i = 1; i <= COUNT; i += 1) {
    const person = slot(i);
    const reg = byEmail.get(person.email);
    if (reg) {
      reg.title = '';
      reg.firstName = person.firstName;
      reg.middleName = person.middleName;
      reg.lastName = person.lastName;
      reg.name = person.name;
      reg.mobileNumber = person.mobileNumber;
      reg.email = person.email;
      reg.participantType = PARTICIPANT_TYPE;
      reg.participantTypeColor = TYPE_COLOR;
      reg.packageId = pkg.id;
      reg.packageName = pkg.name;
      reg.designation = '';
      reg.institution = '';
      await reg.save();
      await clearPrintedName(reg, event);
      console.log(`Updated ${reg.idNumber} (no name)`);
      continue;
    }

    const created = await createParticipantRegistration(event, {
      packageId: pkg.id,
      source: 'bulk',
      profile: {
        title: '',
        firstName: person.firstName,
        middleName: person.middleName,
        lastName: person.lastName,
        gender: '',
        participantType: PARTICIPANT_TYPE,
        participantTypeColor: TYPE_COLOR,
        designation: '',
        institution: '',
        address: '',
        mobileNumber: person.mobileNumber,
        email: person.email,
        foodPreference: '',
      },
    });
    await clearPrintedName(created, event);
    console.log(`Created ${created.idNumber} (no name)`);
  }

  const saved = await EventRegistration.find({
    eventId: event._id,
    participantType: PARTICIPANT_TYPE,
    email: /^eventorganizer\d+@example\.com$/,
  })
    .select('name participantType participantTypeColor packageName idNumber designation institution')
    .sort({ email: 1 })
    .lean();
  console.log(`\n${saved.length} Event Organizer registration(s) from this seed:`);
  for (const row of saved) {
    console.log(
      `- ${row.idNumber}  name="${row.name}"  |  ${row.participantType}  |  ${row.participantTypeColor}  |  ${row.packageName}`
    );
  }
  if (saved.length !== COUNT) {
    throw new Error(`Expected ${COUNT} Event Organizer registrations, found ${saved.length}`);
  }

  process.exit(0);
})().catch((err) => {
  console.error('Seed failed:', err.message || err);
  process.exit(1);
});
