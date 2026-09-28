const LivePhoto = require('../models/LivePhoto');

// GET /api/live-photo — any login on the property. url is '' when none is set.
const getLivePhoto = async (req, res) => {
  try {
    let livePhoto = await LivePhoto.findOne({ apartmentId: req.apartmentId });
    if (!livePhoto) {
      livePhoto = await LivePhoto.findOne().sort({ updatedAt: -1 });
    }
    res.json({ success: true, url: livePhoto ? livePhoto.url : '' });
  } catch (error) {
    console.error('getLivePhoto error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// PUT /api/live-photo { url } — admin only; empty url removes it.
const setLivePhoto = async (req, res) => {
  try {
    const url = String(req.body.url || '').trim();
    if (url && !/^https?:\/\/\S+$/i.test(url)) {
      return res.status(400).json({ success: false, error: 'Enter a valid link (starting with http:// or https://)' });
    }
    const livePhoto = await LivePhoto.findOneAndUpdate(
      { apartmentId: req.apartmentId },
      { $set: { url }, $setOnInsert: { apartmentId: req.apartmentId } },
      { upsert: true, new: true }
    );
    res.json({ success: true, url: livePhoto.url });
  } catch (error) {
    console.error('setLivePhoto error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

module.exports = { getLivePhoto, setLivePhoto };
