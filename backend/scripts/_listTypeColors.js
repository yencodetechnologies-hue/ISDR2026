const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const connectDB = require('../config/database');
const EventRegistration = require('../models/EventRegistration');

(async () => {
  await connectDB();
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
    console.log(String(r.n).padStart(5), '|', JSON.stringify(r._id.type), '|', r._id.color);
  }
  process.exit(0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
