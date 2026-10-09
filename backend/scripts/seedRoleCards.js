/**
 * Adds dummy role cards to the ISDR 2026 event.
 *
 * Named passes print the person. Blank passes keep a database name
 * (DELEGATE plus the ID) so entry and exit scans can save the row, while the
 * QR payload name, designation, and organisation stay empty. Banner colours
 * match the existing set: maroon for Patron, Special Invitee, and Organising
 * Committee; blue for Administrative Officer; orange for Delegate.
 * An email that is already registered is updated in place.
 *
 * Usage: node scripts/seedRoleCards.js
 */
const path = require('path');
const crypto = require('crypto');
const dotenv = require('dotenv');
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const connectDB = require('../config/database');
const ManagedEvent = require('../models/ManagedEvent');
const EventRegistration = require('../models/EventRegistration');
const { createParticipantRegistration } = require('../controllers/managedEventController');

const MAROON = '#9E0A0F';
const BLUE = '#1D4ED8';
const ORANGE = '#D46D1D';
const DUMMY_DATES = ['2000-01-01', '2000-01-02', '2000-01-03'];
const DUMMY_ADDRESS = 'Dummy address';
const DUMMY_ORG = 'Dummy organisation';

const NAMED = [
  {
    email: 'patron01@example.com',
    mobileNumber: '9650000001',
    packageName: 'Patron',
    participantType: 'Patron',
    participantTypeColor: MAROON,
    title: '',
    firstName: 'ER. N.',
    middleName: '',
    lastName: 'ELAMARAN',
    designation: 'Managing Director',
    institution: 'Sree Balaji Group of Institutions',
  },
  {
    email: 'administrativeofficer01@example.com',
    mobileNumber: '9660000001',
    packageName: 'Administrative Officer',
    participantType: 'Administrative Officer',
    participantTypeColor: BLUE,
    title: 'Mr',
    firstName: 'DEVANATHAN',
    middleName: '',
    lastName: '',
    designation: 'Administrative Officer',
    institution: DUMMY_ORG,
  },
  {
    email: 'specialinvitee01@example.com',
    mobileNumber: '9670000001',
    packageName: 'Special Invitee',
    participantType: 'Special Invitee',
    participantTypeColor: MAROON,
    title: 'Dr',
    firstName: 'DEEPAK',
    middleName: '',
    lastName: 'NALLASWAMY',
    designation: '',
    institution: DUMMY_ORG,
  },
  {
    email: 'roledelegate01@example.com',
    mobileNumber: '9680000001',
    packageName: 'Delegate',
    participantType: 'Delegate',
    participantTypeColor: ORANGE,
    title: 'Dr',
    firstName: 'ARAVIND',
    middleName: 'KUMAR',
    lastName: 'S',
    designation: '',
    institution: DUMMY_ORG,
    freePackageOnly: true,
  },
  {
    email: 'organisingcommittee20@example.com',
    mobileNumber: '9690000001',
    packageName: 'Organising Committee',
    participantType: 'Organising Committee',
    participantTypeColor: MAROON,
    title: 'Dr',
    firstName: 'SONA',
    middleName: '',
    lastName: '',
    designation: '',
    institution: '',
  },
  {
    email: 'organisingcommittee21@example.com',
    mobileNumber: '9690000002',
    packageName: 'Organising Committee',
    participantType: 'Organising Committee',
    participantTypeColor: MAROON,
    title: 'Dr',
    firstName: 'KAVITHA',
    middleName: '',
    lastName: '',
    designation: '',
    institution: '',
  },
];

function blankCard(n, spec) {
  const nn = String(n).padStart(2, '0');
  return {
    email: `${spec.emailPrefix}${nn}@example.com`,
    mobileNumber: `${spec.mobilePrefix}${nn}`,
    packageName: spec.packageName,
    participantType: spec.participantType,
    participantTypeColor: spec.participantTypeColor,
    freePackageOnly: !!spec.freePackageOnly,
    firstName: spec.participantType.toUpperCase(),
    lastName: nn,
  };
}

