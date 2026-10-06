const Speaker = require('../models/Speaker');
const SpeakerQuestion = require('../models/SpeakerQuestion');
const EventRegistration = require('../models/EventRegistration');
const EventSchedule = require('../models/EventSchedule');
const SessionQuestion = require('../models/SessionQuestion');
const SessionPoll = require('../models/SessionPoll');
const { participantPackageId, visibleScheduleFilter } = require('../utils/schedulePackages');

const MAX_LENGTH = 1000;

function participantOnly(req, res) {
  if (req.userType === 'participant') return true;
  res.status(403).json({ success: false, error: 'Only participants can do this' });
  return false;
}

function speakerOnly(req, res) {
  if (req.userType === 'speaker') return true;
  res.status(403).json({ success: false, error: 'Only speakers can do this' });
  return false;
}

const adminQuestionDto = (q, speaker) => ({
  id: q._id.toString(),
  participantName: q.participantName || '',
  speakerId: speaker ? speaker._id.toString() : String(q.speakerId || ''),
  speakerName: speaker ? speaker.name : 'Speaker',
  speakerPhoto: speaker ? speaker.photo || '' : '',
  question: q.question,
  answer: q.answer || '',
  answered: !!q.answer,
  answeredAt: q.answeredAt,
  isPublic: q.isPublic === true,
  createdAt: q.createdAt,
});

function handleError(res, label, error) {
  if (error.name === 'CastError') {
    return res.status(404).json({ success: false, error: 'Not found' });
  }
  console.error(`${label} error:`, error);
  return res.status(500).json({ success: false, error: error.message || 'Server error' });
}

/** [speaker] is the populated Speaker for the participant's view. */
const questionDto = (q, speaker) => ({
  id: q._id.toString(),
  question: q.question,
  answer: q.answer || '',
  answered: !!q.answer,
  answeredAt: q.answeredAt,
  createdAt: q.createdAt,
  participantName: q.participantName || '',
  ...(speaker
    ? { speakerId: speaker._id.toString(), speakerName: speaker.name, speakerPhoto: speaker.photo || '' }
    : {}),
});

// GET /api/speaker-questions/speakers — speakers management has enabled for questions.
const listSpeakers = async (req, res) => {
  try {
    if (!participantOnly(req, res)) return;
    const speakers = await Speaker.find({
      apartmentId: req.apartmentId,
      askEnabled: true,
    }).sort({ name: 1 });
    res.json({
      success: true,
      speakers: speakers.map((s) => ({ id: s._id.toString(), name: s.name, photo: s.photo || '' })),
    });
  } catch (error) {
    handleError(res, 'listSpeakers', error);
  }
};

// POST /api/speaker-questions  { speakerId, question }
const askQuestion = async (req, res) => {
  try {
    if (!participantOnly(req, res)) return;
    const question = String(req.body.question || '').trim();
    if (!question) return res.status(400).json({ success: false, error: 'Type your question' });
    if (question.length > MAX_LENGTH) {
      return res
        .status(400)
        .json({ success: false, error: `Question must be under ${MAX_LENGTH} characters` });
    }
    const speaker = await Speaker.findOne({ _id: req.body.speakerId, apartmentId: req.apartmentId });
    if (!speaker || speaker.askEnabled !== true) {
      return res.status(404).json({ success: false, error: 'Speaker not found' });
    }
    const reg = await EventRegistration.findById(req.userId).select('name');
    const created = await SpeakerQuestion.create({
      apartmentId: req.apartmentId,
      speakerId: speaker._id,
      participantId: req.userId,
      participantName: reg ? reg.name : '',
      question,
    });
    res.status(201).json({ success: true, question: questionDto(created, speaker) });
  } catch (error) {
    handleError(res, 'askQuestion', error);
  }
};

// GET /api/speaker-questions/mine — the participant's own questions, newest first.
const myQuestions = async (req, res) => {
  try {
    if (!participantOnly(req, res)) return;
    const list = await SpeakerQuestion.find({ participantId: req.userId })
      .sort({ createdAt: -1 })
      .populate('speakerId', 'name photo');
    res.json({
      success: true,
      questions: list.map((q) => ({
        ...questionDto(q, null),
        speakerId: q.speakerId ? q.speakerId._id.toString() : '',
        speakerName: q.speakerId ? q.speakerId.name : 'Speaker',
        speakerPhoto: q.speakerId ? q.speakerId.photo || '' : '',
      })),
    });
  } catch (error) {
    handleError(res, 'myQuestions', error);
  }
};

