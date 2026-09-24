const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

/**
 * A speaker, added by management on the Speakers page and picked from a
 * dropdown when adding a schedule. Logs in with mobile + password and sees
 * every schedule they're picked for.
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
    photo: { type: String, default: '' },
    mobileNumber: {
      type: String,
      required: [true, 'Mobile number is required'],
      trim: true,
      index: true,
    },
    password: {
      type: String,
      required: [true, 'Password is required'],
      minlength: [6, 'Password must be at least 6 characters'],
      select: false,
    },
    fcmTokens: { type: [String], default: [] },
  },
  { timestamps: true }
);

speakerSchema.pre('save', async function hashPassword(next) {
  if (!this.isModified('password')) return next();
  this.password = await bcrypt.hash(this.password, 10);
  next();
});

speakerSchema.methods.comparePassword = function comparePassword(plain) {
  return bcrypt.compare(plain, this.password);
};

module.exports = mongoose.model('Speaker', speakerSchema);
