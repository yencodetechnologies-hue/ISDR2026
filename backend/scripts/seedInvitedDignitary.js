/**
 * Adds an invited dignitary to the ISDR 2026 event.
 *
 * Uses the free "Organising Committee" package (created with dummy entry/exit
 * dates if it is missing) and that package's banner colour. The heading is the
 * participant type. The rank is stored in the name because the title field only
 * allows Dr, Mr, Ms, and Prof. Designation and organisation stay empty and
 * every other field is dummy data. Re-running updates the same email in place.
 *
 * Usage: node scripts/seedInvitedDignitary.js
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
const PARTICIPANT_TYPE = 'INVITED DIGNITARY';
const TYPE_COLOR = '#9E0A0F';
const DUMMY_DATES = ['2000-01-01', '2000-01-02', '2000-01-03'];
const EMAIL = 'inviteddignitary01@example.com';

const PERSON = {
  firstName: 'Lt. Gen. (Retd.) Nanda',
  middleName: 'Kishore',
  lastName: 'Sahoo',
};

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

  const storedName = [PERSON.firstName, PERSON.middleName, PERSON.lastName].filter(Boolean).join(' ');
  const reg = await EventRegistration.findOne({ eventId: event._id, email: EMAIL });
  if (reg) {
    reg.title = '';
    reg.firstName = PERSON.firstName;
    reg.middleName = PERSON.middleName;
    reg.lastName = PERSON.lastName;
    reg.name = storedName;
    reg.participantType = PARTICIPANT_TYPE;
    reg.participantTypeColor = TYPE_COLOR;
    reg.packageId = pkg.id;
    reg.packageName = pkg.name;
    reg.designation = '';
    reg.institution = '';
    await reg.save();
    console.log(`Updated ${storedName} (${reg.idNumber})`);
  } else {
    const created = await createParticipantRegistration(event, {
      packageId: pkg.id,
      source: 'bulk',
      profile: {
        title: '',
        firstName: PERSON.firstName,
        middleName: PERSON.middleName,
        lastName: PERSON.lastName,
        gender: 'other',
        participantType: PARTICIPANT_TYPE,
        participantTypeColor: TYPE_COLOR,
        designation: '',
        institution: '',
        address: 'Dummy address',
        mobileNumber: '9600000001',
        email: EMAIL,
        foodPreference: 'veg',
      },
    });
    console.log(`Created ${storedName} (${created.idNumber})`);
  }

  const saved = await EventRegistration.findOne({ eventId: event._id, email: EMAIL })
    .select('name title designation institution participantType participantTypeColor packageName idNumber')
    .lean();
  if (!saved) throw new Error('Invited dignitary registration was not saved');
  console.log(`\nInvited dignitary:`);
  console.log(
    `- ${saved.idNumber}  ${saved.name}  |  ${saved.participantType}  |  ${saved.participantTypeColor}  |  ${saved.packageName}  |  designation="${saved.designation}"  |  organisation="${saved.institution}"`
  );

  process.exit(0);
})().catch((err) => {
  console.error('Seed failed:', err.message || err);
  process.exit(1);
});
