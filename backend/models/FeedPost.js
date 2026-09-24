const mongoose = require('mongoose');

// A selfie posted by a participant, visible to every participant of the
// event (no per-participant restriction on who can see it).
const feedPostSchema = new mongoose.Schema(
  {
    apartmentId: { type: mongoose.Schema.Types.ObjectId, ref: 'Apartment', required: true, index: true },
    eventId: { type: mongoose.Schema.Types.ObjectId, ref: 'ManagedEvent', index: true },
    participantId: { type: mongoose.Schema.Types.ObjectId, ref: 'EventRegistration', required: true },
    participantName: { type: String, default: '' },
    participantPhoto: { type: String, default: '' },
    imageUrl: { type: String, required: true },
    // Ids of the accounts that liked the post (one like per account).
    likes: { type: [mongoose.Schema.Types.ObjectId], default: [] },
  },
  { timestamps: true }
);

feedPostSchema.set('toJSON', {
  transform(_doc, ret) {
    ret.id = ret._id?.toString();
    delete ret.__v;
    return ret;
  },
});

module.exports = mongoose.model('FeedPost', feedPostSchema);
