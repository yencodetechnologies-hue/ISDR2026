/**
 * Creates the fixed Event Management (management login) account once.
 *
 * Usage:
 *   node scripts/createManagementAccount.js --name "Test" --email test@example.com --mobile 1234567890 --password secret123
 */
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const mongoose = require('mongoose');
const connectDB = require('../config/database');
const Apartment = require('../models/Apartment');

function arg(name) {
  const i = process.argv.indexOf(`--${name}`);
  return i !== -1 ? process.argv[i + 1] : undefined;
}

(async () => {
  const name = (arg('name') || '').trim();
  const email = (arg('email') || '').trim().toLowerCase();
  const mobile = (arg('mobile') || '').trim();
  const password = arg('password') || '';

  if (!name || !email || !/^[0-9]{10}$/.test(mobile) || password.length < 6) {
    console.error(
      'Usage: node scripts/createManagementAccount.js --name <name> --email <email> --mobile <10 digits> --password <min 6 chars>'
    );
    process.exit(1);
  }

  await connectDB();

  const existing = await Apartment.findOne({ $or: [{ email }, { contactPhone: mobile }] });
  if (existing) {
    console.log(`Account already exists: ${existing.name} (${existing.email || existing.contactPhone}). Nothing changed.`);
    await mongoose.disconnect();
    return;
  }

  const account = await Apartment.create({
    name,
    ownerName: name,
    email,
    contactPhone: mobile,
    password,
    propertyType: 'events',
  });

  console.log(`Created management account: ${account.name}`);
  console.log(`  id:     ${account._id}`);
  console.log(`  email:  ${account.email}`);
  console.log(`  mobile: ${account.contactPhone}`);
  await mongoose.disconnect();
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
