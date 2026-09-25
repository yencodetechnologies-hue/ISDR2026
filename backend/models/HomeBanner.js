const mongoose = require('mongoose');

/**
 * The image banner on the participant home (where the Next Session card was).
 * One per property: admin adds/deletes images and switches the whole banner
 * on or off.
 */
const homeBannerSchema = new mongoose.Schema(
  {
    apartmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Apartment',
      required: true,
      unique: true,
    },
    enabled: { type: Boolean, default: true },
    images: {
      type: [
        new mongoose.Schema(
          { url: { type: String, required: true } },
          { timestamps: true }
        ),
      ],
      default: [],
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('HomeBanner', homeBannerSchema);
