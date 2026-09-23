const ManagedEvent = require('../models/ManagedEvent');
const EventSchedule = require('../models/EventSchedule');
const { uploadToCloudinary } = require('../middleware/upload');

const TIME_REGEX = /^([01]\d|2[0-3]):[0-5]\d$/;

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

// POST /api/managed-events/:id/schedules  (multipart, optional `photo`)
const createSchedule = async (req, res) => {
  try {
    const event = await loadOwnedEvent(req, res);
    if (!event) return;

    const speakerName = String(req.body.speakerName || '').trim();
    const scheduleName = String(req.body.scheduleName || '').trim();
    const hall = String(req.body.hall || '').trim();
    const fromTime = String(req.body.fromTime || '').trim();
    const toTime = String(req.body.toTime || '').trim();
    const description = String(req.body.description || '').trim();
    const date = new Date(req.body.date);

    if (!speakerName) return res.status(400).json({ success: false, error: 'Speaker name is required' });
    if (!scheduleName) return res.status(400).json({ success: false, error: 'Schedule name is required' });
    if (Number.isNaN(date.getTime())) return res.status(400).json({ success: false, error: 'A valid date is required' });
    // The date is a calendar day (sent as yyyy-MM-dd, parsed as UTC midnight); the event
    // times are stored in UTC, so allow one day of slack for the device's time zone.
    const DAY = 24 * 60 * 60 * 1000;
    const utcDay = (d) => Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
    const evStart = utcDay(new Date(event.eventDate)) - DAY;
    const evEnd = utcDay(new Date(event.eventEndDate || event.eventDate)) + DAY;
    const picked = utcDay(date);
    if (picked < evStart || picked > evEnd) {
      return res
        .status(400)
        .json({ success: false, error: 'Schedule date must fall within the event dates' });
    }
    if (!TIME_REGEX.test(fromTime) || !TIME_REGEX.test(toTime)) {
      return res.status(400).json({ success: false, error: 'From and to time are required' });
    }
    if (toTime <= fromTime) {
      return res.status(400).json({ success: false, error: 'To time must be after from time' });
    }

    let speakerPhoto = '';
    if (req.file) {
      speakerPhoto = await uploadToCloudinary(req.file.buffer, 'isdr/speakers');
    }

    const schedule = await EventSchedule.create({
      eventId: event._id,
      apartmentId: event.apartmentId,
      speakerName,
      speakerPhoto,
      scheduleName,
      hall,
      date,
      fromTime,
      toTime,
      description,
    });
    res.status(201).json({ success: true, schedule: toDto(schedule) });
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

module.exports = { listSchedules, createSchedule, deleteSchedule };
