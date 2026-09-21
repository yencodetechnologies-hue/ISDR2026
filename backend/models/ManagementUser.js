const mongoose = require('mongoose');

/** Co-management ID (team member) that can log in to the same property. */
const managementUserSchema = new mongoose.Schema(
  {
    apartmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Apartment',
      required: true,
      index: true,
    },
    name: {
      type: String,
      required: [true, 'Name is required'],
      trim: true,
    },
    mobileNumber: {
      type: String,
      required: [true, 'Mobile number is required'],
      trim: true,
      match: [/^[0-9]{10}$/, 'Please enter a valid 10-digit mobile number'],
    },
    email: {
      type: String,
      trim: true,
      lowercase: true,
      default: '',
    },
    roleTitle: {
      type: String,
      trim: true,
      default: 'Management Member',
    },
    password: {
      type: String,
      required: [true, 'Password is required'],
      minlength: [6, 'Password must be at least 6 characters'],
      select: false,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    fcmTokens: {
      type: [String],
      default: [],
    },
  },
  { timestamps: true }
);

// A mobile number is unique per property for the management team
managementUserSchema.index({ apartmentId: 1, mobileNumber: 1 }, { unique: true });

module.exports = mongoose.model('ManagementUser', managementUserSchema);
