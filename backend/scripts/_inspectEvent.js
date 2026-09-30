const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const connectDB = require('../config/database');
const ManagedEvent = require('../models/ManagedEvent');
const EventRegistration = require('../models/EventRegistration');

(async () => {
  await connectDB();
  const events = await ManagedEvent.find({ title: /ISDR/i })
    .select('title packages formQuestions bookedCount')
    .lean();
  console.log(
    JSON.stringify(
      events.map((e) => ({
        id: e._id,
        title: e.title,
        bookedCount: e.bookedCount,
        packages: e.packages,
        formQuestions: e.formQuestions,
      })),
      null,
      2
    )
  );
  const types = await EventRegistration.distinct('participantType');
  console.log('TYPES', types);
  const pkgs = await EventRegistration.distinct('packageName');
  console.log('PKGS', pkgs);
  const mobiles = ['9445272783', '9080361259', '9025483437', '9821188954'];
  const emails = [
    'preethishree1509@gmail.com',
    'sharishkanna3003@gmail.com',
    'alagusoundari28@gmail.com',
    'draadyabatra@gmail.com',
  ];
  const existing = await EventRegistration.find({
    $or: [{ mobileNumber: { $in: mobiles } }, { email: { $in: emails } }],
  })
    .select('name email mobileNumber participantType packageName eventId idNumber')
    .lean();
  console.log('EXISTING', existing);
  process.exit(0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
