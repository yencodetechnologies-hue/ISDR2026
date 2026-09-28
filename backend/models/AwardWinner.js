const mongoose = require('mongoose');

/** The participant the admin chose as the winner of one award category (1–12). */
const awardWinnerSchema = new mongoose.Schema(
  {
    apartmentId: { type: mongoose.Schema.Types.ObjectId, ref: 'Apartment', required: true },
    awardNumber: { type: Number, required: true, min: 1 },
    registrationId: { type: mongoose.Schema.Types.ObjectId, ref: 'EventRegistration', required: true },
    name: { type: String, required: true, trim: true },
  },
  { timestamps: true }
);

awardWinnerSchema.index({ apartmentId: 1, awardNumber: 1 }, { unique: true });

module.exports = mongoose.model('AwardWinner', awardWinnerSchema);
