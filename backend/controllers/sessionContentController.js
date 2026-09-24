const EventSchedule = require('../models/EventSchedule');
const EventRegistration = require('../models/EventRegistration');
const SessionPoll = require('../models/SessionPoll');
const SessionQuestion = require('../models/SessionQuestion');
const SessionRating = require('../models/SessionRating');

const MAX_POLL_OPTIONS = 6;
const MAX_ANSWER_LENGTH = 1000;
const MAX_COMMENT_LENGTH = 1000;

/**
 * Loads the session (schedule row) and works out whether the caller is its speaker
 * (the speaker the schedule was created with).
 */
async function loadSession(req, res) {
  const schedule = await EventSchedule.findById(req.params.scheduleId).select(
    'apartmentId speakerId'
  );
  if (!schedule || String(schedule.apartmentId) !== String(req.apartmentId)) {
    res.status(404).json({ success: false, error: 'Session not found' });
    return null;
  }
  const isSpeaker =
    req.userType === 'speaker' &&
    !!schedule.speakerId &&
    String(schedule.speakerId) === String(req.userId);
  return { schedule, isSpeaker };
}

function denySpeakerOnly(res) {
  return res
    .status(403)
    .json({ success: false, error: 'Only the speaker of this session can do this' });
}

function denyParticipantOnly(res) {
  return res.status(403).json({ success: false, error: 'Only participants can respond' });
}

function handleError(res, label, error) {
  if (error.name === 'CastError') {
    return res.status(404).json({ success: false, error: 'Not found' });
  }
  console.error(`${label} error:`, error);
  return res.status(500).json({ success: false, error: error.message || 'Server error' });
}

/** Vote counts go to the speaker only; a participant just sees their own vote. */
function pollDto(p, isSpeaker, participantId) {
  const dto = {
    id: p._id.toString(),
    question: p.question,
    options: p.options,
    createdAt: p.createdAt,
  };
  if (isSpeaker) {
    dto.counts = p.options.map((_, i) => p.votes.filter((v) => v.option === i).length);
    dto.totalVotes = p.votes.length;
  }
  if (participantId) {
    const mine = p.votes.find((v) => String(v.participantId) === participantId);
    dto.myVote = mine ? mine.option : null;
  }
  return dto;
}

/** Answers go to the speaker only; a participant just sees their own answer. */
function questionDto(q, isSpeaker, participantId) {
  const dto = {
    id: q._id.toString(),
    question: q.question,
    createdAt: q.createdAt,
  };
  if (isSpeaker) {
    dto.answers = q.answers.map((a) => ({
      name: a.participantName || '',
      text: a.text,
      createdAt: a.createdAt,
    }));
  }
  if (participantId) {
    const mine = q.answers.find((a) => String(a.participantId) === participantId);
    dto.myAnswer = mine ? mine.text : null;
  }
  return dto;
}

const ratingDto = (r) => ({
  name: r.participantName || '',
  stars: r.stars,
  comment: r.comment || '',
  createdAt: r.createdAt,
});

/** Average (1 decimal) and count of a session's ratings. */
function summarize(ratings) {
  const count = ratings.length;
  const average = count ? Math.round((ratings.reduce((s, r) => s + r.stars, 0) / count) * 10) / 10 : 0;
  return { count, average };
}

// GET /api/session-content/:scheduleId
const getContent = async (req, res) => {
  try {
    const ctx = await loadSession(req, res);
    if (!ctx) return;
    const scheduleId = ctx.schedule._id;
    const participantId = req.userType === 'participant' ? String(req.userId) : null;
    const [polls, questions, ratings, myRating] = await Promise.all([
      SessionPoll.find({ scheduleId }).sort({ createdAt: 1 }),
      SessionQuestion.find({ scheduleId }).sort({ createdAt: 1 }),
      // Every rating goes to the speaker only; a participant just gets their own.
      ctx.isSpeaker ? SessionRating.find({ scheduleId }).sort({ createdAt: -1 }) : [],
      participantId ? SessionRating.findOne({ scheduleId, participantId }) : null,
    ]);
    res.json({
      success: true,
      isSpeaker: ctx.isSpeaker,
      canRespond: !!participantId,
      polls: polls.map((p) => pollDto(p, ctx.isSpeaker, participantId)),
      questions: questions.map((q) => questionDto(q, ctx.isSpeaker, participantId)),
      myRating: myRating ? ratingDto(myRating) : null,
      ...(ctx.isSpeaker ? { ratings: ratings.map(ratingDto), ratingSummary: summarize(ratings) } : {}),
    });
  } catch (error) {
    handleError(res, 'getContent', error);
  }
};

