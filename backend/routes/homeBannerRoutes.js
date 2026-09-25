const express = require('express');
const router = express.Router();
const { protect, requireManagement } = require('../middleware/auth');
const { uploadSingleImage } = require('../middleware/upload');
const {
  getBanner,
  setEnabled,
  addImage,
  deleteImage,
} = require('../controllers/homeBannerController');

// Participant home image banner: admin manages it, every login can read it.
router.get('/', protect, getBanner);
router.put('/', protect, requireManagement, setEnabled);
router.post('/images', protect, requireManagement, uploadSingleImage('image'), addImage);
router.delete('/images/:imageId', protect, requireManagement, deleteImage);

module.exports = router;