// GET /api/speaker-questions/inbox — questions participants asked this speaker.
const speakerInbox = async (req, res) => {
  try {
    if (!speakerOnly(req, res)) return;
    const list = await SpeakerQuestion.find({ speakerId: req.userId }).sort({ createdAt: -1 });
    res.json({ success: true, questions: list.map((q) => questionDto(q, null)) });
  } catch (error) {
    handleError(res, 'speakerInbox', error);
  }
};

// GET /api/speaker-questions/public — published questions and their current answer.
const publicQuestions = async (req, res) => {
  try {
    if (!participantOnly(req, res)) return;
    const list = await SpeakerQuestion.find({
      apartmentId: req.apartmentId,
      isPublic: true,
      answer: { $nin: ['', null] },
    })
      .sort({ updatedAt: -1 })
      .populate('speakerId', 'name photo');
    res.json({
      success: true,
      questions: list.map((q) => ({
        id: q._id.toString(),
        question: q.question,
        answer: q.answer || '',
        answeredAt: q.answeredAt,
        updatedAt: q.updatedAt,
        speakerName: q.speakerId ? q.speakerId.name : 'Speaker',
        speakerPhoto: q.speakerId ? q.speakerId.photo || '' : '',
      })),
    });
  } catch (error) {
    handleError(res, 'publicQuestions', error);
  }
};

// PUT /api/speaker-questions/:id/answer  { answer } — management, and it can be edited.
const adminAnswer = async (req, res) => {
  try {
    const answer = String(req.body.answer || '').trim();
    if (!answer) return res.status(400).json({ success: false, error: 'Type your answer' });
    if (answer.length > MAX_LENGTH) {
      return res
        .status(400)
        .json({ success: false, error: `Answer must be under ${MAX_LENGTH} characters` });
    }
    const existing = await SpeakerQuestion.findOne({
      _id: req.params.id,
      apartmentId: req.apartmentId,
    });
    if (!existing) return res.status(404).json({ success: false, error: 'Question not found' });
    existing.answer = answer;
    existing.answeredAt = new Date();
    await existing.save();
    const speaker = await Speaker.findById(existing.speakerId).select('name photo');
    res.json({ success: true, question: adminQuestionDto(existing, speaker) });
  } catch (error) {
    handleError(res, 'adminAnswer', error);
  }
};

// DELETE /api/speaker-questions/:id — management removes the question and its answer.
const deleteQuestion = async (req, res) => {
  try {
    const existing = await SpeakerQuestion.findOneAndDelete({
      _id: req.params.id,
      apartmentId: req.apartmentId,
    });
    if (!existing) return res.status(404).json({ success: false, error: 'Question not found' });
    res.json({ success: true });
  } catch (error) {
    handleError(res, 'deleteQuestion', error);
  }
};

// PUT /api/speaker-questions/:id/public  { isPublic }
const setPublic = async (req, res) => {
  try {
    const existing = await SpeakerQuestion.findOne({
      _id: req.params.id,
      apartmentId: req.apartmentId,
    });
    if (!existing) return res.status(404).json({ success: false, error: 'Question not found' });
    existing.isPublic = req.body.isPublic === true || req.body.isPublic === 'true';
    await existing.save();
    const speaker = await Speaker.findById(existing.speakerId).select('name photo');
    res.json({ success: true, question: adminQuestionDto(existing, speaker) });
  } catch (error) {
    handleError(res, 'setPublic', error);
  }
};

