/**
 * Stores the ISDR 2026 ranked award recipients announced in ISDR Results 2.
 *
 * Award numbers match the app categories:
 *   3 Best Patent, 4 Best Research Grant, 5 Best Research Publication,
 *   6 Best Research Centre, 7 Best Research Book, 8 Best Research Collaboration,
 *   11 UG Best Publication, 12 UG Best Grant.
 * Poster and paper awards are left unchanged.
 *
 * Usage: node scripts/seedAwardWinners.js
 */
const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const connectDB = require('../config/database');
const ManagedEvent = require('../models/ManagedEvent');
const AwardWinner = require('../models/AwardWinner');

const RESULTS = [
  {
    awardNumber: 5,
    title: 'Best Research Publication',
    recipients: [
      { rank: 1, name: 'Dr Saravanan Balasubramanian' },
      { rank: 2, name: 'Dr P D Madan Kumar' },
      { rank: 3, name: 'Dr Divyambiga' },
      { rank: 4, name: 'Dr Gunjan Pruthi' },
      { rank: 5, name: 'Dr Vikender Singh' },
    ],
  },
  {
    awardNumber: 4,
    title: 'Best Research Grant',
    recipients: [
      { rank: 1, name: 'Dr Arpit Gupta' },
      { rank: 2, name: 'Dr P D Madan Kumar' },
      { rank: 3, name: 'Dr Vikender Singh' },
    ],
  },
  {
    awardNumber: 8,
    title: 'Best Research Collaboration',
    recipients: [
      { rank: 1, name: 'Dr Arthi A' },
      { rank: 2, name: 'Dr Divyambiga CV' },
      { rank: 3, name: 'Dr Rameshwari Singhal' },
      { rank: 3, name: 'Dr Priyadharshini' },
    ],
  },
  {
    awardNumber: 6,
    title: 'Best Research Centre',
    recipients: [
      { rank: 1, name: 'Dr Badri Narayanan' },
      { rank: 2, name: 'Dr Ambili R' },
      { rank: 3, name: 'Dr Usha' },
    ],
  },
  {
    awardNumber: 7,
    title: 'Best Book Award',
    recipients: [
      { rank: 1, name: 'Dr Prabhat Kumar Chaudhari' },
      { rank: 2, name: 'Dr N Gopi Chander' },
      { rank: 3, name: 'Dr Hema P' },
    ],
  },
  {
    awardNumber: 3,
    title: 'Best Patent Award',
    recipients: [
      { rank: 1, name: 'Dr Rameshwari Singhal' },
      { rank: 2, name: 'Dr Ambili R' },
      { rank: 3, name: 'Dr Jaideep Mahendra' },
      { rank: 4, name: 'Dr Nalini Ashwath' },
    ],
  },
  {
    awardNumber: 11,
    title: 'Best Research Publication – UG',
    recipients: [
      { rank: 1, name: 'Pradeep. VR' },
      { rank: 2, name: 'Siva Ranjini K.T.' },
    ],
  },
  {
    awardNumber: 12,
    title: 'Best Research Grant – UG',
    recipients: [
      { rank: 1, name: 'Mr Aman Gupta' },
      { rank: 1, name: 'Mr Pradeep Veerappan' },
      { rank: 1, name: 'Ms Catherine Vinod Kattookaran' },
    ],
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
  console.log(`Event: ${event.title} (${event._id}), apartment ${event.apartmentId}`);

  for (const row of RESULTS) {
    const summary = row.recipients.map((p) => `${p.rank}. ${p.name}`).join('  ');
    await AwardWinner.findOneAndUpdate(
      { apartmentId: event.apartmentId, awardNumber: row.awardNumber },
      {
        $set: {
          name: summary,
          recipients: row.recipients,
        },
        $unset: { registrationId: '' },
      },
      { upsert: true, new: true }
    );
    console.log(`${row.awardNumber}. ${row.title}: ${row.recipients.length} recipient(s)`);
  }

  const saved = await AwardWinner.find({ apartmentId: event.apartmentId }).sort({ awardNumber: 1 }).lean();
  console.log(`\n${saved.length} award document(s) for this apartment:`);
  for (const doc of saved) {
    const lines = (doc.recipients || []).map((p) => `${p.rank}. ${p.name}`).join(', ');
    console.log(`- award ${doc.awardNumber}: ${lines || doc.name || '(empty)'}`);
  }

  process.exit(0);
})().catch((err) => {
  console.error('Seed failed:', err.message || err);
  process.exit(1);
});
