const mongoose = require('mongoose');

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
    name: { type: String, required: true, trim: true },
    mobileNumber: { type: String, required: true, trim: true, index: true },
    email: { type: String, default: '', trim: true, lowercase: true },
    institution: { type: String, default: '', trim: true },
    title: { type: String, enum: ['', 'Dr', 'Mr', 'Ms', 'Prof', 'Baby'], default: '' },
    firstName: { type: String, default: '', trim: true },
    middleName: { type: String, default: '', trim: true },
    lastName: { type: String, default: '', trim: true },
    gender: { type: String, enum: ['', 'male', 'female', 'other'], default: '' },
    participantType: { type: String, default: '', trim: true, maxlength: 60 },
    designation: { type: String, default: '', trim: true },
    idNumber: { type: String, default: '', trim: true },
    address: { type: String, default: '', trim: true },
    photoUrl: { type: String, default: '' },
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
    otp: { type: String, required: true },
    qrCode: { type: String, required: true },
    ticketCode: { type: String, required: true, unique: true, index: true },
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
      },
    ],
  },
  { timestamps: true }
);

eventRegistrationSchema.index({ eventId: 1, mobileNumber: 1 }, { unique: true });

eventRegistrationSchema.set('toJSON', {
  transform(_doc, ret) {
    ret.id = ret._id?.toString();
    delete ret.__v;
    return ret;
  },
});

module.exports = mongoose.model('EventRegistration', eventRegistrationSchema);
