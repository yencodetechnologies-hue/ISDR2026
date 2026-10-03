/**
 * Adds invited speakers to the ISDR 2026 event.
 *
 * Uses the free "Organising Committee" package (created with dummy entry/exit
 * dates if it is missing). Each person is a new registration with participant
 * type "Invited Speakers" and the speaker sky-blue banner. The first list has
 * an empty organisation. The course-speaker list sets organisation to
 * "Pre-Conference Course Speaker". Designation stays empty and every other
 * field is dummy data. Names are stored in capitals. An email that is already registered is not inserted again.
 * Re-running refreshes that person's name parts. Later names are appended after that list.
 * A name that is already an invited speaker is left in place. Every invited speaker
 * on the event is given the same sky-blue banner.
 *
 * Usage: node scripts/seedInvitedSpeakers.js
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
const PARTICIPANT_TYPE = 'Invited Speakers';
const TYPE_COLOR = '#0284C7';
const DUMMY_DATES = ['2000-01-01', '2000-01-02', '2000-01-03'];

const SPEAKER_NAMES = [
  'Joe Joseph',
  'Jayakumar P. Pillai',
  'Ashith B Acharya',
  'L. Ashok',
  'Vinod Krishnan',
  'Rekha Bharadwaj',
  'Sumanth Kumar R',
  'Srirengalakshmi M',
  'Thulasiram E',
  'Bharathi Chaturvedula',
  'Manoj Prathap C',
  'Naveen Hedne',
  'Sapna Nangia',
  'Sujith Mulappally',
  'Arunan Murali',
  'Nandhini Suresh',
  'Vamsi Lavu',
  'Gopalakrishnan Dharmarajan',
  'Anurag Satpathy',
  'Ganesh Puttu',
  'Sagar J. Abichandani',
  'Bhuminathan S',
  'R. Narasimha Raghavan',
  'Gopi Chander N',
  'Ritu Duggal',
  'Vijay Prakash Mathur',
  'Nitika Monga',
  'Swaminathan Sethu',
  'Tatu Joy',
  'Ajay Kubavat',
  'Arif Yezdani',
  'Vijay Adhith C',
  'Kavitha Sanjeev',
  'Harsh Priya',
  'Pratibha Ramani',
  'Aruning',
  'Richard Kirubakaran',
  'Mano Vijay',
  'Sangeetha Duraisamy',
  'K Sheela Kumari',
  'Aarthi Bhuvanaghavan',
];

const COURSE_ORGANISATION = 'Pre-Conference Course Speaker';
const COURSE_SPEAKERS = [
  { title: 'Dr', name: 'Manjula Datta' },
  { title: 'Dr', name: 'Sarumathi T' },
  { title: 'Prof', name: 'Swaminathan Sethu' },
  { title: 'Dr', name: 'Venkatesh Babu' },
  { title: 'Mr', name: 'Richard Kirubakaran' },
  { title: 'Prof', name: 'Tatu Joy' },
  { title: 'Dr', name: 'Badri Thiruvenkatachari' },
  { title: 'Dr', name: 'Krithika Datta' },
  { title: 'Dr', name: 'Aarthi Bhuvaraghavan' },
  { title: 'Dr', name: 'S. Raghunandhakumar' },
];

const EXTRA_SPEAKERS = [
  { title: 'Dr', name: 'Jonathan Sandler' },
  { title: 'Prof', name: 'Hiroshi Egusa' },
  { title: 'Dr', name: 'Narayanan Ramasubbu' },
  { title: 'Dr', name: 'Murugabaskar Balan' },
  { title: 'Dr', name: 'Betsy Joseph' },
  { title: 'Dr', name: 'Venkatesh Babu' },
  { title: 'Dr', name: 'Prabhu Manickam Natarajan' },
  { title: 'Dr', name: 'Keerthika Natarajan' },
  { title: 'Dr', name: 'Ramanathan Ravi' },
  { title: 'Dr', name: 'Christopher Fox' },
  { title: 'Dr', name: 'Mahesh Verma' },
];

/** Last word is the surname, including a one-letter initial. A single word stays as the first name. "--" is never part of the surname. */
function splitName(fullName) {
  const parts = String(fullName || '')
    .replace(/--/g, ' ')
    .trim()
    .split(/\s+/)
    .filter(Boolean);
  if (parts.length <= 1) {
    return { firstName: parts[0] || '', middleName: '', lastName: '' };
  }
  return {
    firstName: parts[0],
    middleName: parts.slice(1, -1).join(' '),
    lastName: parts[parts.length - 1].replace(/--/g, ''),
  };
}

