const mongoose = require('mongoose');

/**
 * A participant asked to be notified when a schedule (session) starts.
 * `startAt` is the session start as an instant; `sentAt` is set once pushed.
 */
const scheduleReminderSchema = new mongoose.Schema(
  {
    participantId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'EventRegistration',
      required: true,
    },
    scheduleId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'EventSchedule',
      required: true,
    },
    startAt: { type: Date, required: true },
    sentAt: { type: Date, default: null },
  },
  { timestamps: true }
);

scheduleReminderSchema.index({ participantId: 1, scheduleId: 1 }, { unique: true });
scheduleReminderSchema.index({ sentAt: 1, startAt: 1 });

module.exports = mongoose.model('ScheduleReminder', scheduleReminderSchema);
