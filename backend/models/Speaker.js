const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

/**
 * A speaker, added by management on the Speakers page and picked from a
 * dropdown when adding a schedule. A name is enough. Mobile + password are
 * optional and only needed when that speaker should log in. askEnabled
 * controls whether participants can send them a question.
 */
const speakerSchema = new mongoose.Schema(
  {
    apartmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Apartment',
      required: true,
      index: true,
    },
    name: { type: String, required: [true, 'Name is required'], trim: true },
    // QR pass number (ADM0001 / SPK0001 / STF0001…), assigned by utils/passNumber.js.
    passNumber: { type: String, default: '', trim: true },
    photo: { type: String, default: '' },
    mobileNumber: {
      type: String,
      default: '',
      trim: true,
      index: true,
    },
    password: {
      type: String,
      select: false,
    },
    // Off until management turns this speaker on for "Ask a Speaker".
    askEnabled: { type: Boolean, default: false },
    fcmTokens: { type: [String], default: [] },
  },
  { timestamps: true }
);

speakerSchema.pre('save', async function hashPassword(next) {
  if (!this.isModified('password') || !this.password) return next();
  this.password = await bcrypt.hash(this.password, 10);
  next();
});

speakerSchema.methods.comparePassword = function comparePassword(plain) {
  if (!this.password) return Promise.resolve(false);
  return bcrypt.compare(plain, this.password);
};

module.exports = mongoose.model('Speaker', speakerSchema);