function nameKey(fullName) {
  return String(fullName || '')
    .replace(/--/g, ' ')
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, '');
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

  const existingInvited = await EventRegistration.find({
    eventId: event._id,
    participantType: PARTICIPANT_TYPE,
  }).select('name firstName middleName lastName email');
  const existingEmails = new Set(
    (
      await EventRegistration.find({
        eventId: event._id,
        email: /^invitedspeaker\d+@example\.com$/,
      }).select('email')
    ).map((reg) => String(reg.email || '').toLowerCase())
  );
  const existingNameKeys = new Set(
    existingInvited.map((reg) => {
      const composed = [reg.firstName, reg.middleName, reg.lastName].filter(Boolean).join(' ');
      return nameKey(composed || reg.name);
    })
  );

  const people = [
    ...SPEAKER_NAMES.map((name) => ({ title: 'Dr', name, institution: '' })),
    ...COURSE_SPEAKERS.map((person) => ({ ...person, institution: COURSE_ORGANISATION })),
    ...EXTRA_SPEAKERS.map((person) => ({ ...person, institution: '' })),
  ];

  for (let i = 0; i < people.length; i += 1) {
    const person = people[i];
    const n = String(i + 1).padStart(2, '0');
    const email = `invitedspeaker${n}@example.com`;
    const parts = splitName(person.name.toUpperCase());
    const storedName = [parts.firstName, parts.middleName, parts.lastName].filter(Boolean).join(' ');
    const key = nameKey(storedName);
    if (!existingEmails.has(email) && existingNameKeys.has(key)) {
      console.log(`Skipped ${person.name} (already registered under this name)`);
      continue;
    }
    if (existingEmails.has(email)) {
      const reg = await EventRegistration.findOne({ eventId: event._id, email });
      if (
        reg &&
        (reg.firstName !== parts.firstName ||
          reg.middleName !== parts.middleName ||
          reg.lastName !== parts.lastName ||
          reg.name !== storedName)
      ) {
        reg.firstName = parts.firstName;
        reg.middleName = parts.middleName;
        reg.lastName = parts.lastName;
        reg.name = storedName;
        await reg.save();
        console.log(`Updated ${person.name} → ${storedName}`);
      } else {
        console.log(`Skipped ${person.name} (${email} already registered)`);
      }
      continue;
    }
    const created = await createParticipantRegistration(event, {
      packageId: pkg.id,
      source: 'bulk',
      profile: {
        title: person.title,
        firstName: parts.firstName,
        middleName: parts.middleName,
        lastName: parts.lastName,
        gender: 'other',
        participantType: PARTICIPANT_TYPE,
        participantTypeColor: TYPE_COLOR,
        designation: '',
        institution: person.institution,
        address: 'Dummy address',
        mobileNumber: `98000000${n}`,
        email,
        foodPreference: 'veg',
      },
    });
    existingNameKeys.add(key);
    console.log(`Created ${person.name} (${created.idNumber})`);
  }

  const invited = await EventRegistration.find({
    eventId: event._id,
    participantType: PARTICIPANT_TYPE,
  });
  for (const reg of invited) {
    const firstName = String(reg.firstName || '').toUpperCase();
    const middleName = String(reg.middleName || '').toUpperCase();
    const lastName = String(reg.lastName || '').replace(/--/g, '').toUpperCase();
    const composed = [firstName, middleName, lastName].filter(Boolean).join(' ');
    const name = composed || String(reg.name || '').toUpperCase();
    const nameChanged = !(
      reg.firstName === firstName &&
      reg.middleName === middleName &&
      reg.lastName === lastName &&
      reg.name === name
    );
    const colorChanged = reg.participantTypeColor !== TYPE_COLOR;
    if (!nameChanged && !colorChanged) continue;
    if (nameChanged) {
      reg.firstName = firstName;
      reg.middleName = middleName;
      reg.lastName = lastName;
      reg.name = name;
    }
    if (colorChanged) reg.participantTypeColor = TYPE_COLOR;
    await reg.save();
    if (nameChanged) console.log(`Capitalised ${reg.idNumber}  ${reg.name}`);
    if (colorChanged) console.log(`Color ${reg.idNumber}  ${reg.name || name}  ${TYPE_COLOR}`);
  }

  const saved = await EventRegistration.find({
    eventId: event._id,
    participantType: PARTICIPANT_TYPE,
    email: /^invitedspeaker\d+@example\.com$/,
  })
    .select('name title designation institution participantType participantTypeColor packageName idNumber email')
    .sort({ idNumber: 1 })
    .lean();
  console.log(`\n${saved.length} invited speaker registration(s) from this seed:`);
  for (const row of saved) {
    console.log(
      `- ${row.idNumber}  ${row.title} ${row.name}  |  ${row.participantType}  |  ${row.participantTypeColor}  |  ${row.packageName}  |  designation="${row.designation}"  |  organisation="${row.institution}"`
    );
  }

  const firstExtra = SPEAKER_NAMES.length + COURSE_SPEAKERS.length + 1;
  const added = saved.filter((row) => {
    const n = Number(String(row.email || '').match(/invitedspeaker(\d+)/i)?.[1] || 0);
    return n >= firstExtra;
  });
  console.log(`\n${added.length} new invited speaker row(s):`);
  for (const row of added) {
    console.log(
      `- ${row.idNumber}  ${row.title} ${row.name}  |  ${row.participantTypeColor}  |  organisation="${row.institution}"`
    );
  }

  const missingColor = await EventRegistration.countDocuments({
    eventId: event._id,
    participantType: PARTICIPANT_TYPE,
    participantTypeColor: { $ne: TYPE_COLOR },
  });
  console.log(`\nInvited speakers missing ${TYPE_COLOR}: ${missingColor} (extra list starts at invitedspeaker${String(firstExtra).padStart(2, '0')})`);

  process.exit(0);
})().catch((err) => {
  console.error('Seed failed:', err.message || err);
  process.exit(1);
});
