const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const {
  listSpeakers,
  askQuestion,
  myQuestions,
  speakerInbox,
  answerQuestion,
  sessionQuestionsForParticipant,
  sessionPollsForParticipant,
} = require('../controllers/speakerQuestionController');

// Participants ask speakers directly; each speaker answers once, privately.
router.get('/speakers', protect, listSpeakers);
router.get('/mine', protect, myQuestions);
router.get('/session-questions', protect, sessionQuestionsForParticipant);
router.get('/session-polls', protect, sessionPollsForParticipant);
router.get('/inbox', protect, speakerInbox);
router.post('/', protect, askQuestion);
router.post('/:id/answer', protect, answerQuestion);

module.exports = router;
