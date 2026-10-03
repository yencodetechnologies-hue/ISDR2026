/**
 * Gives a dummy name to registrations whose name is blank.
 * Entry/exit scan saves the whole row, and an empty name fails that save.
 * The stored QR string is left unchanged so already printed badges still match.
 *
 * Usage: node scripts/_fillBlankNames.js
 */
const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const connectDB = require('../config/database');
const EventRegistration = require('../models/EventRegistration');

function dummyName(reg) {
  const id = String(reg.idNumber || '').trim();
  return id ? `DELEGATE ${id}` : 'DELEGATE';
}

(async () => {
  await connectDB();
  const rows = await EventRegistration.find({
    $or: [{ name: '' }, { name: null }, { name: { $exists: false } }, { name: /^\s+$/ }],
  }).select('name idNumber firstName packageName participantType');

  console.log(`Blank names: ${rows.length}`);
  let updated = 0;
  for (const reg of rows) {
    const name = dummyName(reg);
    await EventRegistration.updateOne(
      { _id: reg._id },
      { $set: { name, firstName: name, middleName: '', lastName: '' } }
    );
    updated += 1;
    console.log(`- ${reg.idNumber || reg._id}  ${reg.packageName || ''}  -> "${name}"`);
  }
  console.log(`Updated ${updated}`);
  process.exit(0);
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
