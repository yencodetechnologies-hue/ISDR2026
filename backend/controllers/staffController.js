const Apartment = require('../models/Apartment');
const ManagementUser = require('../models/ManagementUser');
const EventStaff = require('../models/EventStaff');
const { uploadToCloudinary } = require('../middleware/upload');

const EMAIL_REGEX = /^\S+@\S+\.\S+$/;
const STATUSES = ['pending', 'approved', 'rejected'];

/** The `user` object the app expects for an event staff account. */
function buildStaffPayload(staff, apartment) {
  return {
    id: staff._id.toString(),
    name: staff.name,
    username: staff.username,
    email: staff.email || '',
    mobileNumber: staff.mobileNumber,
    secondaryMobileNumber: staff.secondaryMobileNumber || undefined,
    gender: staff.gender || undefined,
    userType: 'user',
    status: staff.status,
    isActive: staff.isActive,
    profilePic: staff.profilePic || null,
    address: staff.address || undefined,
    aadhaarCard: staff.aadhaarCard || undefined,
    aadhaarCardFrontImage: staff.aadhaarCardFrontImage || undefined,
    aadhaarCardBackImage: staff.aadhaarCardBackImage || undefined,
    panCard: staff.panCard || undefined,
    panCardImage: staff.panCardImage || undefined,
    apartmentId: staff.apartmentId.toString(),
    apartmentName: apartment ? apartment.name : undefined,
    propertyType: 'events',
    createdAt: staff.createdAt,
  };
}

/** True when the mobile number is already used by another login on this backend. */
async function mobileTaken(mobile, exceptStaffId = null) {
  const staffQuery = { mobileNumber: mobile };
  if (exceptStaffId) staffQuery._id = { $ne: exceptStaffId };
  if (await EventStaff.exists(staffQuery)) return true;
  if (await Apartment.exists({ contactPhone: mobile })) return true;
  if (await ManagementUser.exists({ mobileNumber: mobile })) return true;
  return false;
}

async function emailTaken(email, exceptStaffId = null) {
  if (!email) return false;
  const staffQuery = { email };
  if (exceptStaffId) staffQuery._id = { $ne: exceptStaffId };
  if (await EventStaff.exists(staffQuery)) return true;
  if (await Apartment.exists({ email })) return true;
  if (await ManagementUser.exists({ email })) return true;
  return false;
}

/** Uploads any attached images (multer `fields`) and returns their URLs. */
async function uploadImages(files) {
  const out = {};
  if (!files) return out;
  const map = [
    ['profilePic', 'profilePic', 'isdr/staff'],
    ['aadhaarFront', 'aadhaarCardFrontImage', 'isdr/staff_ids'],
    ['aadhaarBack', 'aadhaarCardBackImage', 'isdr/staff_ids'],
    ['panCard', 'panCardImage', 'isdr/staff_ids'],
  ];
  for (const [field, key, folder] of map) {
    if (files[field] && files[field][0]) {
      out[key] = await uploadToCloudinary(files[field][0].buffer, folder);
    }
  }
  return out;
}

// @desc    Add an event staff account (management only)
// @route   POST /api/auth/register
const registerStaff = async (req, res) => {
  try {
    const apartmentId = req.apartmentId;
    const name = String(req.body.name || '').trim();
    const email = String(req.body.email || '').trim().toLowerCase();
    const password = String(req.body.password || '');
    const mobile = String(req.body.mobileNumber || '').replace(/\D/g, '').slice(-10);

    if (!name) return res.status(400).json({ error: 'Name is required' });
    if (!/^[0-9]{10}$/.test(mobile)) {
      return res.status(400).json({ error: 'Enter a valid 10-digit mobile number' });
    }
    if (email && !EMAIL_REGEX.test(email)) {
      return res.status(400).json({ error: 'Enter a valid email address' });
    }
    if (password.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters' });
    }
    if (await mobileTaken(mobile)) {
      return res.status(400).json({ error: 'This mobile number is already used by another account' });
    }
    if (await emailTaken(email)) {
      return res.status(400).json({ error: 'This email is already used by another account' });
    }

    const images = await uploadImages(req.files);
    const staff = await EventStaff.create({
      apartmentId,
      name,
      username: `staff_${apartmentId}_${mobile}`,
      email,
      mobileNumber: mobile,
      secondaryMobileNumber: req.body.secondaryMobileNumber || '',
      gender: ['male', 'female', 'other'].includes(req.body.gender) ? req.body.gender : '',
      password,
      address: req.body.address || '',
      aadhaarCard: req.body.aadhaarCard || '',
      panCard: req.body.panCard || '',
      status: 'approved', // staff added by management need no approval
      ...images,
    });

    const apartment = await Apartment.findById(apartmentId).select('name').lean();
    res.status(201).json({
      success: true,
      message: 'Event staff added successfully',
      user: buildStaffPayload(staff, apartment),
    });
  } catch (error) {
    console.error('registerStaff error:', error);
    res.status(500).json({ error: error.message || 'Server error' });
  }
};

