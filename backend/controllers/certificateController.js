const mongoose = require('mongoose');
const ManagedEvent = require('../models/ManagedEvent');
const EventRegistration = require('../models/EventRegistration');
const { resolveRegistrationForCode } = require('../utils/passCodeResolver');
const {
  certificatesFor,
  parseFeedbackAnswers,
  questionsFor,
  cleanQuestion,
  compactOrder,
  newQuestionKey,
  ConferenceFeedbackQuestion,
} = require('../utils/conferenceFeedback');

// A certificate opens when entry and exit are both scanned on each of the
// event's last REQUIRED_DAYS days, or when the admin unlocks it.
const REQUIRED_DAYS = 3;

const istDay = (d) => new Date(d).toLocaleDateString('en-CA', { timeZone: 'Asia/Kolkata' });

function eventDays(event) {
  if (!event || !event.eventDate) return [];
  const out = [];
  let d = new Date(`${istDay(event.eventDate)}T00:00:00Z`);
  const end = new Date(`${istDay(event.eventEndDate || event.eventDate)}T00:00:00Z`);
  while (d <= end && out.length < 60) {
    out.push(d.toISOString().slice(0, 10));
    d = new Date(d.getTime() + 86400000);
  }
  return out;
}

/** Authorized entry & exit dates for the participant's package (fallback to all event days). */
function packageAllowedDates(reg, event) {
  if (!event) return [];
  const pkg = (event.packages || []).find(
    (p) => (reg.packageId && p.id === reg.packageId) || (reg.packageName && p.name === reg.packageName)
  );
  if (pkg && Array.isArray(pkg.entryExitDates) && pkg.entryExitDates.length > 0) {
    return pkg.entryExitDates;
  }
  return eventDays(event);
}

/** Day-by-day entry/exit progress and whether the certificate is open. */
function certificateStatus(reg, event) {
  const allowed = packageAllowedDates(reg, event);
  const days = allowed.map((date) => {
    const a = (reg.attendance || []).find((x) => x.day === date) || {};
    return { date, entryAt: a.entryAt || null, exitAt: a.exitAt || null };
  });
  const complete = (d) => Boolean(d.entryAt && d.exitAt);
  const earned = days.length > 0 && days.every(complete);
  const revoked = Boolean(reg.certificateRevoked);
  return {
    days,
    allScanned: days.length > 0 && days.every(complete),
    earned,
    adminUnlocked: Boolean(reg.certificateUnlocked),
    revoked,
    unlocked: !revoked && (earned || Boolean(reg.certificateUnlocked)),
  };
}

function findRegistration(code, apartmentId = null) {
  return resolveRegistrationForCode(code, apartmentId);
}

const propertyEventIds = async (req) =>
  (
    await ManagedEvent.find({ apartmentId: new mongoose.Types.ObjectId(String(req.apartmentId)) })
      .select('_id title eventDate eventEndDate packages')
      .lean()
  );

