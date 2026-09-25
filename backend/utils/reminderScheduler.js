const ScheduleReminder = require('../models/ScheduleReminder');
const EventSchedule = require('../models/EventSchedule');
const { sendNotificationToUser } = require('./fcmService');

/** Session times are Indian Standard Time (UTC+5:30). */
const IST_OFFSET_MINUTES = 330;
const CHECK_EVERY_MS = 60 * 1000;
// A reminder more than this late (e.g. the server was down) is dropped, not sent.
const MAX_LATE_MS = 15 * 60 * 1000;

/**
 * The instant a schedule starts: its calendar day (stored as UTC midnight,
 * read the same way the app does) at `fromTime` in IST.
 */
function scheduleStartAt(schedule) {
  const d = new Date(schedule.date);
  const [h, m] = String(schedule.fromTime || '0:0').split(':').map((n) => parseInt(n, 10) || 0);
  return new Date(
    Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), h, m) -
      IST_OFFSET_MINUTES * 60 * 1000
  );
}

const fmt12 = (hhmm) => {
  const [h, m] = String(hhmm || '').split(':').map((n) => parseInt(n, 10) || 0);
  const suffix = h >= 12 ? 'PM' : 'AM';
  return `${((h + 11) % 12) + 1}:${String(m).padStart(2, '0')} ${suffix}`;
};

let running = false;

/** Sends every reminder whose session has started, once. */
async function sendDueReminders() {
  if (running) return;
  running = true;
  try {
    const now = new Date();
    // Too late to be useful — mark them done without a push.
    await ScheduleReminder.updateMany(
      { sentAt: null, startAt: { $lt: new Date(now.getTime() - MAX_LATE_MS) } },
      { sentAt: now }
    );
    const due = await ScheduleReminder.find({ sentAt: null, startAt: { $lte: now } });
    if (!due.length) return;

    const schedules = await EventSchedule.find({
      _id: { $in: [...new Set(due.map((r) => String(r.scheduleId)))] },
    }).select('apartmentId scheduleName speakerName fromTime toTime hall');
    const byId = new Map(schedules.map((s) => [String(s._id), s]));

    for (const reminder of due) {
      // Claim it first so a second server/tick can't send it again.
      const claimed = await ScheduleReminder.findOneAndUpdate(
        { _id: reminder._id, sentAt: null },
        { sentAt: new Date() }
      );
      if (!claimed) continue;
      const schedule = byId.get(String(reminder.scheduleId));
      if (!schedule) continue; // session deleted
      const details = [
        `${fmt12(schedule.fromTime)} - ${fmt12(schedule.toTime)}`,
        schedule.hall,
        schedule.speakerName,
      ]
        .filter(Boolean)
        .join(' · ');
      await sendNotificationToUser(String(reminder.participantId), 'participant', {
        title: `Starting now: ${schedule.scheduleName}`,
        body: details,
        type: 'schedule_reminder',
        data: { scheduleId: String(schedule._id) },
        apartmentId: schedule.apartmentId,
      });
    }
  } catch (error) {
    console.error('Reminder check failed:', error.message);
  } finally {
    running = false;
  }
}

function startReminderScheduler() {
  setInterval(sendDueReminders, CHECK_EVERY_MS);
  sendDueReminders();
  console.log('Schedule reminders: checking every minute');
}

module.exports = { startReminderScheduler, scheduleStartAt };
