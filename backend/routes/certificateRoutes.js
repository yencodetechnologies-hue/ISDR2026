const express = require('express');
const router = express.Router();
const { protect, requireManagement } = require('../middleware/auth');
const {
  scanAttendance,
  myCertificate,
  listCertificates,
  unlockCertificates,
  revertCertificates,
  submitFeedback,
  listFeedbackQuestions,
  createFeedbackQuestion,
  updateFeedbackQuestion,
  deleteFeedbackQuestion,
  reorderFeedbackQuestions,
} = require('../controllers/certificateController');

// Entry/exit scans (event staff + admin) and attendance certificates.
router.post('/scan', protect, scanAttendance);
router.get('/me', protect, myCertificate);
router.post('/feedback', protect, submitFeedback);
router.get('/questions', protect, requireManagement, listFeedbackQuestions);
router.post('/questions', protect, requireManagement, createFeedbackQuestion);
router.put('/questions/reorder', protect, requireManagement, reorderFeedbackQuestions);
router.put('/questions/:id', protect, requireManagement, updateFeedbackQuestion);
router.delete('/questions/:id', protect, requireManagement, deleteFeedbackQuestion);
router.get('/', protect, requireManagement, listCertificates);
router.post('/unlock', protect, requireManagement, unlockCertificates);
router.post('/revert', protect, requireManagement, revertCertificates);

module.exports = router;
