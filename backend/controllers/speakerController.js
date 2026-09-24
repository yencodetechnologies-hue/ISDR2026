const Speaker = require('../models/Speaker');
const EventSchedule = require('../models/EventSchedule');
const Apartment = require('../models/Apartment');
const ManagementUser = require('../models/ManagementUser');
const EventStaff = require('../models/EventStaff');
const EventRegistration = require('../models/EventRegistration');
const { uploadToCloudinary } = require('../middleware/upload');

/** Last 10 digits of a phone-like string, or '' if there are fewer than 10 digits. */
function normalizeMobile10(raw) {
  const digits = String(raw ?? '').replace(/\D/g, '');
  return digits.length >= 10 ? digits.slice(-10) : '';
}

const toDto = (s) => ({
  id: s._id.toString(),
  name: s.name,
  photo: s.photo || '',
  mobileNumber: s.mobileNumber,
  createdAt: s.createdAt,
});

/**
 * Login checks management, staff and participant accounts before speakers, so
 * a speaker mobile must not already belong to any of those (or another speaker).
 */
async function mobileTakenMessage(mobile) {
  const [speaker, apartment, mUser, staff, participant] = await Promise.all([
    Speaker.exists({ mobileNumber: mobile }),
    Apartment.exists({ contactPhone: mobile }),
    ManagementUser.exists({ mobileNumber: mobile }),
    EventStaff.exists({ mobileNumber: mobile }),
    EventRegistration.exists({ mobileNumber: mobile }),
  ]);
  if (speaker) return 'A speaker with this mobile number already exists';
  if (apartment || mUser || staff || participant) {
    return 'This mobile number already belongs to another account';
  }
  return null;
}

// GET /api/speakers — the property's speakers, A–Z.
const listSpeakers = async (req, res) => {
  try {
    const speakers = await Speaker.find({ apartmentId: req.apartmentId }).sort({ name: 1 });
    res.json({ success: true, speakers: speakers.map(toDto) });
  } catch (error) {
    console.error('listSpeakers error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// POST /api/speakers  (multipart: name, mobileNumber, password, optional `photo`)
const createSpeaker = async (req, res) => {
  try {
    const name = String(req.body.name || '').trim();
    const mobileNumber = normalizeMobile10(req.body.mobileNumber);
    const password = String(req.body.password || '');
    if (!name) return res.status(400).json({ success: false, error: 'Speaker name is required' });
    if (!mobileNumber) {
      return res.status(400).json({ success: false, error: 'Enter a valid 10-digit mobile number' });
    }
    if (password.trim().length < 6) {
      return res.status(400).json({ success: false, error: 'Password must be at least 6 characters' });
    }
    const clash = await mobileTakenMessage(mobileNumber);
    if (clash) return res.status(400).json({ success: false, error: clash });

    const photo = req.file ? await uploadToCloudinary(req.file.buffer, 'isdr/speakers') : '';
    const speaker = await Speaker.create({
      apartmentId: req.apartmentId,
      name,
      photo,
      mobileNumber,
      password,
    });
    res.status(201).json({ success: true, speaker: toDto(speaker) });
  } catch (error) {
    console.error('createSpeaker error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// DELETE /api/speakers/:id — only when no schedule uses the speaker.
const deleteSpeaker = async (req, res) => {
  try {
    const speaker = await Speaker.findOne({ _id: req.params.id, apartmentId: req.apartmentId });
    if (!speaker) return res.status(404).json({ success: false, error: 'Speaker not found' });
    const inUse = await EventSchedule.countDocuments({ speakerId: speaker._id });
    if (inUse > 0) {
      return res.status(400).json({
        success: false,
        error: `This speaker has ${inUse} schedule${inUse === 1 ? '' : 's'}. Delete those first.`,
      });
    }
    await speaker.deleteOne();
    res.json({ success: true });
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(404).json({ success: false, error: 'Speaker not found' });
    }
    console.error('deleteSpeaker error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

module.exports = { listSpeakers, createSpeaker, deleteSpeaker, normalizeMobile10 };
