const mongoose = require('mongoose');

/** A shop/stall at the event, added by management and shown to participants. */
const exhibitorSchema = new mongoose.Schema(
  {
    apartmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Apartment',
      required: true,
      index: true,
    },
    shopName: { type: String, required: true, trim: true },
    photo: { type: String, default: '' },
    category: { type: String, required: true, trim: true },
    location: { type: String, required: true, trim: true },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Exhibitor', exhibitorSchema);
