const AwardWinner = require('../models/AwardWinner');

const MAX_AWARD = 50;
const MAX_RECIPIENTS = 20;
const MAX_NAME = 200;

function recipientsFrom(row) {
  if (Array.isArray(row.recipients) && row.recipients.length) {
    return row.recipients
      .map((p) => ({ rank: p.rank, name: String(p.name || '').trim() }))
      .filter((p) => p.name);
  }
  if (row.name) return [{ rank: 1, name: String(row.name).trim() }];
  return [];
}

function shapeWinner(row) {
  const recipients = recipientsFrom(row);
  const top = recipients.find((p) => p.rank === 1) || recipients[0] || null;
  return {
    name: top ? top.name : '',
    recipients,
  };
}

function cleanRecipients(raw) {
  if (!Array.isArray(raw)) return { error: 'Enter the recipients' };
  const recipients = [];
  for (const item of raw) {
    if (!item || typeof item !== 'object') continue;
    const name = String(item.name || '').trim();
    if (!name) continue;
    const rank = parseInt(item.rank, 10);
    if (!Number.isInteger(rank) || rank < 1) return { error: 'Each recipient needs a rank of 1 or more' };
    if (name.length > MAX_NAME) return { error: 'A name is too long' };
    recipients.push({ rank, name });
    if (recipients.length > MAX_RECIPIENTS) return { error: `At most ${MAX_RECIPIENTS} recipients` };
  }
  return { recipients };
}

// GET /api/awards — any login: { winners: { "<awardNumber>": { name, recipients: [{rank, name}] } } }
const listWinners = async (req, res) => {
  try {
    const rows = await AwardWinner.find({ apartmentId: req.apartmentId }).lean();
    const winners = {};
    rows.forEach((r) => {
      const shaped = shapeWinner(r);
      if (shaped.recipients.length) winners[r.awardNumber] = shaped;
    });
    res.json({ success: true, winners });
  } catch (error) {
    console.error('listWinners error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// PUT /api/awards/:number { recipients: [{ rank, name }] } — admin types the recipients.
// An empty list removes the award.
const setWinner = async (req, res) => {
  try {
    const awardNumber = parseInt(req.params.number, 10);
    if (!Number.isInteger(awardNumber) || awardNumber < 1 || awardNumber > MAX_AWARD) {
      return res.status(400).json({ success: false, error: 'Invalid award' });
    }
    const filter = { apartmentId: req.apartmentId, awardNumber };
    const cleaned = cleanRecipients(req.body.recipients);
    if (cleaned.error) return res.status(400).json({ success: false, error: cleaned.error });
    if (!cleaned.recipients.length) {
      await AwardWinner.deleteOne(filter);
      return res.json({ success: true, winner: null });
    }
    const top = cleaned.recipients.find((p) => p.rank === 1) || cleaned.recipients[0];
    const doc = await AwardWinner.findOneAndUpdate(
      filter,
      {
        $set: { name: top.name, recipients: cleaned.recipients },
        $unset: { registrationId: '' },
      },
      { upsert: true, new: true }
    );
    res.json({ success: true, winner: shapeWinner(doc) });
  } catch (error) {
    console.error('setWinner error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

module.exports = { listWinners, setWinner };
