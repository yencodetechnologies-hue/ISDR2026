const mongoose = require('mongoose');

/** The text shown before an admin has set their own (one message per line). */
const DEFAULT_TICKER_TEXT = [
  'Welcome to ISDR 2026 — 36th International Conference',
  'IADR Indian Division',
  'Register your sessions and claim your inclusions on time',
].join('\n');

/**
 * The scrolling news ticker on the participant and event staff homes. One per
 * property: admin switches it on/off and edits the text (one message per line).
 */
const newsTickerSchema = new mongoose.Schema(
  {
    apartmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Apartment',
      required: true,
      unique: true,
    },
    enabled: { type: Boolean, default: true },
    text: { type: String, default: DEFAULT_TICKER_TEXT, trim: true },
  },
  { timestamps: true }
);

newsTickerSchema.statics.DEFAULT_TEXT = DEFAULT_TICKER_TEXT;

module.exports = mongoose.model('NewsTicker', newsTickerSchema);
