const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

/**
 * The Event Management property account (management login).
 * There is exactly one kind of property: `events`.
 */
const apartmentSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, 'Name is required'],
      trim: true,
    },
    address: {
      type: String,
      default: '',
      trim: true,
    },
    contactPhone: {
      type: String,
      default: '',
      trim: true,
      unique: true,
      sparse: true,
    },
    password: {
      type: String,
      required: [
        function () {
          return this.isNew || this.isModified('password');
        },
        'Password is required',
      ],
      minlength: [6, 'Password must be at least 6 characters'],
      select: false,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    subscriptionStatus: {
      type: Boolean,
      default: false,
    },
    subscriptionEndsAt: {
      type: Date,
      default: null,
    },
    subscriptionPlanId: {
      type: mongoose.Schema.Types.ObjectId,
      default: null,
    },
    fcmTokens: {
      type: [String],
      default: [],
    },
    securityEnabled: { type: Boolean, default: true },
    assignPaymentEnabled: { type: Boolean, default: true },
    complaintsEnabled: { type: Boolean, default: true },
    showUserMobile: { type: Boolean, default: true },
    blockCreationEnabled: { type: Boolean, default: true },
    addUserEnabled: { type: Boolean, default: true },
    wardenFacilityEnabled: { type: Boolean, default: false },
    supportEnabled: { type: Boolean, default: false },
    adsEnabled: { type: Boolean, default: true },
    propertyType: {
      type: String,
      enum: ['events'],
      default: 'events',
    },
    /** Event organizer name */
    ownerName: { type: String, trim: true, default: '' },
    email: { type: String, trim: true, lowercase: true, default: '' },
  },
  {
    timestamps: true,
  }
);

// Hash password before saving
apartmentSchema.pre('save', async function (next) {
  if (!this.isModified('password')) {
    return next();
  }
  const salt = await bcrypt.genSalt(10);
  this.password = await bcrypt.hash(this.password, salt);
  next();
});

// Compare password method
apartmentSchema.methods.comparePassword = async function (enteredPassword) {
  if (!this.password) return false;
  return bcrypt.compare(enteredPassword, this.password);
};

apartmentSchema.set('toJSON', {
  transform: function (doc, ret) {
    ret.id = ret._id.toString();
    delete ret._id;
    delete ret.__v;
    delete ret.password;
    return ret;
  },
});

module.exports = mongoose.model('Apartment', apartmentSchema);
