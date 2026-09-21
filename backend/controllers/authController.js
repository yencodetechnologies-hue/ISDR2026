const bcrypt = require('bcryptjs');
const Apartment = require('../models/Apartment');
const ManagementUser = require('../models/ManagementUser');
const generateToken = require('../utils/generateToken');
const EventStaff = require('../models/EventStaff');
const { buildStaffPayload } = require('./staffController');
const { uploadToCloudinary } = require('../middleware/upload');

const EMAIL_REGEX = /^\S+@\S+\.\S+$/;

/** Last 10 digits of a phone-like string, or '' if there are fewer than 10 digits. */
function normalizeMobile10(raw) {
  const digits = String(raw ?? '').replace(/\D/g, '');
  return digits.length >= 10 ? digits.slice(-10) : '';
}

/** Find the management account by email or mobile: the property itself or a ManagementUser. */
async function findManagementAccount(rawId) {
  const identifier = String(rawId ?? '').trim();
  if (!identifier) return null;

  if (identifier.includes('@')) {
    const emailLower = identifier.toLowerCase();

    const apartment = await Apartment.findOne({ email: emailLower }).select('+password');
    if (apartment) {
      return { apartment, mobile: (apartment.contactPhone || '').trim(), managementUser: null };
    }

    const mUser = await ManagementUser.findOne({ email: emailLower }).select('+password');
    if (mUser && mUser.isActive) {
      const owner = await Apartment.findById(mUser.apartmentId).select('+password');
      if (owner) {
        return { apartment: owner, mobile: mUser.mobileNumber, managementUser: mUser };
      }
    }
  }

  const mobile = normalizeMobile10(identifier);
  if (mobile) {
    const apartment = await Apartment.findOne({ contactPhone: mobile }).select('+password');
    if (apartment) {
      return { apartment, mobile, managementUser: null };
    }

    const mUser = await ManagementUser.findOne({ mobileNumber: mobile }).select('+password');
    if (mUser && mUser.isActive) {
      const owner = await Apartment.findById(mUser.apartmentId).select('+password');
      if (owner) {
        return { apartment: owner, mobile, managementUser: mUser };
      }
    }
  }

  return null;
}

/** The `user` object the app expects for a management (userType "apartment") login. */
function buildManagementPayload(apartment) {
  const apartmentId = apartment._id.toString();
  const loginMobile = (apartment.contactPhone || '').trim();
  const propertyEmail = (apartment.email || '').trim().toLowerCase();

  return {
    id: apartmentId,
    name: apartment.name,
    username: loginMobile,
    email: propertyEmail || '',
    mobileNumber: loginMobile,
    userType: 'apartment',
    status: 'approved',
    apartmentId,
    isActive: apartment.isActive,
    profilePic: apartment.profilePic || null,
    propertyType: 'events',
    ownerName: apartment.ownerName || null,
    wardenName: null,
    propertyName: apartment.name || null,
    loginRole: null,
    securityEnabled: apartment.securityEnabled !== false,
    assignPaymentEnabled: apartment.assignPaymentEnabled !== false,
    complaintsEnabled: apartment.complaintsEnabled !== false,
    showUserMobile: apartment.showUserMobile !== false,
    addUserEnabled: apartment.addUserEnabled !== false,
  };
}

/** Store a device token on the given document (max 10 per account). */
async function storeFcmToken(doc, fcmToken) {
  if (!fcmToken || typeof fcmToken !== 'string' || fcmToken.trim() === '') return;
  const token = fcmToken.trim();
  const tokens = Array.isArray(doc.fcmTokens) ? [...doc.fcmTokens] : [];
  if (tokens.includes(token)) return;
  tokens.push(token);
  const limited = tokens.length > 10 ? tokens.slice(-10) : tokens;
  await doc.constructor.updateOne({ _id: doc._id }, { fcmTokens: limited });
}

/** Find an event staff account by email or mobile. */
async function findStaffAccount(rawId) {
  const identifier = String(rawId ?? '').trim();
  if (!identifier) return null;
  if (identifier.includes('@')) {
    return EventStaff.findOne({ email: identifier.toLowerCase() }).select('+password');
  }
  const mobile = normalizeMobile10(identifier);
  return mobile ? EventStaff.findOne({ mobileNumber: mobile }).select('+password') : null;
}

