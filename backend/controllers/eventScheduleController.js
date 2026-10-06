const ManagedEvent = require('../models/ManagedEvent');
const EventSchedule = require('../models/EventSchedule');
const EventRegistration = require('../models/EventRegistration');
const ScheduleReminder = require('../models/ScheduleReminder');
const { scheduleStartAt } = require('../utils/reminderScheduler');
const {
  participantPackageId,
  visibleScheduleFilter,
  isScheduleVisible,
} = require('../utils/schedulePackages');

const TIME_REGEX = /^([01]\d|2[0-3]):[0-5]\d$/;
// Reminder choices: at the start, or this many minutes before.
const REMINDER_MINUTES = [0, 5, 10, 15, 30, 60];

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
  hideDate: !!s.hideDate,
  hideFromTime: !!s.hideFromTime,
  hideToTime: !!s.hideToTime,
  description: s.description || '',
  sortOrder: Number.isInteger(s.sortOrder) && s.sortOrder > 0 ? s.sortOrder : null,
  updatedAt: s.updatedAt || null,
});

/** UTC calendar day, matching the admin lists. Empty when the session has no date. */
function calendarKey(date) {
  if (!date) return '';
  const d = new Date(date);
  if (Number.isNaN(d.getTime())) return '';
  const month = String(d.getUTCMonth() + 1).padStart(2, '0');
  const day = String(d.getUTCDate()).padStart(2, '0');
  return `${d.getUTCFullYear()}-${month}-${day}`;
}

function timeRank(s) {
  const from = String(s.fromTime || '').trim();
  if (!from) return '99:99';
  const to = String(s.toTime || '').trim() || '99:99';
  return `${from}\0${to}`;
}

function positiveOrder(s) {
  return Number.isInteger(s.sortOrder) && s.sortOrder > 0 ? s.sortOrder : null;
}

/** Day, then saved order, then clock. Sessions with no date sit after the dated days. */
function compareSchedules(a, b) {
  const ka = calendarKey(a.date);
  const kb = calendarKey(b.date);
  if (ka !== kb) {
    if (!ka) return 1;
    if (!kb) return -1;
    return ka < kb ? -1 : 1;
  }
  const ao = positiveOrder(a);
  const bo = positiveOrder(b);
  if (ao != null && bo != null && ao !== bo) return ao - bo;
  if (ao != null && bo == null) return -1;
  if (ao == null && bo != null) return 1;
  const time = timeRank(a).localeCompare(timeRank(b));
  if (time) return time;
  const name = String(a.scheduleName || '').localeCompare(String(b.scheduleName || ''));
  if (name) return name;
  return String(a._id).localeCompare(String(b._id));
}

function orderWithinDay(rows) {
  return [...rows].sort(compareSchedules);
}

/** Writes 1…n for this day's current sequence. */
async function assignContiguous(rows) {
  const saves = [];
  rows.forEach((row, i) => {
    const next = i + 1;
    if (row.sortOrder === next) return;
    row.sortOrder = next;
    saves.push(row.save());
  });
  await Promise.all(saves);
}

/** Other sessions on the same calendar day, in display order. */
async function daySiblings(eventId, date, excludeId) {
  const all = await EventSchedule.find({ eventId });
  const key = calendarKey(date);
  return orderWithinDay(
    all.filter((s) => calendarKey(s.date) === key && String(s._id) !== String(excludeId || ''))
  );
}

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
    });
    schedules.sort(compareSchedules);
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
 * { speakerName, scheduleName, hall, description, packageIds, slots }.
 * The speaker is a typed name, not a speaker account.
 */