// POST /api/certificates/scan { type: 'entry'|'exit', qrData?, idNumber? } — event staff / admin.
// Entry and exit can each be scanned once per participant per event day allowed by their package.
const scanAttendance = async (req, res) => {
  try {
    if (req.userType === 'participant' || req.userType === 'speaker') {
      return res.status(403).json({ success: false, error: 'Not allowed' });
    }
    const type = String(req.body.type || '').toLowerCase();
    if (!['entry', 'exit'].includes(type)) {
      return res.status(400).json({ success: false, error: 'type must be entry or exit' });
    }
    const code = String(req.body.idNumber || req.body.qrData || '').trim();
    if (!code) return res.status(400).json({ success: false, error: 'ID number or QR data is required' });

    const reg = await findRegistration(code, req.apartmentId);
    if (!reg) return res.status(404).json({ success: false, error: 'Participant registration not found' });
    const event = await ManagedEvent.findById(reg.eventId);
    if (!event) return res.status(404).json({ success: false, error: 'Event not found' });

    const registration = {
      name: reg.name,
      idNumber: reg.idNumber,
      institution: reg.institution,
      packageName: reg.packageName || '',
    };
    if (event.status === 'cancelled') {
      return res.json({ success: false, error: 'This event has been cancelled', registration });
    }
    const today = istDay(new Date());
    const isVipOrStaff =
      ['Admin', 'Speaker', 'Event Staff'].includes(reg.participantType) ||
      reg.packageId === 'vip-all-access';
    const allowedDates = packageAllowedDates(reg, event);
    if (!isVipOrStaff && !allowedDates.includes(today)) {
      const pkgLabel = reg.packageName ? ` (${reg.packageName})` : '';
      return res.json({
        success: false,
        error: `Your package${pkgLabel} is not valid for entry/exit today (${today})`,
        registration,
      });
    }

    let day = reg.attendance.find((a) => a.day === today);
    if (type === 'entry') {
      if (day && day.entryAt) {
        return res.json({ success: false, error: 'Entry already scanned today', registration });
      }
      if (!day) {
        reg.attendance.push({ day: today });
        day = reg.attendance[reg.attendance.length - 1];
      }
      day.entryAt = new Date();
      day.entryBy = req.userId || null;
    } else {
      if (!day || !day.entryAt) {
        return res.json({ success: false, error: 'Entry not scanned yet today', registration });
      }
      if (day.exitAt) return res.json({ success: false, error: 'Exit already scanned today', registration });
      day.exitAt = new Date();
      day.exitBy = req.userId || null;
    }
    await reg.save();
    res.json({
      success: true,
      message: `${type === 'entry' ? 'Entry' : 'Exit'} recorded`,
      registration,
    });
  } catch (error) {
    console.error('scanAttendance error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// GET /api/certificates/me — the participant's day progress and certificate.
const myCertificate = async (req, res) => {
  try {
    if (req.userType !== 'participant') {
      return res.status(403).json({ success: false, error: 'Only participants have certificates' });
    }
    const reg = await EventRegistration.findById(req.userId);
    if (!reg) return res.status(404).json({ success: false, error: 'Registration not found' });
    const event = await ManagedEvent.findById(reg.eventId);
    const questions = await questionsFor(reg.apartmentId);
    res.json({
      success: true,
      name: [reg.title, reg.name].filter(Boolean).join('. '),
      eventTitle: event ? event.title : '',
      ...certificateStatus(reg, event),
      feedbackSubmitted: Boolean(reg.conferenceFeedbackAt),
      questions,
      certificates: certificatesFor(reg, event),
    });
  } catch (error) {
    console.error('myCertificate error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// GET /api/certificates — admin: every participant with their certificate status.
const listCertificates = async (req, res) => {
  try {
    const events = await propertyEventIds(req);
    const byId = new Map(events.map((e) => [String(e._id), e]));
    const regs = await EventRegistration.find({
      eventId: { $in: events.map((e) => e._id) },
      status: { $ne: 'cancelled' },
    })
      .select(
        'name title firstName middleName lastName idNumber participantType packageId packageName gender designation institution mobileNumber email foodPreference address eventId attendance certificateUnlocked certificateRevoked conferenceFeedback conferenceFeedbackAt'
      )
      .sort({ name: 1 })
      .lean();
    const participants = regs.map((r) => {
      const status = certificateStatus(r, byId.get(String(r.eventId)));
      return {
        id: String(r._id),
        name: r.name || '',
        title: r.title || '',
        firstName: r.firstName || '',
        middleName: r.middleName || '',
        lastName: r.lastName || '',
        idNumber: r.idNumber || '',
        participantType: r.participantType || '',
        packageName: r.packageName || '',
        gender: r.gender || '',
        designation: r.designation || '',
        institution: r.institution || '',
        mobileNumber: r.mobileNumber || '',
        email: r.email || '',
        foodPreference: r.foodPreference || '',
        address: r.address || '',
        daysScanned: status.days.filter((d) => d.entryAt && d.exitAt).length,
        totalDays: status.days.length,
        earned: status.earned,
        adminUnlocked: status.adminUnlocked,
        revoked: status.revoked,
        unlocked: status.unlocked,
        feedbackSubmitted: Boolean(r.conferenceFeedbackAt),
        conferenceFeedbackAt: r.conferenceFeedbackAt || null,
        feedback: r.conferenceFeedbackAt ? r.conferenceFeedback : null,
      };
    });
    const questions = await questionsFor(req.apartmentId);
    res.json({ success: true, participants, questions });
  } catch (error) {
    console.error('listCertificates error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// POST /api/certificates/unlock { registrationIds: [] } — admin unlocks selected certificates.
const unlockCertificates = async (req, res) => {
  try {
    const ids = (Array.isArray(req.body.registrationIds) ? req.body.registrationIds : []).filter((id) =>
      mongoose.Types.ObjectId.isValid(id)
    );
    if (!ids.length) return res.status(400).json({ success: false, error: 'Select participants' });
    const events = await propertyEventIds(req);
    const result = await EventRegistration.updateMany(
      { _id: { $in: ids }, eventId: { $in: events.map((e) => e._id) } },
      { $set: { certificateUnlocked: true, certificateUnlockedAt: new Date(), certificateRevoked: false } }
    );
    res.json({ success: true, unlocked: result.modifiedCount || 0 });
  } catch (error) {
    console.error('unlockCertificates error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// POST /api/certificates/revert { registrationIds: [] } — admin locks the selected
// certificates again, whether they were unlocked by the admin or earned by scans.
const revertCertificates = async (req, res) => {
  try {
    const ids = (Array.isArray(req.body.registrationIds) ? req.body.registrationIds : []).filter((id) =>
      mongoose.Types.ObjectId.isValid(id)
    );
    if (!ids.length) return res.status(400).json({ success: false, error: 'Select participants' });
    const events = await propertyEventIds(req);
    const result = await EventRegistration.updateMany(
      { _id: { $in: ids }, eventId: { $in: events.map((e) => e._id) } },
      { $set: { certificateUnlocked: false, certificateUnlockedAt: null, certificateRevoked: true } }
    );
    res.json({ success: true, reverted: result.modifiedCount || 0 });
  } catch (error) {
    console.error('revertCertificates error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// POST /api/certificates/feedback { answers } — once, after the certificate is enabled.
const submitFeedback = async (req, res) => {
  try {
    if (req.userType !== 'participant') {
      return res.status(403).json({ success: false, error: 'Only participants can submit this feedback' });
    }
    const reg = await EventRegistration.findById(req.userId);
    if (!reg) return res.status(404).json({ success: false, error: 'Registration not found' });
    if (reg.conferenceFeedbackAt) {
      return res.status(409).json({ success: false, error: 'Feedback has already been submitted' });
    }
    const event = await ManagedEvent.findById(reg.eventId);
    if (!certificateStatus(reg, event).unlocked) {
      return res.status(403).json({ success: false, error: 'Your certificate is not enabled yet' });
    }
    const questions = await questionsFor(reg.apartmentId);
    const parsed = parseFeedbackAnswers(req.body, questions);
    if (parsed.error) return res.status(400).json({ success: false, error: parsed.error });
    reg.conferenceFeedback = parsed.answers;
    reg.conferenceFeedbackAt = new Date();
    reg.markModified('conferenceFeedback');
    await reg.save();
    res.json({ success: true, feedbackSubmitted: true });
  } catch (error) {
    console.error('submitFeedback error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

async function ownedQuestion(req, id) {
  if (!mongoose.Types.ObjectId.isValid(id)) return null;
  return ConferenceFeedbackQuestion.findOne({
    _id: id,
    apartmentId: new mongoose.Types.ObjectId(String(req.apartmentId)),
  });
}

// GET /api/certificates/questions — admin list, seeding the original form once.
const listFeedbackQuestions = async (req, res) => {
  try {
    const questions = await questionsFor(req.apartmentId);
    res.json({ success: true, questions });
  } catch (error) {
    console.error('listFeedbackQuestions error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// POST /api/certificates/questions
const createFeedbackQuestion = async (req, res) => {
  try {
    const parsed = cleanQuestion(req.body);
    if (parsed.error) return res.status(400).json({ success: false, error: parsed.error });
    const apartmentId = new mongoose.Types.ObjectId(String(req.apartmentId));
    await questionsFor(req.apartmentId);
    const count = await ConferenceFeedbackQuestion.countDocuments({ apartmentId });
    await ConferenceFeedbackQuestion.create({
      apartmentId,
      key: newQuestionKey(),
      order: count,
      ...parsed.value,
    });
    res.json({ success: true, questions: await questionsFor(req.apartmentId) });
  } catch (error) {
    console.error('createFeedbackQuestion error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// PUT /api/certificates/questions/:id
const updateFeedbackQuestion = async (req, res) => {
  try {
    const row = await ownedQuestion(req, req.params.id);
    if (!row) return res.status(404).json({ success: false, error: 'Question not found' });
    const parsed = cleanQuestion(req.body);
    if (parsed.error) return res.status(400).json({ success: false, error: parsed.error });
    Object.assign(row, parsed.value);
    await row.save();
    res.json({ success: true, questions: await questionsFor(req.apartmentId) });
  } catch (error) {
    console.error('updateFeedbackQuestion error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// DELETE /api/certificates/questions/:id
const deleteFeedbackQuestion = async (req, res) => {
  try {
    const row = await ownedQuestion(req, req.params.id);
    if (!row) return res.status(404).json({ success: false, error: 'Question not found' });
    await row.deleteOne();
    await compactOrder(row.apartmentId);
    res.json({ success: true, questions: await questionsFor(req.apartmentId) });
  } catch (error) {
    console.error('deleteFeedbackQuestion error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// PUT /api/certificates/questions/reorder { questionIds }
const reorderFeedbackQuestions = async (req, res) => {
  try {
    const ids = (Array.isArray(req.body.questionIds) ? req.body.questionIds : []).filter((id) =>
      mongoose.Types.ObjectId.isValid(id)
    );
    const apartmentId = new mongoose.Types.ObjectId(String(req.apartmentId));
    const rows = await ConferenceFeedbackQuestion.find({ apartmentId });
    if (!ids.length || ids.length !== rows.length) {
      return res.status(400).json({ success: false, error: 'Send every question in the new order' });
    }
    const byId = new Map(rows.map((row) => [String(row._id), row]));
    if (ids.some((id) => !byId.has(id))) {
      return res.status(400).json({ success: false, error: 'Question not found' });
    }
    await Promise.all(ids.map((id, order) => byId.get(id).updateOne({ order })));
    res.json({ success: true, questions: await questionsFor(req.apartmentId) });
  } catch (error) {
    console.error('reorderFeedbackQuestions error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

module.exports = {
  scanAttendance,
  myCertificate,
  listCertificates,
  unlockCertificates,
  revertCertificates,
  submitFeedback,
  listFeedbackQuestions,
  createFeedbackQuestion,
  updateFeedbackQuestion,
  deleteFeedbackQuestion,
  reorderFeedbackQuestions,
};
