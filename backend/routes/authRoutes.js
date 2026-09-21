const express = require('express');
const router = express.Router();
const {
  loginUser,
  getCurrentUser,
  updateManagementProfile,
  updateManagementProfilePhoto,
  updateFcmToken,
  listManagementUsers,
  createManagementUser,
  deleteManagementUser,
} = require('../controllers/authController');
const { uploadSingleImage, upload } = require('../middleware/upload');
const {
  registerStaff,
  listStaff,
  toggleStaffActive,
  updateStaffStatus,
  updateStaff,
  deleteStaff,
} = require('../controllers/staffController');

const staffImages = upload.fields([
  { name: 'profilePic', maxCount: 1 },
  { name: 'aadhaarFront', maxCount: 1 },
  { name: 'aadhaarBack', maxCount: 1 },
  { name: 'panCard', maxCount: 1 },
]);
const { protect, requireManagement } = require('../middleware/auth');

// @route   POST /api/auth/login
router.post('/login', loginUser);

// @route   GET /api/auth/me
router.get('/me', protect, getCurrentUser);

// @route   PUT /api/auth/management-profile
router.put('/management-profile', protect, requireManagement, updateManagementProfile);

router.put(
  '/management-profile-photo',
  protect,
  requireManagement,
  uploadSingleImage('profilePic'),
  updateManagementProfilePhoto
);

// @route   PUT /api/auth/fcm-token
router.put('/fcm-token', protect, updateFcmToken);

// Management IDs (co-management team)
router.get('/management-users', protect, requireManagement, listManagementUsers);
router.post('/management-users', protect, requireManagement, createManagementUser);
router.delete('/management-users/:id', protect, requireManagement, deleteManagementUser);

// Event staff (added and managed by management)
router.post('/register', protect, requireManagement, staffImages, registerStaff);
router.get('/users', protect, requireManagement, listStaff);
router.put('/users/:id/toggle-active', protect, requireManagement, toggleStaffActive);
router.put('/users/:id/status', protect, requireManagement, updateStaffStatus);
router.put('/users/:id', protect, requireManagement, staffImages, updateStaff);
router.delete('/users/:id', protect, requireManagement, deleteStaff);

module.exports = router;
