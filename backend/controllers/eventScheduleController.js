const ManagedEvent = require('../models/ManagedEvent');
const EventSchedule = require('../models/EventSchedule');
const Apartment = require('../models/Apartment');
const ManagementUser = require('../models/ManagementUser');
const EventStaff = require('../models/EventStaff');
const EventRegistration = require('../models/EventRegistration');
const { uploadToCloudinary } = require('../middleware/upload');

const TIME_REGEX = /^([01]\d|2[0-3]):[0-5]\d$/;

/** Last 10 digits of a phone-like string, or '' if there are fewer than 10 digits. */
function normalizeMobile10(raw) {
  const digits = String(raw ?? '').replace(/\D/g, '');
  return digits.length >= 10 ? digits.slice(-10) : '';
}

/**
 * Login tries management, staff and participant accounts before speakers, so a
 * speaker mobile must not already belong to any of those (or another schedule).
 */
async function speakerMobileTaken(mobile) {
  const [schedule, apartment, mUser, staff, participant] = await Promise.all([
    EventSchedule.exists({ speakerMobile: mobile }),
    Apartment.exists({ contactPhone: mobile }),
    ManagementUser.exists({ mobileNumber: mobile }),
    EventStaff.exists({ mobileNumber: mobile }),
    EventRegistration.exists({ mobileNumber: mobile }),
  ]);
  if (schedule) return 'This mobile number is already used by another schedule';
  if (apartment || mUser || staff || participant) {
    return 'This mobile number already belongs to another account';
  }
  return null;
}

const toDto = (s) => ({
  id: s._id.toString(),
  eventId: s.eventId.toString(),
  speakerName: s.speakerName,
  speakerPhoto: s.speakerPhoto || '',
  scheduleName: s.scheduleName,
  hall: s.hall || '',
  date: s.date,
  fromTime: s.fromTime,
  toTime: s.toTime,
  description: s.description || '',
});

/** Loads the event and checks it belongs to the logged-in property. */
async function loadOwnedEvent(req, res) {
  const event = await ManagedEvent.findById(req.params.id);
  if (!event) {
    res.status(404).json({ success: false, error: 'Event not found' });
    return null;
  }
  if (String(event.apartmentId) !== String(req.apartmentId)) {
    res.status(403).json({ success: false, error: 'Not authorized for this event' });
    return null;
  }
  return event;
}

