const ManagedEvent = require('../models/ManagedEvent');
const EventSchedule = require('../models/EventSchedule');
const EventRegistration = require('../models/EventRegistration');
const Speaker = require('../models/Speaker');
const ScheduleReminder = require('../models/ScheduleReminder');
const { scheduleStartAt } = require('../utils/reminderScheduler');
const {
  participantPackageId,
  visibleScheduleFilter,
  isScheduleVisible,
} = require('../utils/schedulePackages');

const TIME_REGEX = /^([01]\d|2[0-3]):[0-5]\d$/;

const toDto = (s) => ({
  id: s._id.toString(),
  eventId: s.eventId.toString(),
  speakerId: s.speakerId ? s.speakerId.toString() : null,
  speakerName: s.speakerName,
  speakerPhoto: s.speakerPhoto || '',
  scheduleName: s.scheduleName,
  packageIds: s.packageIds || [],
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
    const packageId = await participantPackageId(req);
    const schedules = await EventSchedule.find({
      eventId: event._id,
      ...visibleScheduleFilter(packageId),
    }).sort({
      date: 1,
      fromTime: 1,
    });
    res.json({ success: true, schedules: schedules.map(toDto) });
  } catch (error) {
    console.error('listSchedules error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

/** `packageIds` as a list (or a JSON string of one), trimmed and de-duplicated. */
function readPackageIds(body) {
  let raw = body.packageIds;
  if (typeof raw === 'string') {
    try {
      raw = JSON.parse(raw);
    } catch (_) {
      raw = [raw];
    }
  }
  if (!Array.isArray(raw)) return [];
  return [...new Set(raw.map((id) => String(id ?? '').trim()).filter(Boolean))];
}

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

/**
 * Validates a schedule form (create or edit). Returns { error } or the clean
 * { speaker, scheduleName, hall, description, packageIds, slots }.
 */
async function readScheduleForm(event, body) {
  const speakerId = String(body.speakerId || '').trim();
  const scheduleName = String(body.scheduleName || '').trim();
  const hall = String(body.hall || '').trim();
  const description = String(body.description || '').trim();
  const rawSlots = readSlots(body);
  const packageIds = readPackageIds(body);

  if (!speakerId) return { error: 'Select a speaker' };
  const speaker = await Speaker.findOne({ _id: speakerId, apartmentId: event.apartmentId }).catch(() => null);
  if (!speaker) return { error: 'Speaker not found' };
  if (packageIds.length === 0) return { error: 'Select at least one package' };
  const eventPackageIds = new Set((event.packages || []).map((p) => String(p.id)));
  if (packageIds.some((id) => !eventPackageIds.has(id))) return { error: 'Package not found on this event' };
  if (!scheduleName) return { error: 'Schedule name is required' };
  if (rawSlots.length === 0) return { error: 'Select at least one date' };

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
    if (Number.isNaN(date.getTime())) return { error: 'A valid date is required' };
    const picked = utcDay(date);
    if (picked < evStart || picked > evEnd) return { error: 'Schedule date must fall within the event dates' };
    if (seenDays.has(picked)) return { error: 'The same date was selected twice' };
    seenDays.add(picked);
    if (!TIME_REGEX.test(fromTime) || !TIME_REGEX.test(toTime)) return { error: 'From and to time are required' };
    if (toTime <= fromTime) return { error: 'To time must be after from time' };
    slots.push({ date, fromTime, toTime });
  }
  return { speaker, scheduleName, hall, description, packageIds, slots };
}

// POST /api/managed-events/:id/schedules  { speakerId, packageIds, scheduleName, hall, slots, description }
const createSchedule = async (req, res) => {
  try {
    const event = await loadOwnedEvent(req, res);
    if (!event) return;
    const form = await readScheduleForm(event, req.body);
    if (form.error) return res.status(400).json({ success: false, error: form.error });

    // One row per date, all linked to the speaker (whose login covers them all).
    const created = await EventSchedule.create(
      form.slots.map((slot) => ({
        eventId: event._id,
        apartmentId: event.apartmentId,
        speakerId: form.speaker._id,
        speakerName: form.speaker.name,
        speakerPhoto: form.speaker.photo || '',
        scheduleName: form.scheduleName,
        packageIds: form.packageIds,
        hall: form.hall,
        date: slot.date,
        fromTime: slot.fromTime,
        toTime: slot.toTime,
        description: form.description,
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

// PUT /api/managed-events/:id/schedules/:scheduleId  { speakerId, packageIds, scheduleName, hall, date, fromTime, toTime, description }
// Admin edits one schedule row (a single date).
const updateSchedule = async (req, res) => {
  try {
    const event = await loadOwnedEvent(req, res);
    if (!event) return;
    const schedule = await EventSchedule.findOne({ _id: req.params.scheduleId, eventId: event._id }).catch(
      () => null
    );
    if (!schedule) return res.status(404).json({ success: false, error: 'Schedule not found' });
    const form = await readScheduleForm(event, req.body);
    if (form.error) return res.status(400).json({ success: false, error: form.error });
    if (form.slots.length !== 1) {
      return res.status(400).json({ success: false, error: 'A schedule has exactly one date' });
    }
    const [slot] = form.slots;
    Object.assign(schedule, {
      speakerId: form.speaker._id,
      speakerName: form.speaker.name,
      speakerPhoto: form.speaker.photo || '',
      scheduleName: form.scheduleName,
      packageIds: form.packageIds,
      hall: form.hall,
      date: slot.date,
      fromTime: slot.fromTime,
      toTime: slot.toTime,
      description: form.description,
    });
    await schedule.save();
    res.json({ success: true, schedule: toDto(schedule) });
  } catch (error) {
    console.error('updateSchedule error:', error);
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
// Every schedule the logged-in speaker was picked for, plus the event.
const mySpeakerSessions = async (req, res) => {
  try {
    if (req.userType !== 'speaker') {
      return res.status(403).json({ success: false, error: 'Only speakers can view this' });
    }
    const sessions = await EventSchedule.find({ speakerId: req.userId }).sort({
      date: 1,
      fromTime: 1,
    });
    const event = sessions.length
      ? await ManagedEvent.findById(sessions[0].eventId).select('title venue')
      : null;
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
    const reg = await EventRegistration.findById(req.userId).select('favoriteSchedules packageId');
    if (!reg) return res.status(404).json({ success: false, error: 'Participant not found' });
    const schedules = await EventSchedule.find({
      _id: { $in: reg.favoriteSchedules },
      ...visibleScheduleFilter(String(reg.packageId || '')),
    }).sort({
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
    const schedule = await EventSchedule.findById(req.params.scheduleId).select('_id packageIds');
    const reg = await EventRegistration.findById(req.userId).select('favoriteSchedules packageId');
    if (!reg) return res.status(404).json({ success: false, error: 'Participant not found' });
    if (!schedule || !isScheduleVisible(schedule, String(reg.packageId || ''))) {
      return res.status(404).json({ success: false, error: 'Schedule not found' });
    }
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

// GET /api/managed-events/my-reminders  (participant login)
// Ids of the upcoming schedules this participant wants a start reminder for.
const myReminders = async (req, res) => {
  try {
    if (req.userType !== 'participant') {
      return res.status(403).json({ success: false, error: 'Only participants have reminders' });
    }
    const reminders = await ScheduleReminder.find({ participantId: req.userId, sentAt: null }).select(
      'scheduleId'
    );
    res.json({ success: true, scheduleIds: reminders.map((r) => String(r.scheduleId)) });
  } catch (error) {
    console.error('myReminders error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// POST /api/managed-events/reminders/:scheduleId  (participant login)
// Turns the start reminder on, or off if it's already on.
const toggleReminder = async (req, res) => {
  try {
    if (req.userType !== 'participant') {
      return res.status(403).json({ success: false, error: 'Only participants have reminders' });
    }
    const reg = await EventRegistration.findById(req.userId).select('packageId');
    if (!reg) return res.status(404).json({ success: false, error: 'Participant not found' });
    const schedule = await EventSchedule.findById(req.params.scheduleId).select(
      'date fromTime packageIds'
    );
    if (!schedule || !isScheduleVisible(schedule, String(reg.packageId || ''))) {
      return res.status(404).json({ success: false, error: 'Schedule not found' });
    }
    const removed = await ScheduleReminder.findOneAndDelete({
      participantId: req.userId,
      scheduleId: schedule._id,
      sentAt: null,
    });
    if (removed) return res.json({ success: true, reminder: false });

    const startAt = scheduleStartAt(schedule);
    if (startAt <= new Date()) {
      return res.status(400).json({ success: false, error: 'This session has already started' });
    }
    // Replaces an old, already-sent reminder for the same session if any.
    await ScheduleReminder.findOneAndUpdate(
      { participantId: req.userId, scheduleId: schedule._id },
      { startAt, sentAt: null },
      { upsert: true }
    );
    res.json({ success: true, reminder: true });
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(404).json({ success: false, error: 'Schedule not found' });
    }
    console.error('toggleReminder error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

module.exports = {
  myReminders,
  toggleReminder,
  listSchedules,
  createSchedule,
  updateSchedule,
  deleteSchedule,
  mySpeakerSessions,
  myFavorites,
  toggleFavorite,
};
