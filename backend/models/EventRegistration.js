const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const answerSchema = new mongoose.Schema(
  {
    questionId: { type: String, required: true, trim: true },
    label: { type: String, default: '', trim: true },
    type: {
      type: String,
      enum: ['short_text', 'long_text', 'single_choice', 'checkboxes'],
      required: true,
    },
    value: { type: mongoose.Schema.Types.Mixed, default: '' },
  },
  { _id: false }
);

const eventRegistrationSchema = new mongoose.Schema(
  {
    eventId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'ManagedEvent',
      required: true,
      index: true,
    },
    apartmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Apartment',
      required: true,
      index: true,
    },
    name: { type: String, default: '', trim: true },
    mobileNumber: { type: String, required: true, trim: true, index: true },
    email: { type: String, default: '', trim: true, lowercase: true },
    institution: { type: String, default: '', trim: true },
    title: { type: String, enum: ['', 'Dr', 'Mr', 'Mrs', 'Ms', 'Prof'], default: '' },
    firstName: { type: String, default: '', trim: true, uppercase: true },
    middleName: { type: String, default: '', trim: true, uppercase: true },
    lastName: { type: String, default: '', trim: true, uppercase: true },
    gender: { type: String, enum: ['', 'male', 'female', 'other'], default: '' },
    participantType: { type: String, default: '', trim: true, maxlength: 60 },
    // Hex colour of the banner behind the participant type on the badge ('' = default #167E5D).
    participantTypeColor: { type: String, default: '', trim: true },
    designation: { type: String, default: '', trim: true },
    idNumber: { type: String, default: '', trim: true, index: true },
    address: { type: String, default: '', trim: true },
    photoUrl: { type: String, default: '' },
    // Schedules the participant hearted — shown on their Favorites page.
    favoriteSchedules: { type: [mongoose.Schema.Types.ObjectId], ref: 'EventSchedule', default: [] },
    foodPreference: { type: String, enum: ['', 'veg', 'non-veg'], default: '' },
    paymentMode: { type: String, enum: ['', 'cash', 'card', 'upi'], default: '' },
    utrNumber: { type: String, default: '', trim: true },
    packageId: { type: String, default: '' },
    packageName: { type: String, default: '' },
    source: {
      type: String,
      enum: ['public', 'spot', 'bulk'],
      default: 'public',
    },
    answers: { type: [answerSchema], default: [] },
    userId: { type: mongoose.Schema.Types.ObjectId, default: null },
    // Login password for the participant app. Every participant is given the same
    // default ('123456') at creation; select:false keeps it out of normal reads.
    password: { type: String, default: '', select: false },
    // Device tokens for push notifications (set at login / app start).
    fcmTokens: { type: [String], default: [] },
    otp: { type: String, required: true },
    qrCode: { type: String, required: true },
    status: {
      type: String,
      enum: ['registered', 'checked_in', 'cancelled'],
      default: 'registered',
      index: true,
    },
    checkedInAt: { type: Date, default: null },
    checkedInBy: { type: mongoose.Schema.Types.ObjectId, default: null },
    claimedInclusions: [
      {
        inclusionName: { type: String, required: true, trim: true },
        claimedAt: { type: Date, default: Date.now },
        claimedBy: { type: mongoose.Schema.Types.ObjectId, default: null },
        // True when management manually re-registered this claim (e.g. after a
        // mis-scan) rather than the participant claiming it themselves.
        reclaimedByAdmin: { type: Boolean, default: false },
      },
    ],
    // Entry/exit scans, one row per event day (YYYY-MM-DD, India time).
    attendance: [
      {
        day: { type: String, required: true },
        entryAt: { type: Date, default: null },
        entryBy: { type: mongoose.Schema.Types.ObjectId, default: null },
        exitAt: { type: Date, default: null },
        exitBy: { type: mongoose.Schema.Types.ObjectId, default: null },
      },
    ],
    // Admin unlocked the certificate without the required scans.
    certificateUnlocked: { type: Boolean, default: false },
    certificateUnlockedAt: { type: Date, default: null },
    // Admin reverted the certificate: it stays locked even if the scans earn it.
    certificateRevoked: { type: Boolean, default: false },
    // Conference feedback. The participant certificate stays locked until this is submitted.
    conferenceFeedback: { type: mongoose.Schema.Types.Mixed, default: null },
    conferenceFeedbackAt: { type: Date, default: null },
  },
  { timestamps: true }
);

eventRegistrationSchema.index({ eventId: 1, mobileNumber: 1 }, { unique: true });
eventRegistrationSchema.index({ eventId: 1, idNumber: 1 });
eventRegistrationSchema.index({ eventId: 1, createdAt: -1 });

eventRegistrationSchema.pre('save', async function hashPassword(next) {
  if (!this.isModified('password') || !this.password) return next();
  this.password = await bcrypt.hash(this.password, 10);
  next();
});

eventRegistrationSchema.methods.comparePassword = function comparePassword(plain) {
  return bcrypt.compare(plain, this.password || '');
};

eventRegistrationSchema.set('toJSON', {
  transform(_doc, ret) {
    ret.id = ret._id?.toString();
    delete ret.__v;
    return ret;
  },
});

module.exports = mongoose.model('EventRegistration', eventRegistrationSchema);