const BLANKS = [
  ...Array.from({ length: 8 }, (_, i) =>
    blankCard(i + 2, {
      emailPrefix: 'specialinvitee',
      mobilePrefix: '96700000',
      packageName: 'Special Invitee',
      participantType: 'Special Invitee',
      participantTypeColor: MAROON,
    })
  ),
  ...Array.from({ length: 5 }, (_, i) =>
    blankCard(i + 2, {
      emailPrefix: 'roledelegate',
      mobilePrefix: '96800000',
      packageName: 'Delegate',
      participantType: 'Delegate',
      participantTypeColor: ORANGE,
      freePackageOnly: true,
    })
  ),
];

function storedName(person) {
  return [person.firstName, person.middleName, person.lastName].filter(Boolean).join(' ');
}

function qrPayload(reg, event, name) {
  return JSON.stringify({
    type: 'event_ticket',
    registrationId: reg._id.toString(),
    eventId: event._id.toString(),
    idNumber: reg.idNumber,
    name,
    mobileNumber: reg.mobileNumber,
    otp: reg.otp,
  });
}

/** The card name is "DELEGATE <id>". First, middle, and last name stay empty. */
async function clearPrintedName(reg, event) {
  const name = `DELEGATE ${reg.idNumber}`;
  await EventRegistration.updateOne(
    { _id: reg._id },
    {
      $set: {
        title: '',
        firstName: '',
        middleName: '',
        lastName: '',
        name,
        designation: '',
        institution: '',
        qrCode: qrPayload(reg, event, name),
      },
    }
  );
}

async function ensurePackage(event, packageName, { freeOnly = false } = {}) {
  let pkg = (event.packages || []).find((p) => p.name.toLowerCase() === packageName.toLowerCase());
  if (pkg) {
    if (freeOnly && Number(pkg.rate) > 0) {
      throw new Error(
        `Package "${pkg.name}" is paid (rate ${pkg.rate}); dummy cards are not attached to a paid package`
      );
    }
    console.log(`Package "${pkg.name}" already exists (${pkg.id})`);
    return pkg;
  }
  pkg = {
    id: crypto.randomBytes(6).toString('hex'),
    name: packageName,
    rate: 0,
    paymentMode: '',
    entryExitDates: DUMMY_DATES,
    inclusions: [],
  };
  event.packages.push(pkg);
  await event.save();
  console.log(`Added package "${packageName}" (${pkg.id})`);
  return pkg;
}