// GET /api/managed-events/:id/schedules
const listSchedules = async (req, res) => {
  try {
    const event = await ManagedEvent.findById(req.params.id);
    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' });
    }
    const schedules = await EventSchedule.find({ eventId: event._id }).sort({
      date: 1,
      fromTime: 1,
    });
    res.json({ success: true, schedules: schedules.map(toDto) });
  } catch (error) {
    console.error('listSchedules error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

/**
 * The dates + times to create: `slots` is a JSON list of {date, fromTime, toTime}
 * (one row is created per date); a single date/fromTime/toTime is still accepted.
 */
function readSlots(body) {
  if (body.slots === undefined) {
    return [{ date: body.date, fromTime: body.fromTime, toTime: body.toTime }];
  }
  try {
    const parsed = typeof body.slots === 'string' ? JSON.parse(body.slots) : body.slots;
    return Array.isArray(parsed) ? parsed : [];
  } catch (_) {
    return [];
  }
}

// POST /api/managed-events/:id/schedules  (multipart, optional `photo`)
const createSchedule = async (req, res) => {
  try {
    const event = await loadOwnedEvent(req, res);
    if (!event) return;

    const speakerName = String(req.body.speakerName || '').trim();
    const scheduleName = String(req.body.scheduleName || '').trim();
    const hall = String(req.body.hall || '').trim();
    const description = String(req.body.description || '').trim();
    const speakerMobile = normalizeMobile10(req.body.speakerMobile);
    const speakerPassword = String(req.body.speakerPassword || '');
    const rawSlots = readSlots(req.body);

    if (!speakerName) return res.status(400).json({ success: false, error: 'Speaker name is required' });
    if (!speakerMobile) {
      return res.status(400).json({ success: false, error: 'Enter a valid 10-digit speaker mobile number' });
    }
    if (speakerPassword.trim().length < 6) {
      return res.status(400).json({ success: false, error: 'Speaker password must be at least 6 characters' });
    }
    if (!scheduleName) return res.status(400).json({ success: false, error: 'Schedule name is required' });
    if (rawSlots.length === 0) return res.status(400).json({ success: false, error: 'Select at least one date' });

    // Each date is a calendar day (sent as yyyy-MM-dd, parsed as UTC midnight); the event
    // times are stored in UTC, so allow one day of slack for the device's time zone.
    const DAY = 24 * 60 * 60 * 1000;
    const utcDay = (d) => Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
    const evStart = utcDay(new Date(event.eventDate)) - DAY;
    const evEnd = utcDay(new Date(event.eventEndDate || event.eventDate)) + DAY;
    const seenDays = new Set();
    const slots = [];
    for (const raw of rawSlots) {
      const date = new Date(raw && raw.date);
      const fromTime = String((raw && raw.fromTime) || '').trim();
      const toTime = String((raw && raw.toTime) || '').trim();
      if (Number.isNaN(date.getTime())) return res.status(400).json({ success: false, error: 'A valid date is required' });
      const picked = utcDay(date);
      if (picked < evStart || picked > evEnd) {
        return res
          .status(400)
          .json({ success: false, error: 'Schedule date must fall within the event dates' });
      }
      if (seenDays.has(picked)) return res.status(400).json({ success: false, error: 'The same date was selected twice' });
      seenDays.add(picked);
      if (!TIME_REGEX.test(fromTime) || !TIME_REGEX.test(toTime)) {
        return res.status(400).json({ success: false, error: 'From and to time are required' });
      }
      if (toTime <= fromTime) {
        return res.status(400).json({ success: false, error: 'To time must be after from time' });
      }
      slots.push({ date, fromTime, toTime });
    }
    const mobileClash = await speakerMobileTaken(speakerMobile);
    if (mobileClash) return res.status(400).json({ success: false, error: mobileClash });

    let speakerPhoto = '';
    if (req.file) {
      speakerPhoto = await uploadToCloudinary(req.file.buffer, 'isdr/speakers');
    }

    // One row per date; they share the speaker's mobile + password, so one login covers them all.
    const created = await EventSchedule.create(
      slots.map((slot) => ({
        eventId: event._id,
        apartmentId: event.apartmentId,
        speakerName,
        speakerPhoto,
        speakerMobile,
        speakerPassword,
        scheduleName,
        hall,
        date: slot.date,
        fromTime: slot.fromTime,
        toTime: slot.toTime,
        description,
      }))
    );
    res.status(201).json({
      success: true,
      schedule: toDto(created[0]),
      schedules: created.map(toDto),
    });
  } catch (error) {
    console.error('createSchedule error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// DELETE /api/managed-events/:id/schedules/:scheduleId
const deleteSchedule = async (req, res) => {
  try {
    const event = await loadOwnedEvent(req, res);
    if (!event) return;
    const removed = await EventSchedule.findOneAndDelete({
      _id: req.params.scheduleId,
      eventId: event._id,
    });
    if (!removed) {
      return res.status(404).json({ success: false, error: 'Schedule not found' });
    }
    res.json({ success: true });
  } catch (error) {
    console.error('deleteSchedule error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// GET /api/managed-events/my-speaker-sessions  (speaker login)
// Every schedule row sharing the logged-in speaker's mobile, plus the event.
const mySpeakerSessions = async (req, res) => {
  try {
    if (req.userType !== 'speaker') {
      return res.status(403).json({ success: false, error: 'Only speakers can view this' });
    }
    const own = await EventSchedule.findById(req.userId).select('eventId speakerMobile');
    if (!own) return res.status(404).json({ success: false, error: 'Speaker not found' });
    const sessions = await EventSchedule.find({ speakerMobile: own.speakerMobile }).sort({
      date: 1,
      fromTime: 1,
    });
    const event = await ManagedEvent.findById(own.eventId).select('title venue');
    res.json({
      success: true,
      sessions: sessions.map(toDto),
      event: event ? { id: event._id.toString(), title: event.title, venue: event.venue || '' } : null,
    });
  } catch (error) {
    console.error('mySpeakerSessions error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// GET /api/managed-events/my-favorites  (participant login)
// The participant's hearted schedules (oldest first) with each one's event.
const myFavorites = async (req, res) => {
  try {
    if (req.userType !== 'participant') {
      return res.status(403).json({ success: false, error: 'Only participants have favorites' });
    }
    const reg = await EventRegistration.findById(req.userId).select('favoriteSchedules');
    if (!reg) return res.status(404).json({ success: false, error: 'Participant not found' });
    const schedules = await EventSchedule.find({ _id: { $in: reg.favoriteSchedules } }).sort({
      date: 1,
      fromTime: 1,
    });
    const events = await ManagedEvent.find({
      _id: { $in: [...new Set(schedules.map((s) => String(s.eventId)))] },
    }).select('title venue');
    res.json({
      success: true,
      // Deleted schedules drop out here, so the ids always match `schedules`.
      scheduleIds: schedules.map((s) => s._id.toString()),
      schedules: schedules.map(toDto),
      events: Object.fromEntries(
        events.map((e) => [e._id.toString(), { id: e._id.toString(), title: e.title, venue: e.venue || '' }])
      ),
    });
  } catch (error) {
    console.error('myFavorites error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// POST /api/managed-events/favorites/:scheduleId  (participant login)
// Hearts the schedule, or removes it if it's already a favorite.
const toggleFavorite = async (req, res) => {
  try {
    if (req.userType !== 'participant') {
      return res.status(403).json({ success: false, error: 'Only participants have favorites' });
    }
    const schedule = await EventSchedule.findById(req.params.scheduleId).select('_id');
    if (!schedule) return res.status(404).json({ success: false, error: 'Schedule not found' });
    const reg = await EventRegistration.findById(req.userId).select('favoriteSchedules');
    if (!reg) return res.status(404).json({ success: false, error: 'Participant not found' });
    const isFavorite = reg.favoriteSchedules.some((id) => String(id) === String(schedule._id));
    const updated = await EventRegistration.findByIdAndUpdate(
      reg._id,
      isFavorite
        ? { $pull: { favoriteSchedules: schedule._id } }
        : { $addToSet: { favoriteSchedules: schedule._id } },
      { new: true }
    ).select('favoriteSchedules');
    res.json({
      success: true,
      favorite: !isFavorite,
      scheduleIds: updated.favoriteSchedules.map((id) => id.toString()),
    });
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(404).json({ success: false, error: 'Schedule not found' });
    }
    console.error('toggleFavorite error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

module.exports = {
  listSchedules,
  createSchedule,
  deleteSchedule,
  mySpeakerSessions,
  myFavorites,
  toggleFavorite,
};
