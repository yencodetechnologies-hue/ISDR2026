const FeedPost = require('../models/FeedPost');
const EventRegistration = require('../models/EventRegistration');
const { uploadToCloudinary } = require('../middleware/upload');

const toDto = (p, viewerId) => ({
  id: p._id.toString(),
  eventId: p.eventId ? p.eventId.toString() : null,
  participantId: p.participantId.toString(),
  participantName: p.participantName,
  participantPhoto: p.participantPhoto || '',
  imageUrl: p.imageUrl,
  likeCount: (p.likes || []).length,
  liked: !!viewerId && (p.likes || []).some((id) => String(id) === String(viewerId)),
  // True for the participant who posted it (only they can delete it).
  mine: !!viewerId && String(p.participantId) === String(viewerId),
  createdAt: p.createdAt,
});

// GET /api/feed-posts â€” every post for the property, newest first. No filtering
// by who posted it: every participant sees every other participant's photo.
const listFeedPosts = async (req, res) => {
  try {
    const posts = await FeedPost.find({ apartmentId: req.apartmentId })
      .sort({ createdAt: -1 })
      .limit(200);
    res.json({ success: true, posts: posts.map((p) => toDto(p, req.userId)) });
  } catch (error) {
    console.error('listFeedPosts error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// POST /api/feed-posts (multipart, `photo`) â€” participants only.
const createFeedPost = async (req, res) => {
  try {
    if (req.userType !== 'participant') {
      return res.status(403).json({ success: false, error: 'Only participants can post to the feed' });
    }
    if (!req.file) {
      return res.status(400).json({ success: false, error: 'A photo is required' });
    }
    const participant = await EventRegistration.findById(req.userId);
    if (!participant) {
      return res.status(404).json({ success: false, error: 'Participant not found' });
    }

    const imageUrl = await uploadToCloudinary(req.file.buffer, 'isdr/feed');
    const post = await FeedPost.create({
      apartmentId: req.apartmentId,
      eventId: participant.eventId,
      participantId: participant._id,
      participantName: participant.name,
      participantPhoto: participant.photoUrl || '',
      imageUrl,
    });

    res.status(201).json({ success: true, post: toDto(post, req.userId) });
  } catch (error) {
    console.error('createFeedPost error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// POST /api/feed-posts/:id/like — likes the post, or removes the like if already liked.
const toggleLike = async (req, res) => {
  try {
    const post = await FeedPost.findOne({ _id: req.params.id, apartmentId: req.apartmentId }).select('likes');
    if (!post) return res.status(404).json({ success: false, error: 'Post not found' });
    const liked = post.likes.some((id) => String(id) === String(req.userId));
    const updated = await FeedPost.findByIdAndUpdate(
      post._id,
      liked ? { $pull: { likes: req.userId } } : { $addToSet: { likes: req.userId } },
      { new: true }
    ).select('likes');
    res.json({
      success: true,
      liked: !liked,
      likeCount: updated.likes.length,
    });
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(404).json({ success: false, error: 'Post not found' });
    }
    console.error('toggleLike error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// DELETE /api/feed-posts/:id — only the participant who posted it.
const deleteFeedPost = async (req, res) => {
  try {
    const post = await FeedPost.findOne({ _id: req.params.id, apartmentId: req.apartmentId }).catch(() => null);
    if (!post) return res.status(404).json({ success: false, error: 'Post not found' });
    if (req.userType !== 'participant' || String(post.participantId) !== String(req.userId)) {
      return res.status(403).json({ success: false, error: 'You can only delete your own posts' });
    }
    await post.deleteOne();
    res.json({ success: true });
  } catch (error) {
    console.error('deleteFeedPost error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

module.exports = { listFeedPosts, createFeedPost, toggleLike, deleteFeedPost };
