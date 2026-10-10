const crypto = require('crypto');
const mongoose = require('mongoose');
const ConferenceFeedbackQuestion = require('../models/ConferenceFeedbackQuestion');

/** Conference feedback collected before a certificate can be downloaded. */

const RATING = ['Excellent', 'Very good', 'Good', 'Fair', 'Poor'];

const DEFAULT_QUESTIONS = [
  {
    id: 'q3',
    number: 3,
    section: 'Scientific programme',
    prompt: 'Relevance and quality of the scientific sessions.',
    type: 'choice',
    required: true,
    options: RATING,
  },
  {
    id: 'q4',
    number: 4,
    section: 'Scientific programme',
    prompt: 'Expertise and presentation skills of the speakers.',
    type: 'choice',
    required: true,
    options: RATING,
  },
  {
    id: 'q5',
    number: 5,
    section: 'Scientific programme',
    prompt: 'Diversity of topics and emerging research areas covered.',
    type: 'choice',
    required: true,
    options: RATING,
  },
  {
    id: 'q6',
    number: 6,
    section: 'Scientific programme',
    prompt: 'Quality of the research presentations and poster sessions.',
    type: 'choice',
    required: true,
    options: RATING,
  },
  {
    id: 'q7',
    number: 7,
    section: 'Scientific programme',
    prompt: 'Opportunities for scientific discussion and interaction.',
    type: 'choice',
    required: true,
    options: RATING,
  },
  {
    id: 'q8',
    number: 8,
    section: 'Scientific programme',
    prompt: 'Relevance of the programme to your academic or professional development.',
    type: 'choice',
    required: true,
    options: RATING,
  },
  {
    id: 'q9',
    number: 9,
    section: 'Scientific programme',
    prompt: 'Overall quality of the scientific programme.',
    type: 'choice',
    required: true,
    options: RATING,
  },
  {
    id: 'q10',
    number: 10,
    section: 'Conference organization',
    prompt: 'Registration process and delegate assistance.',
    type: 'choice',
    required: true,
    options: RATING,
  },
  {
    id: 'q11',
    number: 11,
    section: 'Conference organization',
    prompt: 'Scheduling and time management of sessions.',
    type: 'choice',
    required: true,
    options: RATING,
  },
  {
    id: 'q12',
    number: 12,
    section: 'Conference organization',
    prompt: 'Venue, seating arrangements and audiovisual facilities.',
    type: 'choice',
    required: true,
    options: RATING,
  },
  {
    id: 'q13',
    number: 13,
    section: 'Conference organization',
    prompt: 'Hospitality, food and refreshments.',
    type: 'choice',
    required: true,
    options: RATING,
  },
  {
    id: 'q14',
    number: 14,
    section: 'Conference organization',
    prompt: 'Coordination and support provided by the organizing team.',
    type: 'choice',
    required: true,
    options: RATING,
  },
  {
    id: 'q15',
    number: 15,
    section: 'Conference organization',
    prompt: 'Communication regarding the conference programme and updates.',
    type: 'choice',
    required: true,
    options: RATING,
  },
  {
    id: 'q16',
    number: 16,
    section: 'Overall experience',
    prompt: 'How would you rate your overall conference experience?',
    type: 'choice',
    required: true,
    options: RATING,
  },
  {
    id: 'q17',
    number: 17,
    section: 'Overall experience',
    prompt: 'Did the conference meet your expectations?',
    type: 'choice',
    required: true,
    options: [
      'Exceeded my expectations',
      'Met my expectations',
      'Partially met my expectations',
      'Did not meet my expectations',
    ],
  },
  {
    id: 'q18',
    number: 18,
    section: 'Overall experience',
    prompt: 'Would you recommend future IADR Indian Division conferences to your colleagues?',
    type: 'choice',
    required: true,
    options: ['Definitely yes', 'Probably yes', 'Not sure', 'Probably no', 'Definitely no'],
  },
  {
    id: 'q19',
    number: 19,
    section: 'Overall experience',
    prompt: 'Which session, speaker or activity did you find most valuable?',
    type: 'text',
    required: false,
    multiline: false,
  },
  {
    id: 'q20',
    number: 20,
    section: 'Overall experience',
    prompt: 'What topics would you like to see included in future IADR conferences?',
    type: 'text',
    required: false,
    multiline: true,
  },
  {
    id: 'q21',
    number: 21,
    section: 'Overall experience',
    prompt: 'What aspects of the conference could be improved?',
    type: 'text',
    required: false,
    multiline: true,
  },
  {
    id: 'q22',
    number: 22,
    section: 'Overall experience',
    prompt: 'Any additional comments or suggestions for the organizing committee?',
    type: 'text',
    required: false,
    multiline: true,
  },
];

