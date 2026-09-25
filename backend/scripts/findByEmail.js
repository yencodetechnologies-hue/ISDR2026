/**
 * Look up which collection an email belongs to and whether it has FCM tokens registered.
 * Run: node scripts/findByEmail.js <email>
 */
const path = require('path');
const dns = require('dns');
const dotenv = require('dotenv');

dotenv.config({ path: path.join(__dirname, '..', '.env') });
dns.setServers(['8.8.8.8', '1.1.1.1']);

const mongoose = require('mongoose');
const connectDB = require('../config/database');
const Apartment = require('../models/Apartment');
const ManagementUser = require('../models/ManagementUser');
const EventStaff = require('../models/EventStaff');
const EventRegistration = require('../models/EventRegistration');
const Speaker = require('../models/Speaker');

const MODELS = [
  { Model: EventRegistration, type: 'participant' },
  { Model: EventStaff, type: 'user' },
  { Model: Apartment, type: 'apartment' },
  { Model: ManagementUser, type: 'management' },
  { Model: Speaker, type: 'speaker' },
];

async function main() {
  const email = process.argv[2];
  if (!email) {
    console.error('Usage: node scripts/findByEmail.js <email>');
    process.exit(1);
  }

  await connectDB();

  let found = false;
  for (const { Model, type } of MODELS) {
    const doc = await Model.findOne({ email: new RegExp(`^${email}$`, 'i') }).select(
      '_id email fcmTokens name isActive'
    );
    if (doc) {
      found = true;
      console.log(`FOUND in ${type}:`, {
        id: doc._id.toString(),
        email: doc.email,
        name: doc.name,
        isActive: doc.isActive,
        fcmTokenCount: doc.fcmTokens ? doc.fcmTokens.length : 0,
      });
    }
  }

  if (!found) {
    console.log(`No account found with email ${email}`);
  }

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
