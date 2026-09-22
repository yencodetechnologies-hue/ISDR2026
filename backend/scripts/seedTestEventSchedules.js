/**
 * One-off seed: adds 6 random schedules to the event titled "Test event" on
 * 23 Sep 2026, for quick demo/testing of the schedule cycling UI.
 *
 * Usage: node scripts/seedTestEventSchedules.js
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
];

const TOPICS = [
  'Advances in Digital Dentistry',
  'Oral Microbiome and Systemic Health',
  'Panel: Future of AI in Diagnostics',
  'Minimally Invasive Restorative Techniques',
  'Workshop: Endodontic Innovations',
  'Closing Remarks & Networking',
];

const SLOTS = [
  ['09:00', '09:45'],
  ['10:00', '10:45'],
  ['11:00', '11:45'],
  ['12:00', '12:45'],
  ['14:00', '14:45'],
  ['15:00', '15:45'],
];

(async () => {
  await connectDB();
  const event = await ManagedEvent.findOne({ title: 'Test event' });
  if (!event) {
    console.error('No event titled "Test event" found.');
    process.exit(1);
  }

  const date = new Date('2026-09-23T00:00:00.000Z');
  const docs = SPEAKERS.map((speakerName, i) => ({
    eventId: event._id,
    apartmentId: event.apartmentId,
    speakerName,
    speakerPhoto: '',
    scheduleName: TOPICS[i],
    date,
    fromTime: SLOTS[i][0],
    toTime: SLOTS[i][1],
    description: `${TOPICS[i]} presented by ${speakerName}.`,
  }));

  const created = await EventSchedule.insertMany(docs);
  console.log(`Created ${created.length} schedules for "Test event" on 23 Sep 2026.`);
  process.exit(0);
})().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