function profileOf(person, pkg) {
  return {
    title: person.title || '',
    firstName: person.firstName,
    middleName: person.middleName || '',
    lastName: person.lastName || '',
    gender: 'other',
    participantType: person.participantType,
    participantTypeColor: person.participantTypeColor,
    designation: person.designation || '',
    institution: person.institution || '',
    address: DUMMY_ADDRESS,
    mobileNumber: person.mobileNumber,
    email: person.email,
    foodPreference: 'veg',
    packageId: pkg.id,
    packageName: pkg.name,
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

  const packages = new Map();
  for (const person of [...NAMED, ...BLANKS]) {
    if (packages.has(person.packageName)) continue;
    packages.set(
      person.packageName,
      await ensurePackage(event, person.packageName, { freeOnly: !!person.freePackageOnly })
    );
  }

  const emails = [...NAMED, ...BLANKS].map((person) => person.email);
  const existing = await EventRegistration.find({
    eventId: event._id,
    email: { $in: emails },
  });
  const byEmail = new Map(existing.map((reg) => [String(reg.email || '').toLowerCase(), reg]));

  for (const person of NAMED) {
    const pkg = packages.get(person.packageName);
    const name = storedName(person);
    const reg = byEmail.get(person.email);
    if (reg) {
      Object.assign(reg, profileOf(person, pkg));
      reg.name = name;
      reg.qrCode = qrPayload(reg, event, name);
      await reg.save();
      console.log(`Updated ${person.title ? person.title + ' ' : ''}${name} (${reg.idNumber})`);
      continue;
    }
    const created = await createParticipantRegistration(event, {
      packageId: pkg.id,
      source: 'bulk',
      profile: profileOf(person, pkg),
    });
    console.log(`Created ${person.title ? person.title + ' ' : ''}${name} (${created.idNumber})`);
  }

  for (const person of BLANKS) {
    const pkg = packages.get(person.packageName);
    const reg = byEmail.get(person.email);
    if (reg) {
      reg.title = '';
      reg.firstName = person.firstName;
      reg.middleName = '';
      reg.lastName = person.lastName;
      reg.name = storedName(person);
      reg.gender = 'other';
      reg.participantType = person.participantType;
      reg.participantTypeColor = person.participantTypeColor;
      reg.packageId = pkg.id;
      reg.packageName = pkg.name;
      reg.designation = '';
      reg.institution = '';
      reg.address = DUMMY_ADDRESS;
      reg.mobileNumber = person.mobileNumber;
      reg.email = person.email;
      reg.foodPreference = 'veg';
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
        middleName: '',
        lastName: person.lastName,
        gender: 'other',
        participantType: person.participantType,
        participantTypeColor: person.participantTypeColor,
        designation: '',
        institution: '',
        address: DUMMY_ADDRESS,
        mobileNumber: person.mobileNumber,
        email: person.email,
        foodPreference: 'veg',
      },
    });
    await clearPrintedName(created, event);
    console.log(`Created ${created.idNumber} (no name)`);
  }

  const saved = await EventRegistration.find({
    eventId: event._id,
    email: { $in: emails },
  })
    .select(
      'name title firstName middleName lastName designation institution participantType participantTypeColor packageName idNumber email qrCode'
    )
    .lean();
  const bySavedEmail = new Map(saved.map((row) => [String(row.email || '').toLowerCase(), row]));

  console.log('\nNamed cards:');
  for (const person of NAMED) {
    const row = bySavedEmail.get(person.email);
    if (!row) throw new Error(`Missing ${person.email}`);
    const qrName = JSON.parse(row.qrCode || '{}').name;
    const expectedName = storedName(person);
    if (
      row.name !== expectedName ||
      (row.title || '') !== (person.title || '') ||
      (row.designation || '') !== (person.designation || '') ||
      (row.institution || '') !== (person.institution || '') ||
      row.participantType !== person.participantType ||
      row.participantTypeColor !== person.participantTypeColor ||
      String(row.packageName || '').toLowerCase() !== person.packageName.toLowerCase() ||
      qrName !== expectedName
    ) {
      throw new Error(
        `${row.idNumber} ${row.email} is ${row.title} ${row.name} | ${row.participantType} ${row.participantTypeColor} | ${row.packageName} | designation="${row.designation}" | organisation="${row.institution}" | qr="${qrName}"`
      );
    }
    console.log(
      `- ${row.idNumber}  ${row.title ? row.title + ' ' : ''}${row.name}  |  ${row.participantType}  |  ${row.participantTypeColor}  |  ${row.packageName}  |  designation="${row.designation}"  |  organisation="${row.institution}"`
    );
  }

  console.log('\nBlank cards:');
  for (const person of BLANKS) {
    const row = bySavedEmail.get(person.email);
    if (!row) throw new Error(`Missing ${person.email}`);
    const qrName = JSON.parse(row.qrCode || '{}').name;
    const expectedDbName = `DELEGATE ${row.idNumber}`;
    if (
      row.name !== expectedDbName ||
      (row.firstName || '') !== '' ||
      (row.middleName || '') !== '' ||
      (row.lastName || '') !== '' ||
      (row.title || '') !== '' ||
      (row.designation || '') !== '' ||
      (row.institution || '') !== '' ||
      row.participantType !== person.participantType ||
      row.participantTypeColor !== person.participantTypeColor ||
      String(row.packageName || '').toLowerCase() !== person.packageName.toLowerCase() ||
      qrName !== expectedDbName
    ) {
      throw new Error(
        `${row.idNumber} ${row.email} is name="${row.name}" | ${row.participantType} ${row.participantTypeColor} | ${row.packageName} | designation="${row.designation}" | organisation="${row.institution}" | qr="${qrName}"`
      );
    }
    console.log(
      `- ${row.idNumber}  name="${row.name}"  |  first name blank  |  ${row.participantType}  |  ${row.participantTypeColor}  |  ${row.packageName}`
    );
  }

  if (saved.length !== NAMED.length + BLANKS.length) {
    throw new Error(`Expected ${NAMED.length + BLANKS.length} role cards, found ${saved.length}`);
  }

  process.exit(0);
})().catch((err) => {
  console.error('Seed failed:', err.message || err);
  process.exit(1);
});
