const mongoose = require('mongoose');

/**
 * A participant's 1–5 star rating (and optional comment) for one session.
 * One per participant per session, final once submitted. Only the session's
 * speaker sees them (with names).
 */
const sessionRatingSchema = new mongoose.Schema(
  {
    scheduleId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'EventSchedule',
      required: true,
      index: true,
    },
    apartmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Apartment',
      required: true,
    },
    participantId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'EventRegistration',
      required: true,
    },
    participantName: { type: String, default: '' },
    stars: { type: Number, required: true, min: 1, max: 5 },
    comment: { type: String, default: '', trim: true },
  },
  { timestamps: true }
);

sessionRatingSchema.index({ scheduleId: 1, participantId: 1 }, { unique: true });

module.exports = mongoose.model('SessionRating', sessionRatingSchema);
