const mongoose = require('mongoose');

/** A session on an event's schedule (speaker + time slot). */
const eventScheduleSchema = new mongoose.Schema(
  {
    eventId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'ManagedEvent',
      required: true,
      index: true,
    },
    apartmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Apartment',
      required: true,
      index: true,
    },
    speakerName: { type: String, required: true, trim: true },
    speakerPhoto: { type: String, default: '' },
    scheduleName: { type: String, required: true, trim: true },
    hall: { type: String, default: '', trim: true },
    date: { type: Date, required: true },
    fromTime: { type: String, required: true, trim: true }, // "HH:mm"
    toTime: { type: String, required: true, trim: true }, // "HH:mm"
    description: { type: String, default: '', trim: true },
  },
  { timestamps: true }
);

module.exports = mongoose.model('EventSchedule', eventScheduleSchema);
