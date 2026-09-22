/**
 * One-off seed: adds 10 random schedules to the event titled "Test event" on
 * each of 24, 25 and 26 Sep 2026 (30 schedules total), for testing the
 * upcoming-programs cycling UI with a larger dataset.
 *
 * Usage: node scripts/seedTestEventScheduleBatch.js
 */
const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const connectDB = require('../config/database');
const ManagedEvent = require('../models/ManagedEvent');
const EventSchedule = require('../models/EventSchedule');

const SPEAKERS = [
  'Dr. Anjali Menon',
  'Dr. Ravi Kumar',
  'Dr. Priya Nair',
  'Dr. Karthik Iyer',
  'Dr. Sneha Reddy',
  'Dr. Arjun Das',
  'Dr. Meera Pillai',
  'Dr. Vikram Rao',
  'Dr. Divya Krishnan',
  'Dr. Suresh Bhat',
];

const TOPICS = [
  'Advances in Digital Dentistry',
  'Oral Microbiome and Systemic Health',
  'Panel: Future of AI in Diagnostics',
  'Minimally Invasive Restorative Techniques',
  'Workshop: Endodontic Innovations',
  'Pediatric Dental Care Strategies',
  'Advances in Orthodontic Materials',
  'Implantology: Case Studies',
  'Periodontal Disease Management',
  'Panel: Preventive Dentistry in Practice',
];

const SLOTS = [
  ['09:00', '09:30'],
  ['09:45', '10:15'],
  ['10:30', '11:00'],
  ['11:15', '11:45'],
  ['12:00', '12:30'],
  ['13:30', '14:00'],
  ['14:15', '14:45'],
  ['15:00', '15:30'],
  ['15:45', '16:15'],
  ['16:30', '17:00'],
];

const DATES = ['2026-09-24', '2026-09-25', '2026-09-26'];

(async () => {
  await connectDB();
  const event = await ManagedEvent.findOne({ title: 'Test event' });
  if (!event) {
    console.error('No event titled "Test event" found.');
    process.exit(1);
  }

  const docs = [];
  for (const dateStr of DATES) {
    const date = new Date(`${dateStr}T00:00:00.000Z`);
    for (let i = 0; i < 10; i++) {
      const speakerName = SPEAKERS[i];
      const scheduleName = TOPICS[i];
      docs.push({
        eventId: event._id,
        apartmentId: event.apartmentId,
        speakerName,
        speakerPhoto: '',
        scheduleName,
        date,
        fromTime: SLOTS[i][0],
        toTime: SLOTS[i][1],
        description: `${scheduleName} presented by ${speakerName}.`,
      });
    }
  }

  const created = await EventSchedule.insertMany(docs);
  console.log(`Created ${created.length} schedules for "Test event" across ${DATES.join(', ')}.`);
  process.exit(0);
})().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
