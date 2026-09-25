const express = require('express');
const router = express.Router();
const { protect, requireManagement } = require('../middleware/auth');
const { getLive, setLive } = require('../controllers/youtubeLiveController');

// YouTube live link: admin sets it, every login can read it.
router.get('/', protect, getLive);
router.put('/', protect, requireManagement, setLive);

module.exports = router;
