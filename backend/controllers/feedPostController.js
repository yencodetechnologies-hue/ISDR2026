const FeedPost = require('../models/FeedPost');
const EventRegistration = require('../models/EventRegistration');
const { uploadToCloudinary } = require('../middleware/upload');

const toDto = (p) => ({
  id: p._id.toString(),
  eventId: p.eventId ? p.eventId.toString() : null,
  participantId: p.participantId.toString(),
  participantName: p.participantName,
  participantPhoto: p.participantPhoto || '',
  imageUrl: p.imageUrl,
  createdAt: p.createdAt,
});

// GET /api/feed-posts — every post for the property, newest first. No filtering
// by who posted it: every participant sees every other participant's photo.
const listFeedPosts = async (req, res) => {
  try {
    const posts = await FeedPost.find({ apartmentId: req.apartmentId })
      .sort({ createdAt: -1 })
      .limit(200);
    res.json({ success: true, posts: posts.map(toDto) });
  } catch (error) {
    console.error('listFeedPosts error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// POST /api/feed-posts (multipart, `photo`) — participants only.
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

    res.status(201).json({ success: true, post: toDto(post) });
  } catch (error) {
    console.error('createFeedPost error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

module.exports = { listFeedPosts, createFeedPost };
