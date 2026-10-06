const express = require('express');
const router = express.Router();
const { protect, requireManagement } = require('../middleware/auth');
const {
  listSpeakers,
  askQuestion,
  myQuestions,
  publicQuestions,
  adminAnswer,
  deleteQuestion,
  setPublic,
  speakerInbox,
  answerQuestion,
  sessionQuestionsForParticipant,
  sessionPollsForParticipant,
} = require('../controllers/speakerQuestionController');

// Participants ask enabled speakers. Admin answers and can publish the Q&A.
router.get('/speakers', protect, listSpeakers);
router.get('/mine', protect, myQuestions);
router.get('/public', protect, publicQuestions);
router.get('/session-questions', protect, sessionQuestionsForParticipant);
router.get('/session-polls', protect, sessionPollsForParticipant);
router.get('/inbox', protect, speakerInbox);
router.post('/', protect, askQuestion);
router.put('/:id/answer', protect, requireManagement, adminAnswer);
router.put('/:id/public', protect, requireManagement, setPublic);
router.delete('/:id', protect, requireManagement, deleteQuestion);
router.post('/:id/answer', protect, answerQuestion);

module.exports = router;
