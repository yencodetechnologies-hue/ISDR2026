const express = require('express');
const router = express.Router();
const { protect, requireManagement } = require('../middleware/auth');
const { uploadSingleImage } = require('../middleware/upload');
const { listSpeakers, createSpeaker, deleteSpeaker } = require('../controllers/speakerController');

// Speakers are added on the management Speakers page and picked when adding a schedule.
router.get('/', protect, requireManagement, listSpeakers);
router.post('/', protect, requireManagement, uploadSingleImage('photo'), createSpeaker);
router.delete('/:id', protect, requireManagement, deleteSpeaker);

module.exports = router;
