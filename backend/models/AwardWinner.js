const mongoose = require('mongoose');

/** One ranked recipient. Names are typed by an admin; they are not taken from registrations. */
const awardRecipientSchema = new mongoose.Schema(
  {
    rank: { type: Number, required: true, min: 1 },
    name: { type: String, required: true, trim: true },
  },
  { _id: false }
);

/** Ranked recipients for one award category. One document per apartment + award number. */
const awardWinnerSchema = new mongoose.Schema(
  {
    apartmentId: { type: mongoose.Schema.Types.ObjectId, ref: 'Apartment', required: true },
    awardNumber: { type: Number, required: true, min: 1 },
    /** Rank-1 name, kept so older clients still show a recipient. */
    name: { type: String, trim: true, default: '' },
    recipients: { type: [awardRecipientSchema], default: [] },
  },
  { timestamps: true }
);

awardWinnerSchema.index({ apartmentId: 1, awardNumber: 1 }, { unique: true });

module.exports = mongoose.model('AwardWinner', awardWinnerSchema);
