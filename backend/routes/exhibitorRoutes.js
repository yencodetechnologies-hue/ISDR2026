const express = require('express');
const router = express.Router();
const { protect, requireManagement } = require('../middleware/auth');
const { uploadSingleImage } = require('../middleware/upload');
const {
  listExhibitors,
  createExhibitor,
  deleteExhibitor,
} = require('../controllers/exhibitorController');

// Management adds/removes exhibitors; every login on the property can list them.
router.get('/', protect, listExhibitors);
router.post('/', protect, requireManagement, uploadSingleImage('photo'), createExhibitor);
router.delete('/:id', protect, requireManagement, deleteExhibitor);

module.exports = router;
