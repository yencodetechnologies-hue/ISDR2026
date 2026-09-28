const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const { uploadSingleImage } = require('../middleware/upload');
const {
  listFeedPosts,
  createFeedPost,
  toggleLike,
  deleteFeedPost,
} = require('../controllers/feedPostController');

router.get('/', protect, listFeedPosts);
router.post('/', protect, uploadSingleImage('photo'), createFeedPost);
router.post('/:id/like', protect, toggleLike);
router.delete('/:id', protect, deleteFeedPost);

module.exports = router;
