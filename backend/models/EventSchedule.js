const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

/**
 * A session on an event's schedule (speaker name + time slot). The speaker is
 * typed on the schedule; speakerId is only set on older rows linked to an account.
 */
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
    // Older schedules linked a speaker account. New ones store only the typed name.
    speakerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Speaker', default: null, index: true },
    speakerName: { type: String, required: true, trim: true },
    speakerPhoto: { type: String, default: '' },
    // Legacy: older schedules carried their speaker's own login.
    speakerMobile: { type: String, default: '', trim: true, index: true },
    speakerPassword: { type: String, default: '', select: false },
    fcmTokens: { type: [String], default: [] },
    scheduleName: { type: String, required: true, trim: true },
    // Event package ids whose participants see this schedule; empty = everyone.
    packageIds: { type: [String], default: [] },
    hall: { type: String, default: '', trim: true },
    date: { type: Date, required: true },
    fromTime: { type: String, required: true, trim: true }, // "HH:mm"
    toTime: { type: String, required: true, trim: true }, // "HH:mm"
    description: { type: String, default: '', trim: true },
  },
  { timestamps: true }
);

eventScheduleSchema.pre('save', async function hashSpeakerPassword(next) {
  if (!this.isModified('speakerPassword') || !this.speakerPassword) return next();
  this.speakerPassword = await bcrypt.hash(this.speakerPassword, 10);
  next();
});

eventScheduleSchema.methods.comparePassword = function comparePassword(plain) {
  if (!this.speakerPassword) return Promise.resolve(false);
  return bcrypt.compare(plain, this.speakerPassword);
};

module.exports = mongoose.model('EventSchedule', eventScheduleSchema);
