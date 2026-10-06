const mongoose = require('mongoose');

/**
 * A question a participant asks a speaker directly (not tied to a session).
 * Admin answers it and can publish it. Until isPublic is on, only the asking
 * participant and admin see it. The public Q/A shows the latest answer.
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
    // When true, every participant sees this question and its current answer.
    isPublic: { type: Boolean, default: false },
  },
  { timestamps: true }
);

module.exports = mongoose.model('SpeakerQuestion', speakerQuestionSchema);
