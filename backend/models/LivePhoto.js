const mongoose = require('mongoose');

/** The Live Photo gallery link the admin sets; shown as "Get your live photo" button across roles. */
const livePhotoSchema = new mongoose.Schema(
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

module.exports = mongoose.model('LivePhoto', livePhotoSchema);
