const YoutubeLive = require('../models/YoutubeLive');

const YOUTUBE_URL = /^https?:\/\/((www|m)\.)?(youtube\.com|youtu\.be)\/\S+$/i;

// GET /api/youtube-live — any login on the property. url is '' when none is set.
const getLive = async (req, res) => {
  try {
    const live = await YoutubeLive.findOne({ apartmentId: req.apartmentId });
    res.json({ success: true, url: live ? live.url : '' });
  } catch (error) {
    console.error('getLive error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// PUT /api/youtube-live { url } — admin only; an empty url removes the capsule.
const setLive = async (req, res) => {
  try {
    const url = String(req.body.url || '').trim();
    if (url && !YOUTUBE_URL.test(url)) {
      return res.status(400).json({ success: false, error: 'Enter a valid YouTube link' });
    }
    const live = await YoutubeLive.findOneAndUpdate(
      { apartmentId: req.apartmentId },
      { $set: { url }, $setOnInsert: { apartmentId: req.apartmentId } },
      { upsert: true, new: true }
    );
    res.json({ success: true, url: live.url });
  } catch (error) {
    console.error('setLive error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

module.exports = { getLive, setLive };
