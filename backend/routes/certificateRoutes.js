const express = require('express');
const router = express.Router();
const { protect, requireManagement } = require('../middleware/auth');
const {
  scanAttendance,
  myCertificate,
  listCertificates,
  unlockCertificates,
  revertCertificates,
} = require('../controllers/certificateController');

// Entry/exit scans (event staff + admin) and attendance certificates.
router.post('/scan', protect, scanAttendance);
router.get('/me', protect, myCertificate);
router.get('/', protect, requireManagement, listCertificates);
router.post('/unlock', protect, requireManagement, unlockCertificates);
router.post('/revert', protect, requireManagement, revertCertificates);

module.exports = router;
