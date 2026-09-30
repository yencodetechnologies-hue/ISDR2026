const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const connectDB = require('../config/database');
const EventRegistration = require('../models/EventRegistration');

(async () => {
  await connectDB();
  const samples = await EventRegistration.find({
    participantType: /student delegate/i,
  })
    .select('participantType participantTypeColor packageName')
    .limit(10)
    .lean();
  console.log(JSON.stringify(samples, null, 2));
  process.exit(0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
