/**
 * Replaces the 7–8 October 2026 student-conference programme.
 *
 * One EventSchedule row per talk, break, meal, oral session, and e-poster
 * block. Speaker names are stored on the row (joined with " · " when a slot
 * has several). No speaker logins are created. Rows with no printed speaker
 * use "—" so the field stays valid.
 *
 * Only 7 and 8 October are removed. The 9–11 October scientific programme
 * is left in place. If the event starts after 7 October, the start date is
 * moved to 7 October so those days appear in the schedule tabs.
 *
 * Usage: node scripts/seedStudentConferenceProgram.js
 */
const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const connectDB = require('../config/database');
const ManagedEvent = require('../models/ManagedEvent');
const EventSchedule = require('../models/EventSchedule');

const AUDITORIUM = 'SBDCH Auditorium';
const ORAL_SURGERY = 'Oral Surgery Seminar Hall';
const HALLS = 'SBDCH Auditorium Halls 1–7';
const EPOSTER = 'E-Poster Presentations';

const D1 = '2026-10-07';
const D2 = '2026-10-08';
const STUDENT_START = new Date(`${D1}T00:00:00.000Z`);
// 7 Oct 00:00 IST through 9 Oct 00:00 IST, so 9–11 October rows are kept.
const REPLACE_FROM = new Date('2026-10-06T18:30:00.000Z');
const REPLACE_TO = new Date('2026-10-08T18:30:00.000Z');

const NONE = '—';
const SERIES =
  'Research Reimagined: From Idea to Impact | Dental Research Orientation Lecture Series';
const MORNING = `${SERIES}. SBDCH Auditorium, 9:00–10:20 am.`;
const LEADERSHIP = 'Global Research Leadership: Inspiring the Next Generation.';
const AFTERNOON = `${SERIES}. Student Conference Pre-conference Courses, SBDCH Auditorium, 12:30–2:20 pm.`;

