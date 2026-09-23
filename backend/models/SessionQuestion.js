const mongoose = require('mongoose');

const answerSchema = new mongoose.Schema(
  {
    participantId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'EventRegistration',
      required: true,
    },
    participantName: { type: String, default: '' },
    text: { type: String, required: true, trim: true },
  },
  { _id: false, timestamps: true }
);

/** A question a speaker asked on one of their sessions; participants type one answer. */
const sessionQuestionSchema = new mongoose.Schema(
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
    answers: { type: [answerSchema], default: [] },
  },
  { timestamps: true }
);

module.exports = mongoose.model('SessionQuestion', sessionQuestionSchema);
