const mongoose = require('mongoose');

// One row per rejected inclusion scan (denied or already used), so management can see
// how many scans were rejected and which staff member scanned them.
const eventClaimAttemptSchema = new mongoose.Schema(
  {
    eventId: { type: mongoose.Schema.Types.ObjectId, ref: 'ManagedEvent', required: true, index: true },
    apartmentId: { type: mongoose.Schema.Types.ObjectId, ref: 'Apartment', index: true },
    registrationId: { type: mongoose.Schema.Types.ObjectId, ref: 'EventRegistration' },
    participantName: { type: String, default: '' },
    ticketCode: { type: String, default: '' },
    inclusionName: { type: String, default: '' },
    outcome: { type: String, enum: ['denied', 'already_used'], required: true },
    reason: { type: String, default: '' },
    rejectedById: { type: mongoose.Schema.Types.ObjectId },
    rejectedByName: { type: String, default: '' },
  },
  { timestamps: true }
);

module.exports = mongoose.model('EventClaimAttempt', eventClaimAttemptSchema);