/** Event staff login (used when no management account matches). */
async function loginStaff(req, res, identifier, passwordStr, fcmToken) {
  const staff = await findStaffAccount(identifier);
  if (!staff) {
    return res.status(400).json({ error: 'No account found with this email or mobile number' });
  }
  if (!(await staff.comparePassword(passwordStr))) {
    return res.status(401).json({ error: 'Invalid email/mobile number or password' });
  }
  if (!staff.isActive) {
    return res.status(403).json({ error: 'Your account has been deactivated. Please contact management.' });
  }
  if (staff.status !== 'approved') {
    return res.status(403).json({ error: 'Your account is not approved yet.' });
  }
  const apartment = await Apartment.findById(staff.apartmentId).select('name isActive');
  if (!apartment || !apartment.isActive) {
    return res.status(403).json({ error: 'This event account is not active. Please contact management.' });
  }
  await storeFcmToken(staff, fcmToken);
  const token = generateToken(staff._id, staff.apartmentId);
  return res.json({
    message: 'Login successful',
    user: buildStaffPayload(staff, apartment),
    token,
    success: true,
  });
}

// @desc    Management login (email or mobile + password)
// @route   POST /api/auth/login
// @access  Public
const loginUser = async (req, res) => {
  try {
    const { email, password, userType, fcmToken } = req.body;

    const idRaw = email ?? req.body.username;
    if (idRaw == null || String(idRaw).trim() === '') {
      return res.status(400).json({ error: 'Email or username is required' });
    }

    const passwordStr = password != null ? String(password) : '';
    if (!passwordStr || passwordStr.trim() === '') {
      return res.status(400).json({ error: 'Password is required' });
    }

    // Event Management is the only login type; it is also the default.
    const normalizedUserType = userType ? String(userType).toLowerCase().trim() : 'apartment';
    if (normalizedUserType !== 'apartment' && normalizedUserType !== 'user') {
      return res.status(400).json({ error: 'Unsupported login type' });
    }

    const lookup = await findManagementAccount(
      email ?? req.body.mobile ?? req.body.mobileNumber ?? req.body.username ?? ''
    );
    if (!lookup) {
      return await loginStaff(req, res, email ?? req.body.mobile ?? req.body.mobileNumber ?? req.body.username ?? '', passwordStr, fcmToken);
    }

    const { apartment, mobile, managementUser } = lookup;
    let isPasswordMatch = false;
    if (managementUser) {
      isPasswordMatch = await bcrypt.compare(passwordStr, managementUser.password);
    } else if (apartment.password) {
      isPasswordMatch = await apartment.comparePassword(passwordStr);
    }

    if (!isPasswordMatch) {
      return res.status(401).json({ error: 'Invalid email/mobile number or password' });
    }
    if (!apartment.isActive) {
      return res.status(403).json({
        error: 'This apartment account has been deactivated. Please contact administrator.',
      });
    }

    await storeFcmToken(managementUser || apartment, fcmToken);

    const userPayload = buildManagementPayload(apartment);
    if (managementUser) {
      userPayload.name = managementUser.name || userPayload.name;
      userPayload.mobileNumber = managementUser.mobileNumber || mobile;
      userPayload.managementUserId = managementUser._id.toString();
      userPayload.roleTitle = managementUser.roleTitle || 'Management Member';
    }

    const token = generateToken(apartment._id, apartment._id);
    return res.json({
      message: 'Login successful',
      user: userPayload,
      token,
      success: true,
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: error.message || 'Server error' });
  }
};

// @desc    Get current user
// @route   GET /api/auth/me
// @access  Private
const getCurrentUser = async (req, res) => {
  try {
    if (req.userType === 'user') {
      const staff = await EventStaff.findById(req.userId);
      if (!staff) return res.status(404).json({ error: 'User not found' });
      const apt = await Apartment.findById(staff.apartmentId).select('name');
      return res.json({ user: buildStaffPayload(staff, apt) });
    }
    const apartment = await Apartment.findById(req.userId);
    if (!apartment) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json({ user: buildManagementPayload(apartment) });
  } catch (error) {
    console.error('Get current user error:', error);
    res.status(500).json({ error: error.message || 'Server error' });
  }
};

