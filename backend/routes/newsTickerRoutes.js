const express = require('express');
const router = express.Router();
const { protect, requireManagement } = require('../middleware/auth');
const { getTicker, updateTicker } = require('../controllers/newsTickerController');

// Home-screen news ticker: admin edits it, every login can read it.
router.get('/', protect, getTicker);
router.put('/', protect, requireManagement, updateTicker);

module.exports = router;
