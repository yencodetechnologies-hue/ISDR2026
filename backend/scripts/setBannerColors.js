/**
 * Sets badge banner colours on the ISDR 2026 registrations.
 *
 * Organising Committee package (except invited speakers) → maroon.
 * Student Delegate → green. Delegate → orange.
 * Invited Speaker, Invited Speakers, and speaker → sky blue.
 * Event Organizer and Trade → blue.
 * Other types are left as they are. Re-running is safe.
 *
 * Usage: node scripts/setBannerColors.js
 */
const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const connectDB = require('../config/database');
const EventRegistration = require('../models/EventRegistration');

const PACKAGE_NAME = /^organising committee$/i;
const MAROON = '#9E0A0F';
const GREEN = '#167E5D';
const ORANGE = '#D46D1D';
const SKY = '#0284C7';
const ORGANIZER_BLUE = '#1D4ED8';
const SPEAKER_TYPE = /^(invited\s+)?speakers?$/i;

async function counts() {
  const rows = await EventRegistration.aggregate([
    {
      $group: {
        _id: { type: '$participantType', color: '$participantTypeColor' },
        n: { $sum: 1 },
      },
    },
    { $sort: { '_id.type': 1, n: -1 } },
  ]);
  for (const r of rows) {
    console.log(String(r.n).padStart(5), '|', JSON.stringify(r._id.type), '|', r._id.color ?? '');
  }
}

(async () => {
  await connectDB();
  console.log('Before:');
  await counts();

  const committee = await EventRegistration.updateMany(
    { packageName: PACKAGE_NAME, participantType: { $not: SPEAKER_TYPE } },
    { $set: { participantTypeColor: MAROON } }
  );
  const students = await EventRegistration.updateMany(
    { participantType: 'Student Delegate' },
    { $set: { participantTypeColor: GREEN } }
  );
  const delegates = await EventRegistration.updateMany(
    { participantType: 'Delegate' },
    { $set: { participantTypeColor: ORANGE } }
  );
  const speakers = await EventRegistration.updateMany(
    { participantType: SPEAKER_TYPE },
    { $set: { participantTypeColor: SKY } }
  );
  const organizers = await EventRegistration.updateMany(
    { participantType: /^event\s+organizers?$/i },
    { $set: { participantTypeColor: ORGANIZER_BLUE } }
  );
  const trade = await EventRegistration.updateMany(
    { participantType: /^trade$/i },
    { $set: { participantTypeColor: ORGANIZER_BLUE } }
  );

  console.log(
    `\nUpdated committee ${committee.modifiedCount}/${committee.matchedCount} ${MAROON}, ` +
      `student delegates ${students.modifiedCount}/${students.matchedCount} ${GREEN}, ` +
      `delegates ${delegates.modifiedCount}/${delegates.matchedCount} ${ORANGE}, ` +
      `speakers ${speakers.modifiedCount}/${speakers.matchedCount} ${SKY}, ` +
      `event organizers ${organizers.modifiedCount}/${organizers.matchedCount} ${ORGANIZER_BLUE}, ` +
      `trade ${trade.modifiedCount}/${trade.matchedCount} ${ORGANIZER_BLUE}`
  );
  console.log('\nAfter:');
  await counts();
  process.exit(0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
