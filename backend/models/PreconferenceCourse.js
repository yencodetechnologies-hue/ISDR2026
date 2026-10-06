const mongoose = require('mongoose');

/** One pre-conference course shown to participants and edited by management. */
const preconferenceCourseSchema = new mongoose.Schema(
  {
    apartmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Apartment',
      required: true,
      index: true,
    },
    serialNo: { type: Number, required: true, min: 1 },
    date: { type: String, required: true, trim: true },
    course: { type: String, required: true, trim: true },
    venue: { type: String, required: true, trim: true },
  },
  { timestamps: true }
);

preconferenceCourseSchema.index({ apartmentId: 1, serialNo: 1 }, { unique: true });

module.exports = mongoose.model('PreconferenceCourse', preconferenceCourseSchema);
