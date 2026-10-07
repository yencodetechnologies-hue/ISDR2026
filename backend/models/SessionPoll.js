const mongoose = require('mongoose');

const voteSchema = new mongoose.Schema(
  {
    participantId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'EventRegistration',
      required: true,
    },
    option: { type: Number, required: true }, // index into the poll's options
  },
  { _id: false, timestamps: true }
);

/** A poll a speaker created on one of their sessions; participants vote once. */
const sessionPollSchema = new mongoose.Schema(
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
    question: { type: String, required: true, trim: true },
    options: { type: [String], required: true },
    votes: { type: [voteSchema], default: [] },
    // Set on the ISDR session-feedback polls so a re-seed updates the same
    // poll. Speaker-created polls leave this unset.
    templateKey: { type: String, trim: true },
  },
  { timestamps: true }
);

// Speaker polls have no templateKey, so they stay out of this index.
sessionPollSchema.index(
  { scheduleId: 1, templateKey: 1 },
  { unique: true, partialFilterExpression: { templateKey: { $type: 'string' } } }
);

module.exports = mongoose.model('SessionPoll', sessionPollSchema);
