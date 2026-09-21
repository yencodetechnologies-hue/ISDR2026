const mongoose = require('mongoose');

/**
 * A notification the management sent to the participants of an event, optionally narrowed to one
 * package and/or one inclusion. Delivery to participants' devices is added separately; this keeps
 * what was sent and who it targeted.
 */
const eventNotificationSchema = new mongoose.Schema(
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
    packageId: { type: String, default: '' },
    packageName: { type: String, default: '' },
    inclusionName: { type: String, default: '' },
    message: { type: String, required: true, trim: true },
    recipientIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'EventRegistration' }],
    recipientCount: { type: Number, default: 0 },
  },
  { timestamps: true }
);

module.exports = mongoose.model('EventNotification', eventNotificationSchema);
