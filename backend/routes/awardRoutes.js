const express = require('express');
const router = express.Router();
const { protect, requireManagement } = require('../middleware/auth');
const { listWinners, setWinner } = require('../controllers/awardController');

// Award winners: admin picks one participant per award, every login can read them.
router.get('/', protect, listWinners);
router.put('/:number', protect, requireManagement, setWinner);

module.exports = router;
