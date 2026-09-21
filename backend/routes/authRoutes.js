const express = require('express');
const router = express.Router();
const {
  loginUser,
  getCurrentUser,
  updateManagementProfile,
  updateFcmToken,
  listManagementUsers,
  createManagementUser,
  deleteManagementUser,
} = require('../controllers/authController');
const { protect, requireManagement } = require('../middleware/auth');

// @route   POST /api/auth/login
router.post('/login', loginUser);

// @route   GET /api/auth/me
router.get('/me', protect, getCurrentUser);

// @route   PUT /api/auth/management-profile
router.put('/management-profile', protect, requireManagement, updateManagementProfile);

// @route   PUT /api/auth/fcm-token
router.put('/fcm-token', protect, updateFcmToken);

// Management IDs (co-management team)
router.get('/management-users', protect, requireManagement, listManagementUsers);
router.post('/management-users', protect, requireManagement, createManagementUser);
router.delete('/management-users/:id', protect, requireManagement, deleteManagementUser);

module.exports = router;
