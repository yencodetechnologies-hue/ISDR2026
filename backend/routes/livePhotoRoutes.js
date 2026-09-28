const express = require('express');
const router = express.Router();
const { protect, requireManagement } = require('../middleware/auth');
const { getLivePhoto, setLivePhoto } = require('../controllers/livePhotoController');

// Live photo link: admin sets it, every login can read it.
router.get('/', protect, getLivePhoto);
router.put('/', protect, requireManagement, setLivePhoto);

module.exports = router;
