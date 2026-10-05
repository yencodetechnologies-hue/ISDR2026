const mongoose = require('mongoose');
const crypto = require('crypto');

const formQuestionSchema = new mongoose.Schema(
  {
    id: { type: String, required: true, trim: true },
    label: { type: String, required: true, trim: true },
    type: {
      type: String,
      enum: ['short_text', 'long_text', 'single_choice', 'checkboxes'],
      required: true,
    },
    required: { type: Boolean, default: false },
    options: { type: [String], default: [] },
    order: { type: Number, default: 0 },
  },
  { _id: false }
);

const packageInclusionSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    // 'YYYY-MM-DD' strings for the event days this inclusion is offered on.
    // Empty = not offered on any day (the details-page day ticks are the source of truth).
    dates: { type: [String], default: [] },
  },
  { _id: false }
);

const packageSchema = new mongoose.Schema(
  {
    id: { type: String, required: true, trim: true },
    name: { type: String, required: true, trim: true },
    rate: { type: Number, required: true, min: 0 },
    entryExitDates: { type: [String], default: [] },
    inclusions: { type: [packageInclusionSchema], default: [] },
    paymentMode: { type: String, enum: ['', 'cash', 'card', 'upi'], default: '' },
  },
  { _id: false }
);

const managedEventSchema = new mongoose.Schema(
  {
    apartmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Apartment',
      required: true,
      index: true,
    },
    title: { type: String, required: true, trim: true },
    description: { type: String, default: '', trim: true },
    venue: { type: String, default: '', trim: true },
    photoUrl: { type: String, default: '', trim: true },
    eventDate: { type: Date, required: true },
    eventEndDate: { type: Date, default: null },
    bookedCount: { type: Number, default: 0, min: 0 },
    // Omitted (not just null) for properties whose type is "events" — those
    // don't expose a public self-registration link/page for their events.
    // Must stay unset (not null) so the sparse unique index below allows
    // any number of events without a slug.
    publicSlug: {
      type: String,
      unique: true,
      sparse: true,
      trim: true,
    },
    formQuestions: { type: [formQuestionSchema], default: [] },
    packages: { type: [packageSchema], default: [] },
    status: {
      type: String,
      enum: ['draft', 'published', 'cancelled', 'completed'],
      default: 'published',
    },
    isActive: { type: Boolean, default: true },
    createdBy: { type: mongoose.Schema.Types.ObjectId, default: null },
  },
  { timestamps: true }
);

managedEventSchema.statics.generateSlug = function () {
  return crypto.randomBytes(6).toString('hex');
};

managedEventSchema.set('toJSON', {
  virtuals: true,
  transform(_doc, ret) {
    ret.id = ret._id?.toString();
    delete ret.__v;
    return ret;
  },
});

module.exports = mongoose.model('ManagedEvent', managedEventSchema);