/** [date, from, to, hall, title, speaker, description] */
const PROGRAMME = [
  // Day 1 — SBDCH Auditorium
  [
    D1,
    '08:30',
    '09:00',
    AUDITORIUM,
    'Translational Proteomics & Systemic Biomarkers: High Throughput Science with Targeted Therapeutics',
    'Dr. Pavithra Krishnaswami',
    'International Expert Lecture. Senior Scientist, Translational Medicine Unit, Cambridge, Massachusetts, Greater Boston, Sanofi, USA. Moderator: Dr. Khavya C.',
  ],
  [D1, '09:00', '10:00', AUDITORIUM, 'Prayer & Lighting of Lamp', NONE, ''],
  [
    D1,
    '09:00',
    '10:00',
    AUDITORIUM,
    'Welcome to the World of Discovery and Invention',
    'Dr. M.S Kannan',
    'Dean, Sree Balaji Dental College and Hospital, Chennai, India',
  ],
  [
    D1,
    '09:00',
    '10:00',
    AUDITORIUM,
    'Empowering the Researchers of tomorrow',
    'Dr. S. Bhuminathan',
    'Registrar, Bharath Institute of Higher Education and Research, Chennai, India',
  ],
  [
    D1,
    '09:00',
    '10:00',
    AUDITORIUM,
    'Connecting the Young Minds',
    'Dr. K. Gnana Shanmugham',
    'Chairman, Scientific Committee',
  ],
  [
    D1,
    '09:00',
    '10:00',
    AUDITORIUM,
    'One Journey, Many Ideas, Endless Possibilities',
    'Dr. Sumathi Jones',
    'Convenor',
  ],
  [
    D1,
    '10:00',
    '10:30',
    AUDITORIUM,
    'Distinguished Keynote address',
    'Dr. Narayanan Ramasubbu',
    'Professor & Acting Chair, Associate Dean Research, Rutgers University, USA. Moderator: Dr. N. Gold Pearlin Mary.',
  ],
  [
    D1,
    '10:30',
    '10:45',
    AUDITORIUM,
    'Celebrating Collaboration & Gratitude',
    'Dr. N. Gold Pearlin Mary',
    'Co-Convenor.',
  ],
  [D1, '10:45', '11:00', AUDITORIUM, 'Research Refreshment Break', NONE, ''],
  [
    D1,
    '11:00',
    '11:30',
    AUDITORIUM,
    'Aptamers in dentistry: From Molecular recognition to chairside dentistry',
    'Dr. Sylvia Annabel Dass',
    'International Expert Insight. Laboratory Manager, ISO 13485 Quality & Validation Expert, Allen Healthcare Products, Penang, Malaysia. Moderator: Dr. P. Durgadevi.',
  ],
  [
    D1,
    '11:30',
    '11:50',
    AUDITORIUM,
    'Career options in research after BDS',
    'Dr. Sreedevi Kannan',
    `Professor & Head, Prosthodontics, SBDCH. ${SERIES}.`,
  ],
  [
    D1,
    '11:50',
    '12:10',
    AUDITORIUM,
    'Demystifying the concept of Research',
    'Dr. S. Priya Darshini',
    `Senior Lecturer, Oral Medicine and Radiology, SBDCH. ${SERIES}.`,
  ],
  [
    D1,
    '12:10',
    '12:30',
    AUDITORIUM,
    'How to select the right research Topic',
    'Dr. H. Shalini',
    `Senior Lecturer, Endodontics, SBDCH. ${SERIES}.`,
  ],
  [D1, '12:30', '13:30', AUDITORIUM, 'Research Recharge Lunch', NONE, ''],
  [
    D1,
    '13:30',
    '13:50',
    AUDITORIUM,
    'Digital Prosthodontics: A life saver or fire play. What does the research say?',
    'Dr. Ram Kiran K',
    `Reader, Prosthodontics, SBDCH. ${SERIES}.`,
  ],
  [
    D1,
    '13:50',
    '14:20',
    AUDITORIUM,
    'Research Reviewed: A beginner’s guide to Systematic review & meta-analysis',
    'Dr. Balavenkata Bharathi Chaturvedula',
    `Reader, Orthodontics, SBDCH. ${SERIES}.`,
  ],
  [
    D1,
    '14:20',
    '15:00',
    AUDITORIUM,
    'Honouring Excellence: Celebrating Young Researchers',
    NONE,
    '',
  ],

  // Day 1 — oral papers
  [D1, '11:00', '12:30', HALLS, 'Oral/Paper Presentation Session I', NONE, ''],
  [D1, '13:00', '14:30', HALLS, 'Oral/Paper Presentation Session II', NONE, ''],

  // Day 2 — SBDCH Auditorium
  [
    D2,
    '08:30',
    '09:00',
    AUDITORIUM,
    'Targeted Therapeutics of Oral Cancer',
    'Dr. Murugabaskar Balan',
    'International Expert Talk. Scientist, Boston Children’s Hospital, Harvard Medical School, USA. Moderator: Dr. Sumathi Jones.',
  ],
  [
    D2,
    '09:00',
    '09:20',
    AUDITORIUM,
    'Ethics in biomedical research',
    'Dr. M. Ramya Chellammal',
    `Senior Lecturer, Pedodontics, SBDCH. ${MORNING}`,
  ],
  [
    D2,
    '09:20',
    '09:40',
    AUDITORIUM,
    'The Art and Science of Manuscript writing',
    'Dr. K. Mahalakshmi',
    `Professor & Head, Microbiology, SBDCH. ${MORNING}`,
  ],
  [
    D2,
    '09:40',
    '10:00',
    AUDITORIUM,
    'AI in research',
    'Dr. J. Bhuvaneswarri',
    `Professor, Periodontics, SBDCH. ${MORNING}`,
  ],
  [
    D2,
    '10:00',
    '10:20',
    AUDITORIUM,
    'Beyond the P-Value: The Science Behind the Numbers',
    'Dr. D. Charumathi',
    `Senior Lecturer, Public Health Dentistry, SBDCH. ${MORNING}`,
  ],
  [D2, '10:20', '10:30', AUDITORIUM, 'Research Refreshment Break', NONE, ''],
  [
    D2,
    '10:30',
    '11:00',
    AUDITORIUM,
    'A brief insight into IADR and its role in supporting meaningful research',
    'Dr. Christopher Fox',
    `CEO – IADR. ${LEADERSHIP}`,
  ],
  [
    D2,
    '11:00',
    '11:30',
    AUDITORIUM,
    'An insight into my research and career journey',
    'Dr. Jennifer Gallagher',
    `President - IADR. ${LEADERSHIP}`,
  ],
  [
    D2,
    '11:30',
    '12:00',
    AUDITORIUM,
    'An overview about ISDR/IADR Indian Division',
    'Dr. S.M. Balaji',
    `Director of Balaji Dental & Craniofacial Hospital, Chennai, India. ${LEADERSHIP}`,
  ],
  [D2, '12:00', '12:30', AUDITORIUM, 'Felicitation of Pre-conference Resource persons', NONE, ''],
  [
    D2,
    '12:30',
    '12:50',
    AUDITORIUM,
    'Publication Ethics',
    'Dr. S. Leena Sankari',
    `Professor, Oral and Maxillofacial Pathology and Oral Microbiology, SBDCH. ${AFTERNOON}`,
  ],
  [D2, '12:50', '13:30', AUDITORIUM, 'The Networking Feast', NONE, ''],
  [
    D2,
    '13:30',
    '13:50',
    AUDITORIUM,
    'Plagiarism paradox',
    'Dr. R. Mathangi',
    `Professor & Head, Biochemistry, SBDCH. ${AFTERNOON}`,
  ],
  [
    D2,
    '13:50',
    '14:20',
    AUDITORIUM,
    'Don’t just publish - innovate: From Research to Patent',
    'Dr. Sumathi Jones',
    `Professor & Head, Pharmacology, SBDCH. ${AFTERNOON}`,
  ],
  [
    D2,
    '14:30',
    '15:00',
    AUDITORIUM,
    'Closing the Chapter, Opening New Horizons',
    NONE,
    'Valedictory function.',
  ],

  // Day 2 — Oral Surgery Seminar Hall
  [
    D2,
    '09:15',
    '12:00',
    ORAL_SURGERY,
    'Session I',
    NONE,
    'Student Conference Pre-Conference Courses.',
  ],
  [D2, '13:00', '14:30', ORAL_SURGERY, 'E-Poster Presentation Session III', NONE, ''],

  // Day 2 — e-posters
  [D2, '09:00', '10:30', EPOSTER, 'E-Poster Presentation Session I', NONE, ''],
  [D2, '10:30', '12:30', EPOSTER, 'E-Poster Presentation Session II', NONE, ''],
];

