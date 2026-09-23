const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const { uploadSingleImage } = require('../middleware/upload');
const { listFeedPosts, createFeedPost } = require('../controllers/feedPostController');

router.get('/', protect, listFeedPosts);
router.post('/', protect, uploadSingleImage('photo'), createFeedPost);

module.exports = router;
