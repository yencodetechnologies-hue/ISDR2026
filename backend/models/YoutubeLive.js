const mongoose = require('mongoose');

/** The YouTube live link the admin sets; shown as a capsule on the participant home. */
const youtubeLiveSchema = new mongoose.Schema(
  {
    apartmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Apartment',
      required: true,
      unique: true,
    },
    url: { type: String, default: '', trim: true },
  },
  { timestamps: true }
);

module.exports = mongoose.model('YoutubeLive', youtubeLiveSchema);
