const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const { uploadSingleDocument } = require('../middleware/upload');
const {
  getContent,
  uploadFile,
  deleteFile,
  createPoll,
  deletePoll,
  votePoll,
  createQuestion,
  deleteQuestion,
  answerQuestion,
  rateSession,
} = require('../controllers/sessionContentController');

/** Multer's errors (wrong type, too large) as a friendly 400 instead of a 500. */
function acceptDocument(req, res, next) {
  uploadSingleDocument('file')(req, res, (err) => {
    if (!err) return next();
    const error = err.code === 'LIMIT_FILE_SIZE' ? 'File is too large (max 10 MB)' : err.message;
    res.status(400).json({ success: false, error });
  });
}

// Session content: files / polls / questions a speaker adds to one of their sessions.
// Speakers manage them; participants view files, vote on polls and answer questions.
router.get('/:scheduleId', protect, getContent);
router.post('/:scheduleId/files', protect, acceptDocument, uploadFile);
router.delete('/:scheduleId/files/:fileId', protect, deleteFile);
router.post('/:scheduleId/polls', protect, createPoll);
router.delete('/:scheduleId/polls/:pollId', protect, deletePoll);
router.post('/:scheduleId/polls/:pollId/vote', protect, votePoll);
router.post('/:scheduleId/questions', protect, createQuestion);
router.delete('/:scheduleId/questions/:questionId', protect, deleteQuestion);
router.post('/:scheduleId/questions/:questionId/answer', protect, answerQuestion);
router.post('/:scheduleId/rating', protect, rateSession);

module.exports = router;
