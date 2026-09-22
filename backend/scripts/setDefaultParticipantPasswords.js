/**
 * One-off migration: gives every existing participant (EventRegistration) without a
 * password the default login password '123456'. New registrations already get this
 * at creation time (see managedEventController.createParticipantRegistration) — this
 * script only backfills participants created before that existed.
 *
 * Usage: node scripts/setDefaultParticipantPasswords.js
 */
const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const connectDB = require('../config/database');
const EventRegistration = require('../models/EventRegistration');

const DEFAULT_PASSWORD = '123456';

(async () => {
  await connectDB();
  const regs = await EventRegistration.find({
    $or: [{ password: { $exists: false } }, { password: '' }],
  }).select('+password');

  console.log(`Found ${regs.length} participant(s) without a password.`);
  for (const reg of regs) {
    reg.password = DEFAULT_PASSWORD; // hashed by the pre('save') hook
    await reg.save();
  }
  console.log(`Done. Set the default password for ${regs.length} participant(s).`);
  process.exit(0);
})().catch((err) => {
  console.error('Migration failed:', err);
  process.exit(1);
});
