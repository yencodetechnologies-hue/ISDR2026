/**
 * Permanently delete every session Q&A and speaker Q&A document.
 * Run: node scripts/clearAllQuestions.js
 */
const path = require('path');
const dns = require('dns');
const dotenv = require('dotenv');

dotenv.config({ path: path.join(__dirname, '..', '.env') });
dns.setServers(['8.8.8.8', '1.1.1.1']);

const mongoose = require('mongoose');
const connectDB = require('../config/database');
const SessionQuestion = require('../models/SessionQuestion');
const SpeakerQuestion = require('../models/SpeakerQuestion');

async function main() {
  await connectDB();

  const sessionCount = await SessionQuestion.countDocuments();
  const speakerCount = await SpeakerQuestion.countDocuments();
  console.log(`Before: ${sessionCount} session Q&A, ${speakerCount} speaker Q&A`);

  const sessionResult = await SessionQuestion.deleteMany({});
  const speakerResult = await SpeakerQuestion.deleteMany({});

  console.log(
    `Removed: ${sessionResult.deletedCount} session Q&A, ${speakerResult.deletedCount} speaker Q&A`
  );

  await mongoose.connection.close();
  process.exit(0);
}

main().catch(async (err) => {
  console.error('FAIL:', err.message || err);
  try {
    await mongoose.connection.close();
  } catch (_) {}
  process.exit(1);
});
