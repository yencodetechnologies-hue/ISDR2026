const mongoose = require('mongoose');

/** The programme PDF shown when a participant opens Schedule. One per property. */
const schedulePdfSchema = new mongoose.Schema(
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

module.exports = mongoose.model('SchedulePdf', schedulePdfSchema);