// @desc    List the property's event staff
// @route   GET /api/auth/users
const listStaff = async (req, res) => {
  try {
    const apartment = await Apartment.findById(req.apartmentId).select('name').lean();
    const staff = await EventStaff.find({ apartmentId: req.apartmentId }).sort({ createdAt: -1 });
    res.json({
      success: true,
      count: staff.length,
      users: staff.map((s) => buildStaffPayload(s, apartment)),
    });
  } catch (error) {
    console.error('listStaff error:', error);
    res.status(500).json({ error: error.message || 'Server error' });
  }
};

/** Loads a staff account that belongs to the logged-in property. */
async function findOwnedStaff(req, res) {
  const staff = await EventStaff.findOne({ _id: req.params.id, apartmentId: req.apartmentId });
  if (!staff) {
    res.status(404).json({ error: 'Event staff not found' });
    return null;
  }
  return staff;
}

// @route   PUT /api/auth/users/:id/toggle-active
const toggleStaffActive = async (req, res) => {
  try {
    const staff = await findOwnedStaff(req, res);
    if (!staff) return;
    staff.isActive = !staff.isActive;
    await staff.save();
    res.json({
      success: true,
      message: staff.isActive ? 'Staff activated' : 'Staff deactivated',
      user: buildStaffPayload(staff),
    });
  } catch (error) {
    if (error.name === 'CastError') return res.status(400).json({ error: 'Invalid ID' });
    console.error('toggleStaffActive error:', error);
    res.status(500).json({ error: error.message || 'Server error' });
  }
};

// @route   PUT /api/auth/users/:id/status   body: { status }
const updateStaffStatus = async (req, res) => {
  try {
    const status = String(req.body.status || '').toLowerCase();
    if (!STATUSES.includes(status)) {
      return res.status(400).json({ error: 'Invalid status' });
    }
    const staff = await findOwnedStaff(req, res);
    if (!staff) return;
    staff.status = status;
    await staff.save();
    res.json({ success: true, message: 'User status updated', user: buildStaffPayload(staff) });
  } catch (error) {
    if (error.name === 'CastError') return res.status(400).json({ error: 'Invalid ID' });
    console.error('updateStaffStatus error:', error);
    res.status(500).json({ error: error.message || 'Server error' });
  }
};

// @route   PUT /api/auth/users/:id   (multipart; every field optional)
const updateStaff = async (req, res) => {
  try {
    const staff = await findOwnedStaff(req, res);
    if (!staff) return;
    const b = req.body;

    if (b.name !== undefined) {
      const name = String(b.name).trim();
      if (!name) return res.status(400).json({ error: 'Name is required' });
      staff.name = name;
    }
    if (b.email !== undefined) {
      const email = String(b.email).trim().toLowerCase();
      if (email && !EMAIL_REGEX.test(email)) {
        return res.status(400).json({ error: 'Enter a valid email address' });
      }
      if (await emailTaken(email, staff._id)) {
        return res.status(400).json({ error: 'This email is already used by another account' });
      }
      staff.email = email;
    }
    if (b.mobileNumber !== undefined) {
      const mobile = String(b.mobileNumber).replace(/\D/g, '').slice(-10);
      if (!/^[0-9]{10}$/.test(mobile)) {
        return res.status(400).json({ error: 'Enter a valid 10-digit mobile number' });
      }
      if (await mobileTaken(mobile, staff._id)) {
        return res.status(400).json({ error: 'This mobile number is already used by another account' });
      }
      staff.mobileNumber = mobile;
    }
    if (b.password !== undefined && String(b.password).length > 0) {
      if (String(b.password).length < 6) {
        return res.status(400).json({ error: 'Password must be at least 6 characters' });
      }
      staff.password = String(b.password);
    }
    if (b.secondaryMobileNumber !== undefined) staff.secondaryMobileNumber = b.secondaryMobileNumber;
    if (b.gender !== undefined && ['male', 'female', 'other', ''].includes(b.gender)) staff.gender = b.gender;
    if (b.address !== undefined) staff.address = b.address;
    if (b.aadhaarCard !== undefined) staff.aadhaarCard = b.aadhaarCard;
    if (b.panCard !== undefined && typeof b.panCard === 'string') staff.panCard = b.panCard;

    Object.assign(staff, await uploadImages(req.files));
    await staff.save();
    res.json({
      success: true,
      message: 'User updated successfully',
      user: buildStaffPayload(staff),
    });
  } catch (error) {
    if (error.name === 'CastError') return res.status(400).json({ error: 'Invalid ID' });
    console.error('updateStaff error:', error);
    res.status(500).json({ error: error.message || 'Server error' });
  }
};

// @route   DELETE /api/auth/users/:id
const deleteStaff = async (req, res) => {
  try {
    const removed = await EventStaff.findOneAndDelete({
      _id: req.params.id,
      apartmentId: req.apartmentId,
    });
    if (!removed) return res.status(404).json({ error: 'Event staff not found' });
    res.json({ success: true, message: 'User deleted successfully' });
  } catch (error) {
    if (error.name === 'CastError') return res.status(400).json({ error: 'Invalid ID' });
    console.error('deleteStaff error:', error);
    res.status(500).json({ error: error.message || 'Server error' });
  }
};

module.exports = {
  buildStaffPayload,
  registerStaff,
  listStaff,
  toggleStaffActive,
  updateStaffStatus,
  updateStaff,
  deleteStaff,
};
