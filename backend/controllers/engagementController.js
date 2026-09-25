const EventSchedule = require('../models/EventSchedule');
const SessionQuestion = require('../models/SessionQuestion');
const SessionPoll = require('../models/SessionPoll');
const SpeakerQuestion = require('../models/SpeakerQuestion');
const Speaker = require('../models/Speaker');

/**
 * Management's read-only view of all Q&A and polls on its property: speakers'
 * session questions with every participant answer, polls with results, and
 * participants' direct questions to speakers with the answers.
 */

function handleError(res, label, error) {
  console.error(`${label} error:`, error);
  return res.status(500).json({ success: false, error: error.message || 'Server error' });
}

/** Session name, speaker and date for each schedule id, keyed by id. */
async function sessionInfo(scheduleIds) {
  const schedules = await EventSchedule.find({ _id: { $in: scheduleIds } }).select(
    'scheduleName speakerName date fromTime'
  );
  return new Map(
    schedules.map((s) => [
      String(s._id),
      {
        sessionName: s.scheduleName,
        speakerName: s.speakerName,
        date: s.date,
        fromTime: s.fromTime,
      },
    ])
  );
}

// GET /api/engagement/session-questions
const sessionQuestions = async (req, res) => {
  try {
    const questions = await SessionQuestion.find({ apartmentId: req.apartmentId }).sort({
      createdAt: -1,
    });
    const info = await sessionInfo([...new Set(questions.map((q) => String(q.scheduleId)))]);
    res.json({
      success: true,
      questions: questions
        .filter((q) => info.has(String(q.scheduleId)))
        .map((q) => ({
          id: q._id.toString(),
          question: q.question,
          createdAt: q.createdAt,
          ...info.get(String(q.scheduleId)),
          answers: q.answers.map((a) => ({
            name: a.participantName || '',
            text: a.text,
            createdAt: a.createdAt,
          })),
        })),
    });
  } catch (error) {
    handleError(res, 'engagement sessionQuestions', error);
  }
};

// GET /api/engagement/session-polls
const sessionPolls = async (req, res) => {
  try {
    const polls = await SessionPoll.find({ apartmentId: req.apartmentId }).sort({ createdAt: -1 });
    const info = await sessionInfo([...new Set(polls.map((p) => String(p.scheduleId)))]);
    res.json({
      success: true,
      polls: polls
        .filter((p) => info.has(String(p.scheduleId)))
        .map((p) => ({
          id: p._id.toString(),
          question: p.question,
          options: p.options,
          counts: p.options.map((_, i) => p.votes.filter((v) => v.option === i).length),
          totalVotes: p.votes.length,
          createdAt: p.createdAt,
          ...info.get(String(p.scheduleId)),
        })),
    });
  } catch (error) {
    handleError(res, 'engagement sessionPolls', error);
  }
};

// GET /api/engagement/speaker-questions
const speakerQuestions = async (req, res) => {
  try {
    const list = await SpeakerQuestion.find({ apartmentId: req.apartmentId }).sort({
      createdAt: -1,
    });
    const speakers = await Speaker.find({
      _id: { $in: [...new Set(list.map((q) => String(q.speakerId)))] },
    }).select('name photo');
    const byId = new Map(speakers.map((s) => [String(s._id), s]));
    res.json({
      success: true,
      questions: list.map((q) => {
        const speaker = byId.get(String(q.speakerId));
        return {
          id: q._id.toString(),
          participantName: q.participantName || '',
          speakerName: speaker ? speaker.name : 'Speaker',
          speakerPhoto: speaker ? speaker.photo || '' : '',
          question: q.question,
          answer: q.answer || '',
          answered: !!q.answer,
          answeredAt: q.answeredAt,
          createdAt: q.createdAt,
        };
      }),
    });
  } catch (error) {
    handleError(res, 'engagement speakerQuestions', error);
  }
};

module.exports = { sessionQuestions, sessionPolls, speakerQuestions };
