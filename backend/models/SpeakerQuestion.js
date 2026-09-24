const mongoose = require('mongoose');

/**
 * A question a participant asks a speaker directly (not tied to a session).
 * Private: only the asking participant and that speaker see it. The speaker
 * answers once; the answer is final.
 */
const speakerQuestionSchema = new mongoose.Schema(
  {
    apartmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Apartment',
      required: true,
    },
    speakerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Speaker',
      required: true,
      index: true,
    },
    participantId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'EventRegistration',
      required: true,
      index: true,
    },
    participantName: { type: String, default: '' },
    question: { type: String, required: true, trim: true },
    answer: { type: String, default: '', trim: true },
    answeredAt: { type: Date, default: null },
  },
  { timestamps: true }
);

module.exports = mongoose.model('SpeakerQuestion', speakerQuestionSchema);
