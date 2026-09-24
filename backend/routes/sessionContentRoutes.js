const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const {
  getContent,
  createPoll,
  deletePoll,
  votePoll,
  createQuestion,
  deleteQuestion,
  answerQuestion,
  rateSession,
} = require('../controllers/sessionContentController');

// Session content: polls / questions a speaker adds to one of their sessions.
// Speakers manage them; participants vote on polls and answer questions.
router.get('/:scheduleId', protect, getContent);
router.post('/:scheduleId/polls', protect, createPoll);
router.delete('/:scheduleId/polls/:pollId', protect, deletePoll);
router.post('/:scheduleId/polls/:pollId/vote', protect, votePoll);
router.post('/:scheduleId/questions', protect, createQuestion);
router.delete('/:scheduleId/questions/:questionId', protect, deleteQuestion);
router.post('/:scheduleId/questions/:questionId/answer', protect, answerQuestion);
router.post('/:scheduleId/rating', protect, rateSession);

module.exports = router;
