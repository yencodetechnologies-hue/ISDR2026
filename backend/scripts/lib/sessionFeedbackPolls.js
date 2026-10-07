/**
 * The eight session-feedback polls on ISDR 2026 speaker sessions from 8 October
 * onward. 7 October, paper and e-poster blocks, and refreshment, lunch, and
 * dinner breaks get no polls. Any polls already stored on a skipped session
 * are removed. Re-running updates these questions in place. Other poll
 * records on the event are removed. Sessions, questions, and ratings are
 * left as they are.
 */
const EventSchedule = require('../../models/EventSchedule');
const SessionPoll = require('../../models/SessionPoll');

const TEMPLATES = [
  {
    key: 'session-rating',
    question: () => 'How would you rate this session?',
    options: ['Excellent', 'Very Good', 'Good', 'Needs improvement'],
  },
  {
    key: 'hear-again',
    question: (row) => `Would you like to hear more from ${speakerLabel(row.speakerName)} in future conferences?`,
    options: ['Definitely', 'Yes', 'Maybe', 'Not sure'],
  },
  {
    key: 'usefulness',
    question: (row) => `How useful was the session: ${row.scheduleName}?`,
    options: ['Extremely useful', 'Very useful', 'Useful', 'Not very useful'],
  },
  {
    key: 'most-valuable',
    question: () => 'What did you find most valuable in this session?',
    options: [
      'New clinical knowledge',
      'Surgical techniques',
      'Case discussions',
      'Research updates',
      'Practical tips',
    ],
  },
  {
    key: 'engaging',
    question: () => 'How engaging was the speaker’s presentation?',
    options: [
      'Highly engaging',
      'Very engaging',
      'Moderately engaging',
      'Could be more engaging',
    ],
  },
  {
    key: 'relevance',
    question: () => 'How relevant was the topic to your clinical practice?',
    options: ['Highly Relevant', 'Very Relevant', 'Somewhat Relevant', 'Not Relevant'],
  },
  {
    key: 'clarity',
    question: () => 'How clear and effective was the speaker’s presentation?',
    options: ['Excellent', 'Very Good', 'Good', 'Needs Improvement'],
  },
  {
    key: 'insights',
    question: () => 'Did this session provide new insights for you?',
    options: ['Definitely', 'Yes, Several', 'A Few', 'Not Really'],
  },
];

const TEMPLATE_KEYS = TEMPLATES.map((template) => template.key);

/** Student-conference day. These sessions do not get feedback polls. */
const SKIP_DAY = '2026-10-07';

function istDay(date) {
  return new Date(date).toLocaleDateString('en-CA', { timeZone: 'Asia/Kolkata' });
}

function isSkippedDay(schedule) {
  return Boolean(schedule.date) && istDay(schedule.date) === SKIP_DAY;
}

/** Delegate paper, free-paper, e-paper, and e-poster blocks do not get feedback polls. */
function isPaperOrEposterSession(schedule) {
  const name = String(schedule.scheduleName || '');
  return /paper\s*presentation/i.test(name)
    || /free\s*papers?/i.test(name)
    || /scientific\s*papers?/i.test(name)
    || /e-?posters?/i.test(name)
    || /e-?papers?/i.test(name);
}

function isMealBreak(schedule) {
  const name = String(schedule.scheduleName || '');
  return /\blunch\b/i.test(name) || /\bdinner\b/i.test(name) || /refreshment/i.test(name);
}

function isSkipped(schedule) {
  return isSkippedDay(schedule) || isPaperOrEposterSession(schedule) || isMealBreak(schedule);
}

/** Panel names stay as stored. A blank or em-dash speaker becomes "the speaker". */
function speakerLabel(name) {
  const text = String(name || '').trim();
  if (!text || text === '—' || text === '-') return 'the speaker';
  return text;
}

/**
 * Keep only the eight feedback polls on this event, except 7 October, paper
 * or e-poster presentation sessions, and refreshment, lunch, and dinner
 * breaks. Every poll on a skipped session is deleted and none are created.
 * On the remaining sessions, polls that are not one of these eight are
 * deleted. The eight themselves are updated in place, so a matching vote
 * stays on the same choice. Sessions, questions, and ratings are not touched.
 */
async function applySessionFeedbackPolls(event) {
  const all = await EventSchedule.find({ eventId: event._id });
  const skipped = all.filter(isSkipped);
  const schedules = all.filter((row) => !isSkipped(row));
  const scheduleIds = schedules.map((row) => row._id);
  const skippedIds = skipped.map((row) => row._id);

  const cleared = skippedIds.length
    ? await SessionPoll.deleteMany({ scheduleId: { $in: skippedIds } })
    : { deletedCount: 0 };
  const stray = await SessionPoll.deleteMany({
    scheduleId: { $in: scheduleIds },
    templateKey: { $nin: TEMPLATE_KEYS },
  });
  const orphans = await SessionPoll.deleteMany({
    apartmentId: event.apartmentId,
    templateKey: { $in: TEMPLATE_KEYS },
    scheduleId: { $nin: scheduleIds },
  });
  const removed =
    (cleared.deletedCount || 0) + (stray.deletedCount || 0) + (orphans.deletedCount || 0);

  const existing = await SessionPoll.find({
    scheduleId: { $in: scheduleIds },
    templateKey: { $in: TEMPLATE_KEYS },
  }).select('_id scheduleId templateKey');
  const byPair = new Map(existing.map((poll) => [`${poll.scheduleId}:${poll.templateKey}`, poll]));

  const base = Date.now();
  const ops = [];
  let created = 0;
  let updated = 0;
  schedules.forEach((schedule, scheduleIndex) => {
    TEMPLATES.forEach((template, templateIndex) => {
      const question = template.question(schedule);
      const found = byPair.get(`${schedule._id}:${template.key}`);
      if (!found) {
        const at = new Date(base + scheduleIndex * TEMPLATES.length + templateIndex);
        ops.push({
          insertOne: {
            document: {
              scheduleId: schedule._id,
              apartmentId: event.apartmentId,
              templateKey: template.key,
              question,
              options: template.options,
              votes: [],
              createdAt: at,
              updatedAt: at,
            },
          },
        });
        created += 1;
        return;
      }
      ops.push({
        updateOne: {
          filter: { _id: found._id },
          update: { $set: { question, options: template.options } },
        },
      });
      updated += 1;
    });
  });
  if (ops.length) await SessionPoll.bulkWrite(ops);

  console.log(
    `Feedback polls: ${schedules.length} session(s), ${skipped.length} skipped (7 October, paper, e-poster, meals), ${removed} poll(s) removed, ${updated} updated, ${created} created. Sessions were not removed.`
  );
  return {
    schedules: schedules.length,
    removed,
    updated,
    created,
  };
}

module.exports = {
  TEMPLATES,
  applySessionFeedbackPolls,
};
