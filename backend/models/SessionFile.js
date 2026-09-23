const mongoose = require('mongoose');

/** A PDF or PPT a speaker uploaded to one of their sessions (schedule rows). */
const sessionFileSchema = new mongoose.Schema(
  {
    scheduleId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'EventSchedule',
      required: true,
      index: true,
    },
    apartmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Apartment',
      required: true,
    },
    kind: { type: String, enum: ['pdf', 'ppt'], required: true },
    name: { type: String, required: true, trim: true },
    url: { type: String, required: true },
    publicId: { type: String, default: '' }, // Cloudinary id, used to delete the file
    size: { type: Number, default: 0 },
  },
  { timestamps: true }
);

module.exports = mongoose.model('SessionFile', sessionFileSchema);