// @desc    Update management profile: name, email, mobile, password
// @route   PUT /api/auth/management-profile
// @access  Private
const updateManagementProfile = async (req, res) => {
  try {
    const {
      name,
      email,
      mobileNumber,
      contactPhone,
      currentPassword,
      newPassword,
      password,
    } = req.body;

    const nextPassword =
      typeof newPassword === 'string'
        ? newPassword
        : typeof password === 'string'
          ? password
          : undefined;
    const wantsPasswordChange =
      typeof nextPassword === 'string' && nextPassword.trim().length > 0;

    const apartment = await Apartment.findById(req.userId).select('+password');
    if (!apartment) {
      return res.status(404).json({ success: false, error: 'Property account not found' });
    }

    if (name !== undefined) {
      const trimmedName = String(name || '').trim();
      if (!trimmedName) {
        return res.status(400).json({ success: false, error: 'Name is required' });
      }
      apartment.name = trimmedName;
    }

    if (email !== undefined) {
      const trimmedEmail = String(email || '').trim().toLowerCase();
      if (!trimmedEmail || !EMAIL_REGEX.test(trimmedEmail)) {
        return res.status(400).json({ success: false, error: 'Enter a valid email address' });
      }
      apartment.email = trimmedEmail;
    }

    const nextMobileRaw =
      contactPhone !== undefined ? contactPhone : mobileNumber !== undefined ? mobileNumber : undefined;
    if (nextMobileRaw !== undefined) {
      const phone = normalizeMobile10(nextMobileRaw);
      if (!phone) {
        return res.status(400).json({ success: false, error: 'Enter a valid 10-digit mobile number' });
      }
      const clash = await Apartment.findOne({
        contactPhone: phone,
        _id: { $ne: apartment._id },
      }).select('_id');
      if (clash) {
        return res.status(400).json({
          success: false,
          error: 'A property with this mobile number already exists',
        });
      }
      apartment.contactPhone = phone;
    }

    if (wantsPasswordChange) {
      if (!currentPassword || String(currentPassword).trim().length === 0) {
        return res.status(400).json({
          success: false,
          error: 'Current password is required to set a new password',
        });
      }
      if (String(nextPassword).trim().length < 6) {
        return res.status(400).json({
          success: false,
          error: 'New password must be at least 6 characters long',
        });
      }
      const matches = await apartment.comparePassword(String(currentPassword));
      if (!matches) {
        return res.status(400).json({ success: false, error: 'Current password is incorrect' });
      }
      apartment.password = String(nextPassword).trim();
    }

    await apartment.save();

    res.json({
      success: true,
      message: wantsPasswordChange
        ? 'Profile and password updated successfully'
        : 'Profile updated successfully',
      user: buildManagementPayload(apartment),
      apartment: {
        id: apartment._id.toString(),
        name: apartment.name,
        email: apartment.email,
        contactPhone: apartment.contactPhone,
        ownerName: apartment.ownerName || '',
        wardenName: '',
        wardenContact: '',
        propertyType: 'events',
      },
    });
  } catch (error) {
    console.error('Update management profile error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// @desc    Upload / replace the management profile photo
// @route   PUT /api/auth/management-profile-photo
// @access  Private
const updateManagementProfilePhoto = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, error: 'Photo is required' });
    }
    const apartment = await Apartment.findById(req.userId);
    if (!apartment) {
      return res.status(404).json({ success: false, error: 'Account not found' });
    }
    apartment.profilePic = await uploadToCloudinary(req.file.buffer, 'isdr/profiles');
    await apartment.save();
    res.json({
      success: true,
      message: 'Profile photo updated',
      profilePic: apartment.profilePic,
      user: buildManagementPayload(apartment),
    });
  } catch (error) {
    console.error('Update profile photo error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// @desc    Update FCM token for the logged-in account
// @route   PUT /api/auth/fcm-token
// @access  Private
const updateFcmToken = async (req, res) => {
  try {
    const { fcmToken } = req.body;
    if (!fcmToken || typeof fcmToken !== 'string' || fcmToken.trim() === '') {
      return res.status(400).json({ success: false, error: 'fcmToken is required' });
    }
    const apartment = await Apartment.findById(req.userId);
    if (!apartment) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }
    await storeFcmToken(apartment, fcmToken);
    res.json({ success: true });
  } catch (error) {
    console.error('Update FCM token error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// @desc    List management IDs (primary account + co-management IDs) for the property
// @route   GET /api/auth/management-users
// @access  Private
const listManagementUsers = async (req, res) => {
  try {
    const apartmentId = req.apartmentId;

    const apt = await Apartment.findById(apartmentId);
    const addedUsers = await ManagementUser.find({ apartmentId }).sort({ createdAt: -1 });

    const allUsers = [];

    // The main property account is shown as a standard Management ID
    if (apt) {
      const primaryMobile = (apt.contactPhone || '').trim();
      if (primaryMobile) {
        allUsers.push({
          _id: `primary_${apt._id}`,
          name: (apt.ownerName || apt.name || 'Management Member').trim(),
          mobileNumber: primaryMobile,
          email: (apt.email || '').trim(),
          roleTitle: 'Management Member',
          isActive: apt.isActive !== false,
          createdAt: apt.createdAt,
        });
      }
    }

    for (const u of addedUsers) {
      allUsers.push({
        _id: u._id.toString(),
        name: u.name,
        mobileNumber: u.mobileNumber,
        email: u.email || '',
        roleTitle: u.roleTitle || 'Management Member',
        isActive: u.isActive !== false,
        createdAt: u.createdAt,
      });
    }

    res.json({ success: true, users: allUsers });
  } catch (error) {
    console.error('listManagementUsers error:', error);
    res.status(500).json({ error: error.message || 'Server error' });
  }
};

// @desc    Create a co-management ID for the property
// @route   POST /api/auth/management-users
// @access  Private
const createManagementUser = async (req, res) => {
  try {
    const apartmentId = req.apartmentId;
    const { name, mobileNumber, email, roleTitle, password } = req.body;
    const cleanMobile = String(mobileNumber || '').trim();
    const cleanEmail = String(email || '').trim().toLowerCase();

    if (!name || !cleanMobile || !cleanEmail || !password) {
      return res
        .status(400)
        .json({ error: 'Name, mobile number, email address, and password are required' });
    }
    if (!/^[0-9]{10}$/.test(cleanMobile)) {
      return res.status(400).json({ error: 'Mobile number must be a valid 10-digit number' });
    }
    if (String(password).length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters' });
    }

    const existing = await ManagementUser.findOne({ apartmentId, mobileNumber: cleanMobile });
    if (existing) {
      return res
        .status(400)
        .json({ error: 'A management ID with this mobile number already exists for this property' });
    }

    const hashedPassword = await bcrypt.hash(String(password), 10);

    const newUser = await ManagementUser.create({
      apartmentId,
      name: String(name).trim(),
      mobileNumber: cleanMobile,
      email: cleanEmail,
      roleTitle: roleTitle ? String(roleTitle).trim() : 'Management Member',
      password: hashedPassword,
    });

    res.status(201).json({
      success: true,
      message: 'Management ID added successfully',
      user: {
        id: newUser._id.toString(),
        name: newUser.name,
        mobileNumber: newUser.mobileNumber,
        email: newUser.email,
        roleTitle: newUser.roleTitle,
        isActive: newUser.isActive,
      },
    });
  } catch (error) {
    console.error('createManagementUser error:', error);
    res.status(500).json({ error: error.message || 'Server error' });
  }
};

// @desc    Delete a co-management ID
// @route   DELETE /api/auth/management-users/:id
// @access  Private
const deleteManagementUser = async (req, res) => {
  try {
    const { id } = req.params;
    if (String(id).startsWith('primary_')) {
      return res.status(400).json({ error: 'The main management account cannot be removed' });
    }
    // Only IDs that belong to this property can be removed
    const removed = await ManagementUser.findOneAndDelete({ _id: id, apartmentId: req.apartmentId });
    if (!removed) {
      return res.status(404).json({ error: 'Management ID not found' });
    }
    res.json({ success: true, message: 'Management ID removed successfully' });
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid ID' });
    }
    console.error('deleteManagementUser error:', error);
    res.status(500).json({ error: error.message || 'Server error' });
  }
};

module.exports = {
  loginUser,
  getCurrentUser,
  updateManagementProfile,
  updateManagementProfilePhoto,
  updateFcmToken,
  listManagementUsers,
  createManagementUser,
  deleteManagementUser,
};