// POST /api/session-content/:scheduleId/polls  { question, options: [String] }
const createPoll = async (req, res) => {
  try {
    const ctx = await loadSession(req, res);
    if (!ctx) return;
    if (!ctx.isSpeaker) return denySpeakerOnly(res);
    const question = String(req.body.question || '').trim();
    const options = (Array.isArray(req.body.options) ? req.body.options : [])
      .map((o) => String(o ?? '').trim())
      .filter(Boolean);
    if (!question) return res.status(400).json({ success: false, error: 'Enter the poll question' });
    if (options.length < 2 || options.length > MAX_POLL_OPTIONS) {
      return res.status(400).json({
        success: false,
        error: `A poll needs 2 to ${MAX_POLL_OPTIONS} options`,
      });
    }
    const poll = await SessionPoll.create({
      scheduleId: ctx.schedule._id,
      apartmentId: ctx.schedule.apartmentId,
      question,
      options,
    });
    res.status(201).json({ success: true, poll: pollDto(poll, true, null) });
  } catch (error) {
    handleError(res, 'createPoll', error);
  }
};

// DELETE /api/session-content/:scheduleId/polls/:pollId
const deletePoll = async (req, res) => {
  try {
    const ctx = await loadSession(req, res);
    if (!ctx) return;
    if (!ctx.isSpeaker) return denySpeakerOnly(res);
    const removed = await SessionPoll.findOneAndDelete({
      _id: req.params.pollId,
      scheduleId: ctx.schedule._id,
    });
    if (!removed) return res.status(404).json({ success: false, error: 'Poll not found' });
    res.json({ success: true });
  } catch (error) {
    handleError(res, 'deletePoll', error);
  }
};

// PUT /api/session-content/:scheduleId/polls/:pollId  { question, options?: [String] }
// The question can always be edited; options only while nobody has voted.
const updatePoll = async (req, res) => {
  try {
    const ctx = await loadSession(req, res);
    if (!ctx) return;
    if (!ctx.isSpeaker) return denySpeakerOnly(res);
    const poll = await SessionPoll.findOne({ _id: req.params.pollId, scheduleId: ctx.schedule._id });
    if (!poll) return res.status(404).json({ success: false, error: 'Poll not found' });

    const question = String(req.body.question || '').trim();
    if (!question) return res.status(400).json({ success: false, error: 'Enter the poll question' });

    let options = null;
    if (Array.isArray(req.body.options)) {
      options = req.body.options.map((o) => String(o ?? '').trim()).filter(Boolean);
      if (options.length < 2 || options.length > MAX_POLL_OPTIONS) {
        return res.status(400).json({
          success: false,
          error: `A poll needs 2 to ${MAX_POLL_OPTIONS} options`,
        });
      }
    }
    const optionsChanged =
      !!options &&
      (options.length !== poll.options.length || options.some((o, i) => o !== poll.options[i]));
    const lockedError = {
      success: false,
      error: "Options can't be changed after participants have voted",
    };
    if (optionsChanged && poll.votes.length) return res.status(400).json(lockedError);

    // With new options, only update while there are still no votes.
    const filter = { _id: poll._id };
    const update = { question };
    if (optionsChanged) {
      filter.votes = { $size: 0 };
      update.options = options;
    }
    const updated = await SessionPoll.findOneAndUpdate(filter, update, { new: true });
    if (!updated) return res.status(400).json(lockedError);
    res.json({ success: true, poll: pollDto(updated, true, null) });
  } catch (error) {
    handleError(res, 'updatePoll', error);
  }
};

// POST /api/session-content/:scheduleId/polls/:pollId/vote  { option }
const votePoll = async (req, res) => {
  try {
    const ctx = await loadSession(req, res);
    if (!ctx) return;
    if (req.userType !== 'participant') return denyParticipantOnly(res);
    const poll = await SessionPoll.findOne({ _id: req.params.pollId, scheduleId: ctx.schedule._id });
    if (!poll) return res.status(404).json({ success: false, error: 'Poll not found' });
    const option = Number(req.body.option);
    if (!Number.isInteger(option) || option < 0 || option >= poll.options.length) {
      return res.status(400).json({ success: false, error: 'Choose one of the options' });
    }
    // One vote per participant — the filter only matches if they haven't voted yet.
    const updated = await SessionPoll.findOneAndUpdate(
      { _id: poll._id, 'votes.participantId': { $ne: req.userId } },
      { $push: { votes: { participantId: req.userId, option } } },
      { new: true }
    );
    if (!updated) {
      return res.status(400).json({ success: false, error: 'You have already voted on this poll' });
    }
    res.json({ success: true, poll: pollDto(updated, false, String(req.userId)) });
  } catch (error) {
    handleError(res, 'votePoll', error);
  }
};

// POST /api/session-content/:scheduleId/questions  { question }
const createQuestion = async (req, res) => {
  try {
    const ctx = await loadSession(req, res);
    if (!ctx) return;
    if (!ctx.isSpeaker) return denySpeakerOnly(res);
    const question = String(req.body.question || '').trim();
    if (!question) return res.status(400).json({ success: false, error: 'Enter the question' });
    const q = await SessionQuestion.create({
      scheduleId: ctx.schedule._id,
      apartmentId: ctx.schedule.apartmentId,
      question,
    });
    res.status(201).json({ success: true, question: questionDto(q, true, null) });
  } catch (error) {
    handleError(res, 'createQuestion', error);
  }
};

