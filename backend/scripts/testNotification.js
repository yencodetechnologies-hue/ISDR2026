/**
 * Send a test FCM push notification via backend fcmService.
 * Run: node scripts/testNotification.js [userId] [userType]
 * userType: apartment | management | user (event staff) | participant | speaker
 * Example: node scripts/testNotification.js 507f1f77bcf86cd799439011 participant
 */
const path = require('path');
const dns = require('dns');
const dotenv = require('dotenv');

dotenv.config({ path: path.join(__dirname, '..', '.env') });

// Windows/router DNS sometimes blocks SRV lookups; fall back to public resolvers.
dns.setServers(['8.8.8.8', '1.1.1.1']);

const mongoose = require('mongoose');
const connectDB = require('../config/database');
const Apartment = require('../models/Apartment');
const ManagementUser = require('../models/ManagementUser');
const EventStaff = require('../models/EventStaff');
const EventRegistration = require('../models/EventRegistration');
const Speaker = require('../models/Speaker');
const { sendNotificationToUser } = require('../utils/fcmService');

const MODELS = [
  { Model: EventRegistration, type: 'participant' },
  { Model: EventStaff, type: 'user' },
  { Model: Apartment, type: 'apartment' },
  { Model: ManagementUser, type: 'management' },
  { Model: Speaker, type: 'speaker' },
];

async function findRecipientWithTokens(userId, userType) {
  if (userId && userType) {
    return { userId, userType };
  }

  for (const { Model, type } of MODELS) {
    const doc = await Model.findOne({
      fcmTokens: { $exists: true, $not: { $size: 0 } },
      isActive: { $ne: false },
    }).select('_id fcmTokens email name mobileNumber');

    if (doc && doc.fcmTokens?.length) {
      const label = doc.email || doc.name || doc.mobileNumber || doc._id.toString();
      console.log(`Using first account with FCM tokens: ${label} (${type})`);
      return { userId: doc._id.toString(), userType: type };
    }
  }

  return null;
}

async function main() {
  const [userIdArg, userTypeArg] = process.argv.slice(2);

  await connectDB();

  const recipient = await findRecipientWithTokens(userIdArg, userTypeArg);
  if (!recipient) {
    console.error(
      'FAIL: No account with FCM tokens found. Log in on the app first, or pass:\n' +
        '  node scripts/testNotification.js <userId> <userType>'
    );
    process.exit(1);
  }

  const { userId, userType } = recipient;
  console.log(`Sending test notification to userId=${userId} userType=${userType}`);

  const result = await sendNotificationToUser(userId, userType, {
    title: 'ISDR 2026 test',
    body: 'Push notifications are working.',
    type: 'general',
    data: { source: 'testNotification.js' },
  });

  if (result.success) {
    console.log('OK:', result);
    await mongoose.connection.close();
    process.exit(0);
  }

  console.error('FAIL:', result.error || result);
  await mongoose.connection.close();
  process.exit(1);
}

main().catch(async (err) => {
  console.error('FAIL:', err.message || err);
  try {
    await mongoose.connection.close();
  } catch (_) {}
  process.exit(1);
});
