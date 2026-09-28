const mongoose = require('mongoose');
const AwardWinner = require('../models/AwardWinner');
const EventRegistration = require('../models/EventRegistration');
const ManagedEvent = require('../models/ManagedEvent');

const MAX_AWARD = 50;

// GET /api/awards — any login: { winners: { "<awardNumber>": { registrationId, name } } }
const listWinners = async (req, res) => {
  try {
    const rows = await AwardWinner.find({ apartmentId: req.apartmentId }).lean();
    const winners = {};
    rows.forEach((r) => {
      winners[r.awardNumber] = { registrationId: String(r.registrationId), name: r.name };
    });
    res.json({ success: true, winners });
  } catch (error) {
    console.error('listWinners error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// PUT /api/awards/:number { registrationId } — admin sets the winner; an empty id removes it.
const setWinner = async (req, res) => {
  try {
    const awardNumber = parseInt(req.params.number, 10);
    if (!Number.isInteger(awardNumber) || awardNumber < 1 || awardNumber > MAX_AWARD) {
      return res.status(400).json({ success: false, error: 'Invalid award' });
    }
    const filter = { apartmentId: req.apartmentId, awardNumber };
    const registrationId = String(req.body.registrationId || '').trim();
    if (!registrationId) {
      await AwardWinner.deleteOne(filter);
      return res.json({ success: true, winner: null });
    }
    if (!mongoose.Types.ObjectId.isValid(registrationId)) {
      return res.status(400).json({ success: false, error: 'Invalid participant' });
    }
    const events = await ManagedEvent.find({ apartmentId: req.apartmentId }).select('_id').lean();
    const reg = await EventRegistration.findOne({
      _id: registrationId,
      eventId: { $in: events.map((e) => e._id) },
      status: { $ne: 'cancelled' },
    }).select('name title');
    if (!reg) return res.status(404).json({ success: false, error: 'Participant not found' });

    const name = [reg.title, reg.name].filter(Boolean).join('. ');
    await AwardWinner.findOneAndUpdate(
      filter,
      { $set: { registrationId: reg._id, name } },
      { upsert: true, new: true }
    );
    res.json({ success: true, winner: { registrationId, name } });
  } catch (error) {
    console.error('setWinner error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

module.exports = { listWinners, setWinner };