const CERTIFICATES = {
  student: {
    key: 'student',
    label: 'Student Conference Certificate',
    fileName: 'ISDR2026_Student_Conference_Certificate.pdf',
  },
  delegate: {
    key: 'delegate',
    label: 'Delegate Certificate',
    fileName: 'ISDR2026_Delegate_Certificate.pdf',
  },
};

function registrationPackage(reg, event) {
  const packages = (event && event.packages) || [];
  return (
    packages.find(
      (p) => (reg.packageId && p.id === reg.packageId) || (reg.packageName && p.name === reg.packageName)
    ) || null
  );
}

/** 2000 student packages receive only the student-conference certificate. */
function studentConferenceOnly(reg, event) {
  const pkg = registrationPackage(reg, event);
  const rate = pkg ? Number(pkg.rate) : NaN;
  const name = String((pkg && pkg.name) || reg.packageName || '');
  return rate === 2000 || /\b2000\b/.test(name);
}

function certificatesFor(reg, event) {
  const keys = studentConferenceOnly(reg, event) ? ['student'] : ['student', 'delegate'];
  return keys.map((key) => CERTIFICATES[key]);
}

const MAX_TEXT = 2000;

function toPublic(rows) {
  return rows.map((row, index) => ({
    id: row.key,
    questionId: String(row._id),
    number: index + 1,
    section: row.section,
    prompt: row.prompt,
    type: row.type,
    required: Boolean(row.required),
    options: row.options || [],
    multiline: Boolean(row.multiline),
  }));
}

/** The property's questions, seeding the original form the first time. */
async function questionsFor(apartmentId) {
  if (!apartmentId || !mongoose.Types.ObjectId.isValid(String(apartmentId))) return [];
  const id = new mongoose.Types.ObjectId(String(apartmentId));
  let rows = await ConferenceFeedbackQuestion.find({ apartmentId: id }).sort({ order: 1, createdAt: 1 });
  if (!rows.length) {
    try {
      await ConferenceFeedbackQuestion.insertMany(
        DEFAULT_QUESTIONS.map((q, order) => ({
          apartmentId: id,
          key: q.id,
          section: q.section,
          prompt: q.prompt,
          type: q.type,
          required: Boolean(q.required),
          options: q.options || [],
          multiline: Boolean(q.multiline),
          order,
        }))
      );
    } catch (error) {
      if (error.code !== 11000) throw error;
    }
    rows = await ConferenceFeedbackQuestion.find({ apartmentId: id }).sort({ order: 1, createdAt: 1 });
  }
  return toPublic(rows);
}

/** Returns { value } or { error } for an admin create/update body. */
function cleanQuestion(body) {
  const section = String((body && body.section) || '').trim();
  const prompt = String((body && body.prompt) || '').trim();
  const type = body && (body.type === 'choice' || body.type === 'text') ? body.type : '';
  if (!section) return { error: 'Section is required' };
  if (!prompt) return { error: 'Question is required' };
  if (!type) return { error: 'Choose a question type' };
  if (section.length > 120 || prompt.length > 500) return { error: 'That text is too long' };
  const required = Boolean(body.required);
  const multiline = type === 'text' && Boolean(body.multiline);
  let options = [];
  if (type === 'choice') {
    const raw = Array.isArray(body.options) ? body.options : String(body.options || '').split('\n');
    options = [...new Set(raw.map((item) => String(item).trim()).filter(Boolean))];
    if (options.length < 2) return { error: 'A choice question needs at least two options' };
    if (options.length > 20 || options.some((item) => item.length > 200)) {
      return { error: 'Check the answer options' };
    }
  }
  return { value: { section, prompt, type, required, options, multiline } };
}

async function compactOrder(apartmentId) {
  const rows = await ConferenceFeedbackQuestion.find({ apartmentId }).sort({ order: 1, createdAt: 1 });
  await Promise.all(
    rows.map((row, index) => (row.order === index ? null : row.updateOne({ order: index })))
  );
}

/** Returns { answers } or { error }. */
function parseFeedbackAnswers(body, questions) {
  const raw = body && typeof body.answers === 'object' && body.answers ? body.answers : {};
  const answers = {};
  for (const q of questions) {
    const value = String(raw[q.id] ?? '').trim();
    if (q.required && !value) {
      return { error: 'Please answer every required question' };
    }
    if (!value) continue;
    if (q.type === 'choice' && !(q.options || []).includes(value)) {
      return { error: 'One of the answers is not a valid option' };
    }
    if (q.type === 'text' && value.length > MAX_TEXT) {
      return { error: 'Please keep written answers under 2000 characters' };
    }
    answers[q.id] = value;
  }
  return { answers };
}

function newQuestionKey() {
  return `q_${crypto.randomBytes(6).toString('hex')}`;
}

module.exports = {
  certificatesFor,
  parseFeedbackAnswers,
  questionsFor,
  cleanQuestion,
  compactOrder,
  newQuestionKey,
  ConferenceFeedbackQuestion,
};
