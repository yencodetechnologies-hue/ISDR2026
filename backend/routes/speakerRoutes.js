const express = require('express');
const router = express.Router();
const { protect, requireManagement } = require('../middleware/auth');
const { uploadSingleImage } = require('../middleware/upload');
const {
  listSpeakers,
  createSpeaker,
  updateSpeaker,
  setAskEnabled,
  deleteSpeaker,
} = require('../controllers/speakerController');

// Speakers are added on the management Speakers page and picked when adding a schedule.
router.get('/', protect, requireManagement, listSpeakers);
router.post('/', protect, requireManagement, uploadSingleImage('photo'), createSpeaker);
router.patch('/:id', protect, requireManagement, setAskEnabled);
router.put('/:id', protect, requireManagement, uploadSingleImage('photo'), updateSpeaker);
router.delete('/:id', protect, requireManagement, deleteSpeaker);

module.exports = router;