function readScheduleForm(event, body) {
  const speakerName = String(body.speakerName || '').trim();
  const scheduleName = String(body.scheduleName || '').trim();
  const hall = String(body.hall || '').trim();
  const description = String(body.description || '').trim();
  const rawSlots = readSlots(body);
  const packageIds = readPackageIds(body);
  const flag = (value) => value === true || value === 'true' || value === 1 || value === '1';
  const hideDate = flag(body.hideDate);
  const hideFromTime = flag(body.hideFromTime);
  const hideToTime = flag(body.hideToTime);

  // An empty list means every package can see the session.
  const eventPackageIds = new Set((event.packages || []).map((p) => String(p.id)));
  if (packageIds.some((id) => !eventPackageIds.has(id))) return { error: 'Package not found on this event' };
  if (!scheduleName) return { error: 'Schedule name is required' };
  // No date is allowed: one undated row. Speaker and times are optional too.
  const slotInput = rawSlots.length ? rawSlots : [{ date: '', fromTime: '', toTime: '' }];

  // Each date is a calendar day (sent as yyyy-MM-dd, parsed as UTC midnight); the event
  // times are stored in UTC, so allow one day of slack for the device's time zone.
  const DAY = 24 * 60 * 60 * 1000;
  const utcDay = (d) => Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
  const evStart = utcDay(new Date(event.eventDate)) - DAY;
  const evEnd = utcDay(new Date(event.eventEndDate || event.eventDate)) + DAY;
  const seenDays = new Set();
  const slots = [];
  for (const raw of slotInput) {
    const dateRaw = String((raw && raw.date) || '').trim();
    const fromTime = String((raw && raw.fromTime) || '').trim();
    const toTime = String((raw && raw.toTime) || '').trim();
    const hasFrom = !!fromTime;
    const hasTo = !!toTime;
    if (hasFrom !== hasTo || (hasFrom && (!TIME_REGEX.test(fromTime) || !TIME_REGEX.test(toTime)))) {
      return { error: 'Set both from and to time, or leave both empty' };
    }
    if (hasFrom && toTime <= fromTime) return { error: 'To time must be after from time' };
    if ((hasFrom || hasTo) && !dateRaw) return { error: 'Select a date when setting a time' };
    if (!dateRaw) {
      slots.push({ date: null, fromTime: '', toTime: '' });
      continue;
    }
    const date = new Date(dateRaw);
    if (Number.isNaN(date.getTime())) return { error: 'A valid date is required' };
    const picked = utcDay(date);
    if (picked < evStart || picked > evEnd) return { error: 'Schedule date must fall within the event dates' };
    if (seenDays.has(picked)) return { error: 'The same date was selected twice' };
    seenDays.add(picked);
    slots.push({ date, fromTime: hasFrom ? fromTime : '', toTime: hasTo ? toTime : '' });
  }
  return { speakerName, scheduleName, hall, description, packageIds, hideDate, hideFromTime, hideToTime, slots };
}

