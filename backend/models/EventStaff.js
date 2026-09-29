const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

/** Event staff account, added by management and able to log in to the app. */
const eventStaffSchema = new mongoose.Schema(
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
    username: { type: String, required: true, unique: true, trim: true, lowercase: true },
    email: {
      type: String,
      trim: true,
      lowercase: true,
      default: '',
      match: [/^$|^\S+@\S+\.\S+$/, 'Please enter a valid email'],
    },
    mobileNumber: { type: String, required: [true, 'Mobile number is required'], trim: true },
    secondaryMobileNumber: { type: String, default: '' },
    gender: { type: String, enum: ['', 'male', 'female', 'other'], default: '' },
    password: {
      type: String,
      required: [true, 'Password is required'],
      minlength: [6, 'Password must be at least 6 characters'],
      select: false,
    },
    status: { type: String, enum: ['pending', 'approved', 'rejected'], default: 'approved' },
    isActive: { type: Boolean, default: true },
    profilePic: { type: String, default: '' },
    address: { type: String, default: '' },
    aadhaarCard: { type: String, default: '' },
    aadhaarCardFrontImage: { type: String, default: '' },
    aadhaarCardBackImage: { type: String, default: '' },
    panCard: { type: String, default: '' },
    panCardImage: { type: String, default: '' },
    fcmTokens: { type: [String], default: [] },
  },
  { timestamps: true }
);

eventStaffSchema.pre('save', async function hashPassword(next) {
  if (!this.isModified('password')) return next();
  this.password = await bcrypt.hash(this.password, 10);
  next();
});

eventStaffSchema.methods.comparePassword = function comparePassword(plain) {
  return bcrypt.compare(plain, this.password);
};

module.exports = mongoose.model('EventStaff', eventStaffSchema);
