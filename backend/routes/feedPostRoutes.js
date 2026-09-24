const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const { uploadSingleImage } = require('../middleware/upload');
const { listFeedPosts, createFeedPost, toggleLike } = require('../controllers/feedPostController');

router.get('/', protect, listFeedPosts);
router.post('/', protect, uploadSingleImage('photo'), createFeedPost);
router.post('/:id/like', protect, toggleLike);

module.exports = router;
