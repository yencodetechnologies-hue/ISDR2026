/**
 * The eight session-feedback polls on every ISDR 2026 schedule row.
 * Re-running updates these questions in place. Other poll records on the
 * event are removed. Sessions, questions, and ratings are left as they are.
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

/** Panel names stay as stored. A blank or em-dash speaker becomes "the speaker". */
function speakerLabel(name) {
  const text = String(name || '').trim();
  if (!text || text === '—' || text === '-') return 'the speaker';
  return text;
}

/**
 * Keep only the eight feedback polls on this event.
 * Polls that are not one of these eight are deleted. The eight themselves
 * are updated in place, so a matching vote stays on the same choice.
 * Sessions, questions, and ratings are not touched.
 */
async function applySessionFeedbackPolls(event) {
  const schedules = await EventSchedule.find({ eventId: event._id });
  const scheduleIds = schedules.map((row) => row._id);

  const stray = await SessionPoll.deleteMany({
    scheduleId: { $in: scheduleIds },
    templateKey: { $nin: TEMPLATE_KEYS },
  });
  const orphans = await SessionPoll.deleteMany({
    apartmentId: event.apartmentId,
    templateKey: { $in: TEMPLATE_KEYS },
    scheduleId: { $nin: scheduleIds },
  });
  const removed = (stray.deletedCount || 0) + (orphans.deletedCount || 0);

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
    `Feedback polls: ${schedules.length} session(s), ${removed} other poll(s) removed, ${updated} updated, ${created} created. Sessions were not removed.`
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
