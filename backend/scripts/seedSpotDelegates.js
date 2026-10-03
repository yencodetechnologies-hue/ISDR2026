/**
 * Adds 15 spot registrations to the Spot register package.
 *
 * These cards have no participant type and no name. The banner is orange
 * and the pass is the QR. A temporary name is required to create the row,
 * then it is cleared.
 * Email and mobile stay internal so
 * this script can be re-run. An email that is already registered is updated
 * in place.
 *
 * Usage: node scripts/seedSpotDelegates.js
 */
const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const connectDB = require('../config/database');
const ManagedEvent = require('../models/ManagedEvent');
const EventRegistration = require('../models/EventRegistration');
const { createParticipantRegistration } = require('../controllers/managedEventController');

const PACKAGE_NAME = 'Spot register';
const TYPE_COLOR = '#D46D1D';
const COUNT = 15;

function slot(n) {
  const nn = String(n).padStart(2, '0');
  return {
    email: `spotdelegate${nn}@example.com`,
    mobileNumber: `96400000${nn}`,
    firstName: 'SPOT',
    lastName: nn,
    name: `SPOT ${nn}`,
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
        participantType: '',
        participantTypeColor: TYPE_COLOR,
        source: 'spot',
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

  const pkg = (event.packages || []).find((p) => p.name.toLowerCase() === PACKAGE_NAME.toLowerCase());
  if (!pkg) throw new Error(`Package "${PACKAGE_NAME}" was not found on this event`);
  console.log(`Package "${pkg.name}" (${pkg.id})`);

  const existing = await EventRegistration.find({
    eventId: event._id,
    email: /^spotdelegate\d+@example\.com$/,
  });
  const byEmail = new Map(existing.map((reg) => [String(reg.email || '').toLowerCase(), reg]));

  for (let i = 1; i <= COUNT; i += 1) {
    const person = slot(i);
    const reg = byEmail.get(person.email);
    if (reg) {
      reg.title = '';
      reg.firstName = person.firstName;
      reg.middleName = '';
      reg.lastName = person.lastName;
      reg.name = person.name;
      reg.mobileNumber = person.mobileNumber;
      reg.email = person.email;
      reg.participantType = '';
      reg.participantTypeColor = TYPE_COLOR;
      reg.packageId = pkg.id;
      reg.packageName = pkg.name;
      reg.idNumber = `SP${String(i).padStart(4, '0')}`;
      reg.designation = '';
      reg.institution = '';
      reg.source = 'spot';
      await reg.save();
      await clearPrintedName(reg, event);
      console.log(`Updated ${reg.idNumber} (no name)`);
      continue;
    }

    const created = await createParticipantRegistration(event, {
      packageId: pkg.id,
      source: 'spot',
      profile: {
        title: '',
        firstName: person.firstName,
        middleName: '',
        lastName: person.lastName,
        gender: '',
        participantType: '',
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
    email: /^spotdelegate\d+@example\.com$/,
  })
    .select('name participantType participantTypeColor packageName idNumber source')
    .sort({ email: 1 })
    .lean();
  console.log(`\n${saved.length} Spot register registration(s):`);
  for (const row of saved) {
    console.log(
      `- ${row.idNumber}  name="${row.name}"  |  ${row.participantType}  |  ${row.participantTypeColor}  |  ${row.packageName}  |  ${row.source}`
    );
  }
  if (saved.length !== COUNT) {
    throw new Error(`Expected ${COUNT} Spot register registrations, found ${saved.length}`);
  }

  process.exit(0);
})().catch((err) => {
  console.error('Seed failed:', err.message || err);
  process.exit(1);
});
