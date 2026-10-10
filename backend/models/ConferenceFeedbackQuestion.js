const mongoose = require('mongoose');

/** One conference-feedback question for a property. Answers are stored by `key`. */
const conferenceFeedbackQuestionSchema = new mongoose.Schema(
  {
    apartmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Apartment',
      required: true,
      index: true,
    },
    key: { type: String, required: true, trim: true },
    section: { type: String, required: true, trim: true },
    prompt: { type: String, required: true, trim: true },
    type: { type: String, enum: ['choice', 'text'], required: true },
    required: { type: Boolean, default: false },
    options: { type: [String], default: [] },
    multiline: { type: Boolean, default: false },
    order: { type: Number, default: 0 },
  },
  { timestamps: true }
);

conferenceFeedbackQuestionSchema.index({ apartmentId: 1, key: 1 }, { unique: true });
conferenceFeedbackQuestionSchema.index({ apartmentId: 1, order: 1 });

module.exports = mongoose.model('ConferenceFeedbackQuestion', conferenceFeedbackQuestionSchema);
