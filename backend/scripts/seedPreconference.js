/**
 * Upserts the nine ISDR 2026 pre-conference courses for the event's property.
 * Re-running updates the same S No in place and leaves any extra rows alone.
 *
 * Usage: node scripts/seedPreconference.js
 */
const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const connectDB = require('../config/database');
const ManagedEvent = require('../models/ManagedEvent');
const PreconferenceCourse = require('../models/PreconferenceCourse');

const COURSES = [
  {
    serialNo: 1,
    date: '08.09.26',
    course:
      'PCC 1- UNLOCKING THE BASICS OF RESEARCH METHODOLGY AND BIOSTATISTICS - DR MANJULA DATTA, DR SARUMATHI & TEAM',
    venue: 'AUDITORIUM I, SBDCH.',
  },
  {
    serialNo: 2,
    date: '08.09.26',
    course: 'PCC2- BIOMARKERS IN DENTISTRY FOR PERSONALISED CARE – DR SWAMINATHAN SETHU',
    venue: 'LECTURE HALL I, SBDCH',
  },
  {
    serialNo: 3,
    date: '08.09.26',
    course:
      'PCC 3 -MASTERING HIGH-QUALITY SYSTEMATIC REVIEWS – AN INTERACTIVE WORKSHOP - DR VENKATESH BABU',
    venue: 'BOARD ROOM, SBDCH',
  },
  {
    serialNo: 4,
    date: '08.09.26',
    course: 'PCC 4 -EVIDENCE SYNTHESIS IN DENTAL RESEARCH - HANDS ON-DR RICHARD KIRUBAKARAN',
    venue: 'LECTURE HALL III, SBDCH',
  },
  {
    serialNo: 5,
    date: '08.09.26',
    course: 'PCC 5 – NEUROMUSCULAR DENTISTRY -DR TATU JOY',
    venue: 'PROSTHO SEMINAR HALL SBDCH',
  },
  {
    serialNo: 6,
    date: '08.09.26',
    course:
      'PCC 6 – CLEFT RESEARCH: FROM IDEAS TO IMPACT-TOPICS, FUNDING, COLLABORATIONS, STUDY DESIGN,AND EXECUTION– DR BADRI TIRUVENKATACHARI & TEAM',
    venue: 'THE CLEFT & CRANIOFACIAL CENTRE, RELA HOSPITAL, CHENNAI',
  },
  {
    serialNo: 7,
    date: '08.09.26',
    course: 'PCC 7 – THE MINIMALIST DENTIST-CHANGING CONCEPTS IN MID- DR KRITHIKA DATTA',
    venue: 'LECTURE HALL II, SBDCH',
  },
  {
    serialNo: 8,
    date: '08.09.26',
    course:
      'PCC 8 - FUNDING SUCCESS SIMPLIFIED: DESIGNING, WRITING, BUDGETING AND REFINING ICMR AND DST PROPOSALS- DR.AARTHI BHUVARAGHAN',
    venue: 'THE CLEFT & CRANIOFACIAL CENTRE, RELA HOSPITAL, CHENNAI',
  },
  {
    serialNo: 9,
    date: '08.09.26',
    course:
      'PCC 9- STEM CELLS AND SMART BIOMATERIALS IN DENTISTRY: FROM LABORATORY INNOVATION TO CLINICAL REGENERATION- DR RAGHUNANDA KUMAR',
    venue: 'SAVEETHA DENTAL COLLEGE',
  },
];

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

  for (const row of COURSES) {
    await PreconferenceCourse.findOneAndUpdate(
      { apartmentId: event.apartmentId, serialNo: row.serialNo },
      { $set: { ...row, apartmentId: event.apartmentId } },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );
    console.log(`  ${row.serialNo}. ${row.course.slice(0, 48)}…`);
  }
  console.log(`Upserted ${COURSES.length} pre-conference courses.`);
  process.exit(0);
})().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