// POST /api/managed-events/:id/schedules  { speakerName, packageIds, scheduleName, hall, slots, description }
const createSchedule = async (req, res) => {
  try {
    const event = await loadOwnedEvent(req, res);
    if (!event) return;
    const form = readScheduleForm(event, req.body);
    if (form.error) return res.status(400).json({ success: false, error: form.error });

    // One row per date, appended after that day's current sequence.
    const existing = await EventSchedule.find({ eventId: event._id });
    const payloads = [];
    for (const slot of form.slots) {
      const key = calendarKey(slot.date);
      const siblings = orderWithinDay(existing.filter((s) => calendarKey(s.date) === key));
      await assignContiguous(siblings);
      payloads.push({
        eventId: event._id,
        apartmentId: event.apartmentId,
        speakerId: null,
        speakerName: form.speakerName,
        speakerPhoto: '',
        scheduleName: form.scheduleName,
        packageIds: form.packageIds,
        hall: form.hall,
        date: slot.date,
        fromTime: slot.fromTime,
        toTime: slot.toTime,
        hideDate: form.hideDate,
        hideFromTime: form.hideFromTime,
        hideToTime: form.hideToTime,
        description: form.description,
        sortOrder: siblings.length + 1,
      });
    }
    const created = await EventSchedule.create(payloads);
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

// PUT /api/managed-events/:id/schedules/:scheduleId  { speakerName, packageIds, scheduleName, hall, date, fromTime, toTime, description }
// Admin edits one schedule row (a single date).
const updateSchedule = async (req, res) => {
  try {
    const event = await loadOwnedEvent(req, res);
    if (!event) return;
    const schedule = await EventSchedule.findOne({ _id: req.params.scheduleId, eventId: event._id }).catch(
      () => null
    );
    if (!schedule) return res.status(404).json({ success: false, error: 'Schedule not found' });
    const form = readScheduleForm(event, req.body);
    if (form.error) return res.status(400).json({ success: false, error: form.error });
    if (form.slots.length !== 1) {
      return res.status(400).json({ success: false, error: 'Edit one session at a time' });
    }
    const [slot] = form.slots;
    const previousDate = schedule.date;
    const movedDay = calendarKey(previousDate) !== calendarKey(slot.date);
    Object.assign(schedule, {
      speakerId: null,
      speakerName: form.speakerName,
      speakerPhoto: '',
      scheduleName: form.scheduleName,
      packageIds: form.packageIds,
      hall: form.hall,
      date: slot.date,
      fromTime: slot.fromTime,
      toTime: slot.toTime,
      hideDate: form.hideDate,
      hideFromTime: form.hideFromTime,
      hideToTime: form.hideToTime,
      description: form.description,
    });
    // Clock edits keep the day's sequence. A date change closes the old day and
    // appends this session on the new one. The row is still stored on the old
    // date until save, so both lookups exclude it.
    if (movedDay) {
      await assignContiguous(await daySiblings(event._id, previousDate, schedule._id));
      const dest = await daySiblings(event._id, slot.date, schedule._id);
      await assignContiguous(dest);
      schedule.sortOrder = dest.length + 1;
    }
    await schedule.save();
    res.json({ success: true, schedule: toDto(schedule) });
  } catch (error) {
    console.error('updateSchedule error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// PUT /api/managed-events/:id/schedules/:scheduleId/order  { serial }
// Moves one session to that S.No on its own date and shifts the others.
const reorderSchedule = async (req, res) => {
  try {
    const event = await loadOwnedEvent(req, res);
    if (!event) return;
    const serial = Number(req.body && req.body.serial);
    if (!Number.isInteger(serial) || serial < 1) {
      return res.status(400).json({ success: false, error: 'Enter a whole S.No starting at 1' });
    }
    const schedule = await EventSchedule.findOne({ _id: req.params.scheduleId, eventId: event._id }).catch(
      () => null
    );
    if (!schedule) return res.status(404).json({ success: false, error: 'Schedule not found' });

    const rows = await daySiblings(event._id, schedule.date, null);
    const from = rows.findIndex((s) => String(s._id) === String(schedule._id));
    if (from < 0) return res.status(404).json({ success: false, error: 'Schedule not found' });
    const to = Math.min(serial, rows.length) - 1;
    if (from !== to) {
      const [moved] = rows.splice(from, 1);
      rows.splice(to, 0, moved);
    }
    await assignContiguous(rows);
    res.json({ success: true, schedules: rows.map(toDto) });
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(404).json({ success: false, error: 'Schedule not found' });
    }
    console.error('reorderSchedule error:', error);
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
    await assignContiguous(await daySiblings(event._id, removed.date, removed._id));
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
      'scheduleId minutesBefore'
    );
    res.json({
      success: true,
      scheduleIds: reminders.map((r) => String(r.scheduleId)),
      // scheduleId -> minutes before the start (0 = at the start).
      reminders: Object.fromEntries(reminders.map((r) => [String(r.scheduleId), r.minutesBefore || 0])),
    });
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
    const mine = { participantId: req.userId, scheduleId: schedule._id, sentAt: null };
    // Body: { minutesBefore } sets/changes the reminder, { remove: true } turns it
    // off; an empty body toggles (older app versions).
    const hasChoice = req.body && req.body.minutesBefore !== undefined;
    if ((req.body && req.body.remove === true) || !hasChoice) {
      const removed = await ScheduleReminder.findOneAndDelete(mine);
      if (removed || req.body.remove === true) return res.json({ success: true, reminder: false });
    }

    const minutesBefore = hasChoice ? Number(req.body.minutesBefore) : 0;
    if (!REMINDER_MINUTES.includes(minutesBefore)) {
      return res.status(400).json({ success: false, error: 'Choose when to be reminded' });
    }
    const startAt = scheduleStartAt(schedule);
    if (!startAt) {
      return res.status(400).json({ success: false, error: 'This session has no start time' });
    }
    const remindAt = new Date(startAt.getTime() - minutesBefore * 60 * 1000);
    if (startAt <= new Date()) {
      return res.status(400).json({ success: false, error: 'This session has already started' });
    }
    if (remindAt <= new Date()) {
      return res.status(400).json({ success: false, error: 'That time has already passed' });
    }
    // Replaces an old, already-sent reminder for the same session if any.
    await ScheduleReminder.findOneAndUpdate(
      { participantId: req.userId, scheduleId: schedule._id },
      { startAt, minutesBefore, remindAt, sentAt: null },
      { upsert: true }
    );
    res.json({ success: true, reminder: true, minutesBefore });
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
  reorderSchedule,
  deleteSchedule,
  mySpeakerSessions,
  myFavorites,
  toggleFavorite,
};
