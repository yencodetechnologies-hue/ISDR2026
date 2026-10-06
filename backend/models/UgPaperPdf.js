const mongoose = require('mongoose');

/** The UG paper and e-poster PDF. One per property, replaced when an admin uploads. */
const ugPaperPdfSchema = new mongoose.Schema(
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

module.exports = mongoose.model('UgPaperPdf', ugPaperPdfSchema);
