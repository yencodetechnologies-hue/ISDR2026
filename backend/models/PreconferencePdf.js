const mongoose = require('mongoose');

/** Preconference PDF. One per property, replaced when an admin uploads. */
const preconferencePdfSchema = new mongoose.Schema(
  {
    apartmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Apartment',
      required: true,
      unique: true,
    },
    fileName: { type: String, default: '', trim: true },
    // Cloudinary delivery URL. Empty until an admin uploads a PDF.
    url: { type: String, default: '' },
    publicId: { type: String, default: '' },
  },
  { timestamps: true }
);

module.exports = mongoose.model('PreconferencePdf', preconferencePdfSchema);
