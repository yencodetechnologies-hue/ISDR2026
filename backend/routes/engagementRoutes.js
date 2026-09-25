const express = require('express');
const router = express.Router();
const { protect, requireManagement } = require('../middleware/auth');
const {
  sessionQuestions,
  sessionPolls,
  speakerQuestions,
} = require('../controllers/engagementController');

// Management only: every Q&A and poll on the property (read-only).
router.get('/session-questions', protect, requireManagement, sessionQuestions);
router.get('/session-polls', protect, requireManagement, sessionPolls);
router.get('/speaker-questions', protect, requireManagement, speakerQuestions);

module.exports = router;