// POST /api/speaker-questions/:id/answer  { answer } — speaker, one time, final.
const answerQuestion = async (req, res) => {
  try {
    if (!speakerOnly(req, res)) return;
    const answer = String(req.body.answer || '').trim();
    if (!answer) return res.status(400).json({ success: false, error: 'Type your answer' });
    if (answer.length > MAX_LENGTH) {
      return res
        .status(400)
        .json({ success: false, error: `Answer must be under ${MAX_LENGTH} characters` });
    }
    // The filter only matches while it is still unanswered.
    const updated = await SpeakerQuestion.findOneAndUpdate(
      { _id: req.params.id, speakerId: req.userId, answer: '' },
      { answer, answeredAt: new Date() },
      { new: true }
    );
    if (!updated) {
      const exists = await SpeakerQuestion.exists({ _id: req.params.id, speakerId: req.userId });
      return exists
        ? res.status(400).json({ success: false, error: 'You have already answered this question' })
        : res.status(404).json({ success: false, error: 'Question not found' });
    }
    res.json({ success: true, question: questionDto(updated, null) });
  } catch (error) {
    handleError(res, 'answerQuestion', error);
  }
};

// GET /api/speaker-questions/session-questions — every question speakers put on
// their sessions, for the participant to answer in one place (own answer only).
const sessionQuestionsForParticipant = async (req, res) => {
  try {
    if (!participantOnly(req, res)) return;
    const questions = await SessionQuestion.find({ apartmentId: req.apartmentId }).sort({
      createdAt: -1,
    });
    const scheduleIds = [...new Set(questions.map((q) => String(q.scheduleId)))];
    const schedules = await EventSchedule.find({
      _id: { $in: scheduleIds },
      ...visibleScheduleFilter(await participantPackageId(req)),
    }).select('scheduleName speakerName speakerPhoto date fromTime');
    const byId = new Map(schedules.map((s) => [String(s._id), s]));
    const me = String(req.userId);
    res.json({
      success: true,
      questions: questions
        .filter((q) => byId.has(String(q.scheduleId)))
        .map((q) => {
          const s = byId.get(String(q.scheduleId));
          const mine = q.answers.find((a) => String(a.participantId) === me);
          return {
            id: q._id.toString(),
            scheduleId: String(q.scheduleId),
            question: q.question,
            myAnswer: mine ? mine.text : null,
            createdAt: q.createdAt,
            sessionName: s.scheduleName,
            speakerName: s.speakerName,
            speakerPhoto: s.speakerPhoto || '',
            date: s.date,
            fromTime: s.fromTime,
          };
        }),
    });
  } catch (error) {
    handleError(res, 'sessionQuestionsForParticipant', error);
  }
};

// GET /api/speaker-questions/session-polls — every poll speakers put on their
// sessions, for the participant to vote in one place (own vote only, no counts).
const sessionPollsForParticipant = async (req, res) => {
  try {
    if (!participantOnly(req, res)) return;
    const polls = await SessionPoll.find({ apartmentId: req.apartmentId }).sort({ createdAt: -1 });
    const scheduleIds = [...new Set(polls.map((p) => String(p.scheduleId)))];
    const schedules = await EventSchedule.find({
      _id: { $in: scheduleIds },
      ...visibleScheduleFilter(await participantPackageId(req)),
    }).select('scheduleName speakerName date fromTime');
    const byId = new Map(schedules.map((s) => [String(s._id), s]));
    const me = String(req.userId);
    res.json({
      success: true,
      polls: polls
        .filter((p) => byId.has(String(p.scheduleId)))
        .map((p) => {
          const s = byId.get(String(p.scheduleId));
          const mine = p.votes.find((v) => String(v.participantId) === me);
          return {
            id: p._id.toString(),
            scheduleId: String(p.scheduleId),
            question: p.question,
            options: p.options,
            myVote: mine ? mine.option : null,
            voteCount: p.votes.length,
            createdAt: p.createdAt,
            sessionName: s.scheduleName,
            speakerName: s.speakerName,
            date: s.date,
            fromTime: s.fromTime,
          };
        }),
    });
  } catch (error) {
    handleError(res, 'sessionPollsForParticipant', error);
  }
};

module.exports = {
  sessionPollsForParticipant,
  listSpeakers,
  askQuestion,
  myQuestions,
  publicQuestions,
  adminAnswer,
  deleteQuestion,
  setPublic,
  speakerInbox,
  answerQuestion,
  sessionQuestionsForParticipant,
};
