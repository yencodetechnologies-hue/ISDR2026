const mongoose = require('mongoose');

/**
 * One in-app notification for one account (what the Notifications screen
 * lists). Every push sent through utils/fcmService is also stored here.
 */
const notificationSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      required: [true, 'User ID is required'],
      index: true,
    },
    // apartment = admin login, management = Admin ID, user = event staff,
    // participant, speaker
    userType: {
      type: String,
      required: [true, 'User type is required'],
      enum: ['apartment', 'management', 'user', 'participant', 'speaker'],
      index: true,
    },
    title: {
      type: String,
      required: [true, 'Notification title is required'],
      trim: true,
    },
    body: {
      type: String,
      required: [true, 'Notification body is required'],
      trim: true,
    },
    type: {
      type: String,
      enum: ['support_ticket', 'schedule_reminder', 'event_notification', 'message', 'general'],
      default: 'general',
      index: true,
    },
    data: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
    },
    read: {
      type: Boolean,
      default: false,
      index: true,
    },
    apartmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Apartment',
      default: null,
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

// Compound index for efficient queries
notificationSchema.index({ userId: 1, userType: 1, read: 1, createdAt: -1 });
notificationSchema.index({ apartmentId: 1, createdAt: -1 });

notificationSchema.set('toJSON', {
  transform: function (doc, ret) {
    ret.id = ret._id.toString();
    delete ret._id;
    delete ret.__v;
    return ret;
  },
});

module.exports = mongoose.model('Notification', notificationSchema);