/** Calendar day in India, so UTC-midnight rows and IST-midnight rows group the same. */
function istDay(date) {
  const shifted = new Date(new Date(date).getTime() + 5.5 * 60 * 60 * 1000);
  return shifted.toISOString().slice(0, 10);
}

function countByDay(rows) {
  const map = {};
  for (const row of rows) {
    const key = istDay(row.date);
    map[key] = (map[key] || 0) + 1;
  }
  return map;
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

  const before = await EventSchedule.find({ eventId: event._id }).select('date');
  const beforeCounts = countByDay(before);
  console.log('Before:', beforeCounts);

  if (event.eventDate && event.eventDate > STUDENT_START) {
    const previous = event.eventDate.toISOString();
    event.eventDate = STUDENT_START;
    await event.save();
    console.log(`Event start moved from ${previous} to ${STUDENT_START.toISOString()}.`);
  } else {
    console.log(`Event start left at ${event.eventDate ? event.eventDate.toISOString() : '(none)'}.`);
  }

  const removed = await EventSchedule.deleteMany({
    eventId: event._id,
    date: { $gte: REPLACE_FROM, $lt: REPLACE_TO },
  });
  console.log(`Removed ${removed.deletedCount} schedule(s) on 7–8 October.`);

  const docs = PROGRAMME.map(([date, fromTime, toTime, hall, scheduleName, speakerName, description]) => ({
    eventId: event._id,
    apartmentId: event.apartmentId,
    speakerName,
    speakerPhoto: '',
    scheduleName,
    packageIds: [],
    hall,
    date: new Date(`${date}T00:00:00.000Z`),
    fromTime,
    toTime,
    description,
  }));

  const created = await EventSchedule.insertMany(docs);
  const byHall = {};
  for (const row of created) {
    byHall[row.hall] = (byHall[row.hall] || 0) + 1;
  }
  console.log(`Created ${created.length} schedules.`);
  for (const [hall, count] of Object.entries(byHall)) {
    console.log(`  ${hall}: ${count}`);
  }

  const after = await EventSchedule.find({ eventId: event._id }).select('date');
  const afterCounts = countByDay(after);
  console.log('After:', afterCounts);
  for (const day of ['2026-10-09', '2026-10-10', '2026-10-11']) {
    const kept = beforeCounts[day] || 0;
    const now = afterCounts[day] || 0;
    if (kept !== now) {
      throw new Error(`${day} changed from ${kept} to ${now}`);
    }
    console.log(`  ${day}: ${now} (unchanged)`);
  }

  process.exit(0);
})().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