// DELETE /api/session-content/:scheduleId/questions/:questionId
const deleteQuestion = async (req, res) => {
  try {
    const ctx = await loadSession(req, res);
    if (!ctx) return;
    if (!ctx.isSpeaker) return denySpeakerOnly(res);
    const removed = await SessionQuestion.findOneAndDelete({
      _id: req.params.questionId,
      scheduleId: ctx.schedule._id,
    });
    if (!removed) return res.status(404).json({ success: false, error: 'Question not found' });
    res.json({ success: true });
  } catch (error) {
    handleError(res, 'deleteQuestion', error);
  }
};

// PUT /api/session-content/:scheduleId/questions/:questionId  { question }
// Editable only until the first participant answers.
const updateQuestion = async (req, res) => {
  try {
    const ctx = await loadSession(req, res);
    if (!ctx) return;
    if (!ctx.isSpeaker) return denySpeakerOnly(res);
    const question = String(req.body.question || '').trim();
    if (!question) return res.status(400).json({ success: false, error: 'Enter the question' });
    const updated = await SessionQuestion.findOneAndUpdate(
      { _id: req.params.questionId, scheduleId: ctx.schedule._id, answers: { $size: 0 } },
      { question },
      { new: true }
    );
    if (!updated) {
      const exists = await SessionQuestion.exists({
        _id: req.params.questionId,
        scheduleId: ctx.schedule._id,
      });
      return exists
        ? res.status(400).json({
            success: false,
            error: "This question can't be edited because participants have answered it",
          })
        : res.status(404).json({ success: false, error: 'Question not found' });
    }
    res.json({ success: true, question: questionDto(updated, true, null) });
  } catch (error) {
    handleError(res, 'updateQuestion', error);
  }
};

// POST /api/session-content/:scheduleId/questions/:questionId/answer  { text }
const answerQuestion = async (req, res) => {
  try {
    const ctx = await loadSession(req, res);
    if (!ctx) return;
    if (req.userType !== 'participant') return denyParticipantOnly(res);
    const text = String(req.body.text || '').trim();
    if (!text) return res.status(400).json({ success: false, error: 'Type your answer' });
    if (text.length > MAX_ANSWER_LENGTH) {
      return res
        .status(400)
        .json({ success: false, error: `Answer must be under ${MAX_ANSWER_LENGTH} characters` });
    }
    const reg = await EventRegistration.findById(req.userId).select('name');
    // One answer per participant — the filter only matches if they haven't answered yet.
    const updated = await SessionQuestion.findOneAndUpdate(
      {
        _id: req.params.questionId,
        scheduleId: ctx.schedule._id,
        'answers.participantId': { $ne: req.userId },
      },
      { $push: { answers: { participantId: req.userId, participantName: reg ? reg.name : '', text } } },
      { new: true }
    );
    if (!updated) {
      const exists = await SessionQuestion.exists({
        _id: req.params.questionId,
        scheduleId: ctx.schedule._id,
      });
      return exists
        ? res.status(400).json({ success: false, error: 'You have already answered this question' })
        : res.status(404).json({ success: false, error: 'Question not found' });
    }
    res.json({ success: true, question: questionDto(updated, false, String(req.userId)) });
  } catch (error) {
    handleError(res, 'answerQuestion', error);
  }
};

// POST /api/session-content/:scheduleId/rating  { stars: 1-5, comment }
// One rating per participant per session; final once submitted.
const rateSession = async (req, res) => {
  try {
    const ctx = await loadSession(req, res);
    if (!ctx) return;
    if (req.userType !== 'participant') return denyParticipantOnly(res);
    const stars = Number(req.body.stars);
    if (!Number.isInteger(stars) || stars < 1 || stars > 5) {
      return res.status(400).json({ success: false, error: 'Choose 1 to 5 stars' });
    }
    const comment = String(req.body.comment || '').trim();
    if (comment.length > MAX_COMMENT_LENGTH) {
      return res
        .status(400)
        .json({ success: false, error: `Comment must be under ${MAX_COMMENT_LENGTH} characters` });
    }
    const exists = await SessionRating.exists({ scheduleId: ctx.schedule._id, participantId: req.userId });
    if (exists) {
      return res.status(400).json({ success: false, error: 'You have already rated this session' });
    }
    const reg = await EventRegistration.findById(req.userId).select('name');
    const rating = await SessionRating.create({
      scheduleId: ctx.schedule._id,
      apartmentId: ctx.schedule.apartmentId,
      participantId: req.userId,
      participantName: reg ? reg.name : '',
      stars,
      comment,
    });
    res.status(201).json({ success: true, rating: ratingDto(rating) });
  } catch (error) {
    // Duplicate key = a second rating raced the first.
    if (error.code === 11000) {
      return res.status(400).json({ success: false, error: 'You have already rated this session' });
    }
    handleError(res, 'rateSession', error);
  }
};

module.exports = {
  getContent,
  createPoll,
  updatePoll,
  deletePoll,
  votePoll,
  createQuestion,
  updateQuestion,
  deleteQuestion,
  answerQuestion,
  rateSession,
};
