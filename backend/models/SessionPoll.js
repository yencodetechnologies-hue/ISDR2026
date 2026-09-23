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
  },
  { timestamps: true }
);

module.exports = mongoose.model('SessionPoll', sessionPollSchema);
