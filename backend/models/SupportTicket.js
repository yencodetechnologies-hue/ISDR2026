const mongoose = require('mongoose');

const CATEGORIES = ['emergency', 'medical', 'others', 'app'];

const messageSchema = new mongoose.Schema(
  {
    // 'participant' | 'staff' | 'admin'
    senderType: { type: String, required: true },
    senderId: { type: mongoose.Schema.Types.ObjectId, required: true },
    senderName: { type: String, default: '' },
    text: { type: String, required: true, trim: true },
  },
  { timestamps: true }
);

/**
 * A participant's Help & Support ticket. The description is the first chat
 * message; event staff and admin reply in the same chat.
 */
const supportTicketSchema = new mongoose.Schema(
  {
    apartmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Apartment',
      required: true,
      index: true,
    },
    participantId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'EventRegistration',
      required: true,
      index: true,
    },
    participantName: { type: String, default: '' },
    category: { type: String, enum: CATEGORIES, required: true },
    description: { type: String, required: true, trim: true },
    messages: { type: [messageSchema], default: [] },
    // Staff/admin close it; the participant can then only read it.
    status: { type: String, enum: ['open', 'closed'], default: 'open' },
    closedAt: { type: Date, default: null },
    closedByName: { type: String, default: '' },
    lastMessageAt: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

supportTicketSchema.statics.CATEGORIES = CATEGORIES;

module.exports = mongoose.model('SupportTicket', supportTicketSchema);
