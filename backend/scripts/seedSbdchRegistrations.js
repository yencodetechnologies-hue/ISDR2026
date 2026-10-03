/**
 * Adds three SBDCH registrations to the ISDR 2026 event.
 *
 * Two Delegates use "SBDCH Delegates 7500" and the orange banner.
 * One Student Delegate uses "SBDCH UG 3500" and the green banner.
 * Names are stored in capitals. A mobile or email that is already
 * registered is updated in place. Re-running is safe.
 *
 * Usage: node scripts/seedSbdchRegistrations.js
 */
const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const connectDB = require('../config/database');
const ManagedEvent = require('../models/ManagedEvent');
const EventRegistration = require('../models/EventRegistration');
const { createParticipantRegistration } = require('../controllers/managedEventController');

const DELEGATE_COLOR = '#D46D1D';
const STUDENT_COLOR = '#167E5D';
const INSTITUTION = 'Sree Balaji Dental College and Hospital';

const PEOPLE = [
  {
    packageName: 'SBDCH Delegates 7500',
    title: 'Dr',
    firstName: 'MATHANGI',
    middleName: '',
    lastName: 'R',
    gender: 'female',
    participantType: 'Delegate',
    participantTypeColor: DELEGATE_COLOR,
    designation: 'Professor',
    institution: INSTITUTION,
    address: '9B/B3, 1st cross st. Sarvamanagala Nagar, Chitlapakkam',
    mobileNumber: '9884296337',
    email: 'mathangi.pbc@sbdch.bharathuniv.ac.in',
    foodPreference: 'veg',
    paymentMode: 'upi',
    utrNumber: '627401338705',
  },
  {
    packageName: 'SBDCH Delegates 7500',
    title: 'Mrs',
    firstName: 'JAYASRIKRUPAA',
    middleName: '',
    lastName: 'RAVI',
    gender: 'female',
    participantType: 'Delegate',
    participantTypeColor: DELEGATE_COLOR,
    designation: 'Professor',
    institution: INSTITUTION,
    address: 'Sree Balaji Dental College, Narayanapuram, Pallikaranai, Chennai',
    mobileNumber: '9840286523',
    email: 'jayasri.krupaa@gmail.com',
    foodPreference: 'veg',
    paymentMode: 'upi',
    utrNumber: '627490955069',
  },
  {
    packageName: 'SBDCH UG 3500',
    title: 'Ms',
    firstName: 'VEENUSRI',
    middleName: '',
    lastName: 'K. V',
    gender: 'female',
    participantType: 'Student Delegate',
    participantTypeColor: STUDENT_COLOR,
    designation: 'Bds ug',
    institution: INSTITUTION,
    address: 'Pallikaranai, Chennai 600100',
    mobileNumber: '9003371675',
    email: 'sriveenu079@gmail.com',
    foodPreference: 'non-veg',
    paymentMode: 'upi',
    utrNumber: '661806225991',
  },
];

function storedName(person) {
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

  const packages = new Map();
  for (const name of [...new Set(PEOPLE.map((person) => person.packageName))]) {
    const pkg = (event.packages || []).find((p) => p.name.toLowerCase() === name.toLowerCase());
    if (!pkg) throw new Error(`Package "${name}" was not found on this event`);
    packages.set(name, pkg);
    console.log(`Package "${pkg.name}" (${pkg.id})`);
  }

  for (const person of PEOPLE) {
    const pkg = packages.get(person.packageName);
    const name = storedName(person);
    const existing = await EventRegistration.findOne({
      eventId: event._id,
      $or: [{ mobileNumber: person.mobileNumber }, { email: person.email }],
    });

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
      console.log(`Updated ${person.title} ${name} (${existing.idNumber})`);
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
    console.log(`Created ${person.title} ${name} (${created.idNumber})`);
  }

  const saved = await EventRegistration.find({
    eventId: event._id,
    $or: PEOPLE.map((person) => ({ email: person.email })),
  })
    .select('name title designation institution participantType participantTypeColor packageName idNumber email mobileNumber')
    .lean();

  console.log(`\n${saved.length} SBDCH registration(s):`);
  for (const row of saved) {
    console.log(
      `- ${row.idNumber}  ${row.title} ${row.name}  |  ${row.participantType}  |  ${row.participantTypeColor}  |  ${row.packageName}  |  ${row.mobileNumber}  |  ${row.email}`
    );
  }
  if (saved.length !== PEOPLE.length) {
    throw new Error(`Expected ${PEOPLE.length} registrations, found ${saved.length}`);
  }

  process.exit(0);
})().catch((err) => {
  console.error('Seed failed:', err.message || err);
  process.exit(1);
});
