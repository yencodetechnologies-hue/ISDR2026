const NewsTicker = require('../models/NewsTicker');

const MAX_LENGTH = 2000;

const toDto = (t) => ({
  enabled: t ? t.enabled !== false : true,
  text: t && t.text ? t.text : NewsTicker.DEFAULT_TEXT,
});

// GET /api/news-ticker — any login on the property.
const getTicker = async (req, res) => {
  try {
    const ticker = await NewsTicker.findOne({ apartmentId: req.apartmentId });
    res.json({ success: true, ticker: toDto(ticker) });
  } catch (error) {
    console.error('getTicker error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// PUT /api/news-ticker  { enabled?, text? } — admin only.
const updateTicker = async (req, res) => {
  try {
    const update = {};
    if (req.body.enabled !== undefined) {
      if (typeof req.body.enabled !== 'boolean') {
        return res.status(400).json({ success: false, error: 'enabled must be true or false' });
      }
      update.enabled = req.body.enabled;
    }
    if (req.body.text !== undefined) {
      // Tidy each line; blank lines are dropped.
      const text = String(req.body.text)
        .split(/\r?\n/)
        .map((line) => line.trim())
        .filter(Boolean)
        .join('\n');
      if (!text) return res.status(400).json({ success: false, error: 'Enter the ticker text' });
      if (text.length > MAX_LENGTH) {
        return res
          .status(400)
          .json({ success: false, error: `Ticker text must be under ${MAX_LENGTH} characters` });
      }
      update.text = text;
    }
    const ticker = await NewsTicker.findOneAndUpdate(
      { apartmentId: req.apartmentId },
      { $set: update, $setOnInsert: { apartmentId: req.apartmentId } },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );
    res.json({ success: true, ticker: toDto(ticker) });
  } catch (error) {
    console.error('updateTicker error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

module.exports = { getTicker, updateTicker };
