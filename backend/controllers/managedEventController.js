const crypto = require('crypto');
const mongoose = require('mongoose');
const ManagedEvent = require('../models/ManagedEvent');
const EventRegistration = require('../models/EventRegistration');
const Apartment = require('../models/Apartment');
const { uploadToCloudinary } = require('../middleware/upload');

/** Every request is scoped to the logged-in management property (from the token). */
function resolveApartmentId(req) {
  return req.apartmentId ? String(req.apartmentId) : null;
}

function generateOtp() {
  return crypto.randomInt(100000, 999999).toString();
}

// Excludes ambiguous characters (0/O, 1/I) for readability on printed badges.
const TICKET_CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
function generateTicketCode() {
  let code = '';
  for (let i = 0; i < 5; i += 1) {
    code += TICKET_CODE_CHARS[crypto.randomInt(TICKET_CODE_CHARS.length)];
  }
  return code;
}

const QUESTION_TYPES = ['short_text', 'long_text', 'single_choice', 'checkboxes'];

function normalizeFormQuestions(raw) {
  if (raw == null) return [];
  if (!Array.isArray(raw)) {
    throw new Error('formQuestions must be an array');
  }
  const seen = new Set();
  return raw.map((q, index) => {
    const id = String(q?.id || crypto.randomBytes(6).toString('hex')).trim();
    if (!id || seen.has(id)) {
      throw new Error('Each form question needs a unique id');
    }
    seen.add(id);
    const label = String(q?.label || '').trim();
    if (!label) {
      throw new Error(`Question ${index + 1} needs a label`);
    }
    const type = String(q?.type || '').trim();
    if (!QUESTION_TYPES.includes(type)) {
      throw new Error(`Invalid question type for "${label}"`);
    }
    const options = Array.isArray(q?.options)
      ? q.options.map((o) => String(o || '').trim()).filter(Boolean)
      : [];
    if ((type === 'single_choice' || type === 'checkboxes') && options.length < 2) {
      throw new Error(`"${label}" needs at least 2 options`);
    }
    return {
      id,
      label,
      type,
      required: !!q?.required,
      options: type === 'single_choice' || type === 'checkboxes' ? options : [],
      order: Number.isFinite(Number(q?.order)) ? Number(q.order) : index,
    };
  });
}

function validateAndBuildAnswers(formQuestions, rawAnswers) {
  const questions = Array.isArray(formQuestions) ? formQuestions : [];
  const incoming = Array.isArray(rawAnswers) ? rawAnswers : [];
  const byId = Object.fromEntries(
    incoming.map((a) => [String(a?.questionId || '').trim(), a])
  );

  const answers = [];
  for (const q of [...questions].sort((a, b) => (a.order || 0) - (b.order || 0))) {
    const raw = byId[q.id];
    let value = raw?.value;

    if (q.type === 'checkboxes') {
      const list = Array.isArray(value)
        ? value.map((v) => String(v || '').trim()).filter(Boolean)
        : value
          ? [String(value).trim()].filter(Boolean)
          : [];
      if (q.required && list.length === 0) {
        throw new Error(`"${q.label}" is required`);
      }
      for (const v of list) {
        if (!q.options.includes(v)) {
          throw new Error(`Invalid option for "${q.label}"`);
        }
      }
      value = list;
    } else if (q.type === 'single_choice') {
      value = value == null ? '' : String(value).trim();
      if (q.required && !value) {
        throw new Error(`"${q.label}" is required`);
      }
      if (value && !q.options.includes(value)) {
        throw new Error(`Invalid option for "${q.label}"`);
      }
    } else {
      value = value == null ? '' : String(value).trim();
      if (q.required && !value) {
        throw new Error(`"${q.label}" is required`);
      }
    }

    answers.push({
      questionId: q.id,
      label: q.label,
      type: q.type,
      value,
    });
  }
  return answers;
}

/** Accepts legacy plain-string inclusions (from before the per-day matrix existed) as well as
 *  the current { name, dates } shape — and tolerates Mongoose returning a bare string when an
 *  old document's inclusions array couldn't be cast to the current subdocument schema. */
function normalizeInclusion(i) {
  if (i == null) return null;
  if (typeof i === 'string') {
    const inclName = i.trim();
    return inclName ? { name: inclName, dates: [] } : null;
  }
  const inclName = String(i?.name || '').trim();
  if (!inclName) return null;
  const dates = Array.isArray(i?.dates)
    ? i.dates.map((d) => String(d || '').trim()).filter(Boolean)
    : [];
  return { name: inclName, dates };
}

function normalizeInclusions(raw) {
  return Array.isArray(raw) ? raw.map(normalizeInclusion).filter(Boolean) : [];
}

function normalizePackages(raw) {
  if (raw == null) return [];
  if (!Array.isArray(raw)) {
    throw new Error('packages must be an array');
  }
  return raw.map((p, index) => {
    const name = String(p?.name || '').trim();
    if (!name) {
      throw new Error(`Package ${index + 1} needs a name`);
    }
    const rate = Number(p?.rate);
    if (!Number.isFinite(rate) || rate < 0) {
      throw new Error(`"${name}" needs a valid rate`);
    }
    const inclusions = normalizeInclusions(p?.inclusions);
    const id = String(p?.id || crypto.randomBytes(6).toString('hex')).trim();
    const rawMode = String(p?.paymentMode || '').trim().toLowerCase();
    const paymentMode = rate > 0 && ['cash', 'card', 'upi'].includes(rawMode) ? rawMode : '';
    return { id, name, rate, paymentMode, inclusions };
  });
}

function buildQrPayload(registration, event) {
  return JSON.stringify({
    type: 'event_ticket',
    registrationId: registration._id.toString(),
    eventId: event._id.toString(),
    ticketCode: registration.ticketCode,
    name: registration.name,
    mobileNumber: registration.mobileNumber,
    otp: registration.otp,
  });
}

function publicEventDto(event) {
  return {
    id: event._id.toString(),
    title: event.title,
    description: event.description,
    venue: event.venue,
    eventDate: event.eventDate,
    eventEndDate: event.eventEndDate,
    bookedCount: event.bookedCount,
    publicSlug: event.publicSlug,
    status: event.status,
    isActive: !!event.isActive,
    formQuestions: Array.isArray(event.formQuestions)
      ? event.formQuestions.map((q) => ({
          id: q.id,
          label: q.label,
          type: q.type,
          required: !!q.required,
          options: q.options || [],
          order: q.order ?? 0,
        }))
      : [],
    packages: Array.isArray(event.packages)
      ? event.packages.map((p) => ({
          id: p.id,
          name: p.name,
          rate: p.rate,
          paymentMode: p.paymentMode || '',
          inclusions: normalizeInclusions(p.inclusions),
        }))
      : [],
    isOpen:
      event.isActive &&
      event.status === 'published' &&
      (!event.eventEndDate || new Date(event.eventEndDate) > new Date()),
  };
}

function registrationDto(reg, event) {
  return {
    id: reg._id.toString(),
    eventId: reg.eventId?.toString?.() || String(reg.eventId),
    name: reg.name,
    mobileNumber: reg.mobileNumber,
    email: reg.email,
    institution: reg.institution || '',
    title: reg.title || '',
    firstName: reg.firstName || '',
    middleName: reg.middleName || '',
    lastName: reg.lastName || '',
    gender: reg.gender || '',
    participantType: reg.participantType || 'Delegate',
    designation: reg.designation || '',
    idNumber: reg.idNumber || '',
    address: reg.address || '',
    photoUrl: reg.photoUrl || '',
    foodPreference: reg.foodPreference || '',
    paymentMode: reg.paymentMode || '',
    utrNumber: reg.utrNumber || '',
    packageId: reg.packageId || '',
    packageName: reg.packageName || '',
    source: reg.source || 'public',
    answers: Array.isArray(reg.answers)
      ? reg.answers.map((a) => ({
          questionId: a.questionId,
          label: a.label,
          type: a.type,
          value: a.value,
        }))
      : [],
    ticketCode: reg.ticketCode,
    otp: reg.otp,
    qrCode: reg.qrCode,
    status: reg.status,
    checkedInAt: reg.checkedInAt,
    claimedInclusions: Array.isArray(reg.claimedInclusions)
      ? reg.claimedInclusions.map((c) => ({
          inclusionName: c.inclusionName,
          claimedAt: c.claimedAt,
        }))
      : [],
    createdAt: reg.createdAt,
    event: event
      ? {
          id: event._id.toString(),
          title: event.title,
          venue: event.venue,
          eventDate: event.eventDate,
          publicSlug: event.publicSlug,
        }
      : undefined,
  };
}

// GET /api/managed-events
const listEvents = async (req, res) => {
  try {
    const apartmentId = resolveApartmentId(req);
    if (!apartmentId) {
      return res.status(400).json({ success: false, error: 'apartmentId is required' });
    }
    const events = await ManagedEvent.find({
      apartmentId: new mongoose.Types.ObjectId(apartmentId),
    }).sort({ eventDate: -1 });
    res.json({
      success: true,
      events: events.map((e) => publicEventDto(e)),
      count: events.length,
    });
  } catch (error) {
    console.error('listEvents error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// POST /api/managed-events
const createEvent = async (req, res) => {
  try {
    const apartmentId = resolveApartmentId(req);
    if (!apartmentId) {
      return res.status(400).json({ success: false, error: 'apartmentId is required' });
    }

    const apt = await Apartment.findById(apartmentId).select('propertyType isActive');
    if (!apt || !apt.isActive) {
      return res.status(404).json({ success: false, error: 'Property not found' });
    }

    const { title, description, venue, eventDate, eventEndDate, status, formQuestions } =
      req.body;
    if (!title || !String(title).trim()) {
      return res.status(400).json({ success: false, error: 'Event title is required' });
    }
    if (!eventDate) {
      return res.status(400).json({ success: false, error: 'Event date is required' });
    }

    let normalizedQuestions = [];
    try {
      normalizedQuestions = normalizeFormQuestions(formQuestions);
    } catch (err) {
      return res.status(400).json({ success: false, error: err.message || 'Invalid form questions' });
    }

    // Events Management properties don't get a public self-registration link.
    let slug = null;
    if (apt.propertyType !== 'events') {
      slug = ManagedEvent.generateSlug();
      // rare collision retry
      for (let i = 0; i < 3; i++) {
        const exists = await ManagedEvent.findOne({ publicSlug: slug }).select('_id');
        if (!exists) break;
        slug = ManagedEvent.generateSlug();
      }
    }

    const event = await ManagedEvent.create({
      apartmentId,
      title: String(title).trim(),
      description: String(description || '').trim(),
      venue: String(venue || '').trim(),
      eventDate: new Date(eventDate),
      eventEndDate: eventEndDate ? new Date(eventEndDate) : null,
      bookedCount: 0,
      // Omit the key entirely (rather than setting null) when there's no
      // slug, so the sparse unique index doesn't collide across events.
      ...(slug ? { publicSlug: slug } : {}),
      formQuestions: normalizedQuestions,
      status: status === 'draft' ? 'draft' : 'published',
      createdBy: req.userId || null,
    });

    res.status(201).json({
      success: true,
      message: 'Event created',
      event: publicEventDto(event),
      registerPath: event.publicSlug ? `/e/${event.publicSlug}` : null,
    });
  } catch (error) {
    console.error('createEvent error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// GET /api/managed-events/:id
const getEvent = async (req, res) => {
  try {
    const apartmentId = resolveApartmentId(req);
    const event = await ManagedEvent.findById(req.params.id);
    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' });
    }
    if (apartmentId && event.apartmentId.toString() !== apartmentId) {
      return res.status(403).json({ success: false, error: 'Not authorized for this event' });
    }
    res.json({ success: true, event: publicEventDto(event) });
  } catch (error) {
    console.error('getEvent error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// PUT /api/managed-events/:id
const updateEvent = async (req, res) => {
  try {
    const apartmentId = resolveApartmentId(req);
    const event = await ManagedEvent.findById(req.params.id);
    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' });
    }
    if (apartmentId && event.apartmentId.toString() !== apartmentId) {
      return res.status(403).json({ success: false, error: 'Not authorized for this event' });
    }

    const {
      title,
      description,
      venue,
      eventDate,
      eventEndDate,
      status,
      isActive,
      formQuestions,
      packages,
    } = req.body;
    if (title != null) event.title = String(title).trim();
    if (description != null) event.description = String(description).trim();
    if (venue != null) event.venue = String(venue).trim();
    if (eventDate != null) event.eventDate = new Date(eventDate);
    if (eventEndDate !== undefined) {
      event.eventEndDate = eventEndDate ? new Date(eventEndDate) : null;
    }
    if (status && ['draft', 'published', 'cancelled', 'completed'].includes(status)) {
      event.status = status;
    }
    if (isActive != null) event.isActive = !!isActive;
    if (formQuestions !== undefined) {
      try {
        event.formQuestions = normalizeFormQuestions(formQuestions);
      } catch (err) {
        return res.status(400).json({ success: false, error: err.message || 'Invalid form questions' });
      }
    }
    if (packages !== undefined) {
      try {
        event.packages = normalizePackages(packages);
      } catch (err) {
        return res.status(400).json({ success: false, error: err.message || 'Invalid packages' });
      }
    }

    await event.save();
    res.json({ success: true, message: 'Event updated', event: publicEventDto(event) });
  } catch (error) {
    console.error('updateEvent error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// DELETE /api/managed-events/:id
const deleteEvent = async (req, res) => {
  try {
    const apartmentId = resolveApartmentId(req);
    const event = await ManagedEvent.findById(req.params.id);
    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' });
    }
    if (apartmentId && event.apartmentId.toString() !== apartmentId) {
      return res.status(403).json({ success: false, error: 'Not authorized for this event' });
    }
    if (String(req.query.permanent || '') === 'true') {
      const removed = await EventRegistration.deleteMany({ eventId: event._id });
      await event.deleteOne();
      return res.json({
        success: true,
        message: 'Event deleted',
        deletedRegistrations: removed.deletedCount || 0,
      });
    }
    // updateOne skips full-document validation, so events whose old packages still hold
    // legacy string inclusions can still be cancelled.
    await ManagedEvent.updateOne({ _id: event._id }, { $set: { status: 'cancelled', isActive: false } });
    event.status = 'cancelled';
    event.isActive = false;
    res.json({ success: true, message: 'Event cancelled', event: publicEventDto(event) });
  } catch (error) {
    console.error('deleteEvent error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// GET /api/managed-events/:id/registrations
const listRegistrations = async (req, res) => {
  try {
    const apartmentId = resolveApartmentId(req);
    const event = await ManagedEvent.findById(req.params.id);
    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' });
    }
    if (apartmentId && event.apartmentId.toString() !== apartmentId) {
      return res.status(403).json({ success: false, error: 'Not authorized for this event' });
    }
    const regs = await EventRegistration.find({ eventId: event._id }).sort({ createdAt: -1 });
    res.json({
      success: true,
      registrations: regs.map((r) => registrationDto(r, event)),
      count: regs.length,
    });
  } catch (error) {
    console.error('listRegistrations error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

const PARTICIPANT_TITLES = ['Dr', 'Mr', 'Ms', 'Prof', 'Baby'];
const PARTICIPANT_GENDERS = ['male', 'female', 'other'];
const FOOD_PREFERENCES = ['veg', 'non-veg'];
const PARTICIPANT_PAYMENT_MODES = ['cash', 'card', 'upi'];

/** Reads the participant profile fields from a request body. `strict` (create) enforces the required ones;
 *  otherwise (edit) only fields that were actually sent are returned. */
function parseParticipantProfile(body, { strict }) {
  const out = {};
  const has = (k) => body[k] !== undefined;
  const str = (k) => String(body[k] ?? '').trim();

  const required = (k, label) => {
    if (strict && !str(k)) throw new Error(`${label} is required`);
  };
  const oneOf = (k, label, allowed, transform = (v) => v) => {
    if (!has(k) && !strict) return;
    required(k, label);
    const v = transform(str(k));
    if (v && !allowed.includes(v)) throw new Error(`Invalid ${label.toLowerCase()}`);
    out[k] = v;
  };

  if (has('title') || strict) {
    required('title', 'Title');
    const t = str('title').replace(/\.$/, '');
    const match = PARTICIPANT_TITLES.find((x) => x.toLowerCase() === t.toLowerCase());
    if (t && !match) throw new Error('Invalid title');
    out.title = match || '';
  }
  if (has('firstName') || strict) {
    required('firstName', 'First name');
    out.firstName = str('firstName');
  }
  if (has('middleName')) out.middleName = str('middleName');
  if (has('lastName') || strict) {
    required('lastName', 'Last name');
    out.lastName = str('lastName');
  }
  oneOf('gender', 'Gender', PARTICIPANT_GENDERS, (v) => v.toLowerCase());
  if (has('participantType') || strict) {
    const t = str('participantType');
    if (!t) throw new Error('Participant type is required');
    if (t.length > 60) throw new Error('Participant type is too long');
    out.participantType = t;
  }
  if (has('designation') || strict) {
    required('designation', 'Designation');
    out.designation = str('designation');
  }
  if (has('institution') || strict) {
    required('institution', 'Organization');
    out.institution = str('institution');
  }
  if (has('idNumber')) out.idNumber = str('idNumber');
  if (has('address')) out.address = str('address');
  if (has('mobileNumber') || strict) {
    required('mobileNumber', 'Mobile number');
    const m = str('mobileNumber').replace(/[\s-]/g, '');
    if (m && !/^\+?\d{10,13}$/.test(m)) throw new Error('Enter a valid mobile number');
    out.mobileNumber = m;
  }
  if (has('email') || strict) {
    required('email', 'Email');
    const e = str('email').toLowerCase();
    if (e && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e)) throw new Error('Enter a valid email address');
    out.email = e;
  }
  oneOf('foodPreference', 'Food preference', FOOD_PREFERENCES, (v) => {
    const t = v.toLowerCase().trim();
    if (/^non[\s-]?veg(etarian)?$/.test(t)) return 'non-veg';
    if (/^veg(etarian)?$/.test(t)) return 'veg';
    return t;
  });
  if (has('paymentMode')) {
    const mode = str('paymentMode').toLowerCase();
    if (mode && !PARTICIPANT_PAYMENT_MODES.includes(mode)) throw new Error('Invalid payment mode');
    out.paymentMode = mode;
  }
  if (has('utrNumber')) out.utrNumber = str('utrNumber');
  return out;
}

function composeParticipantName(p) {
  return [p.firstName, p.middleName, p.lastName].filter(Boolean).join(' ');
}

async function uploadParticipantPhoto(file) {
  if (!file) return '';
  return uploadToCloudinary(file.buffer, 'apartment_management/event_participants');
}

function generateSpotMobilePlaceholder() {
  return `SPOT${crypto.randomBytes(4).toString('hex').toUpperCase()}`;
}

/** Shared by spot + bulk import: builds and saves one registration for a management-created participant. */
async function createParticipantRegistration(event, { name, institution, packageId, ticketCode, source, profile = {} }) {
  const trimmedName = String(profile.firstName ? composeParticipantName(profile) : name || '').trim();
  if (!trimmedName) {
    throw new Error('Name is required');
  }

  let packageName = '';
  if (packageId) {
    const pkg = (event.packages || []).find((p) => p.id === packageId);
    if (!pkg) {
      throw new Error(`Package not found for "${trimmedName}"`);
    }
    packageName = pkg.name;
  }

  let customTicketCode = '';
  const rawTicketCode = String(ticketCode || '').trim().toUpperCase();
  if (rawTicketCode) {
    if (!/^[A-Z0-9]{5}$/.test(rawTicketCode)) {
      throw new Error(`Ticket code for "${trimmedName}" must be exactly 5 letters/digits`);
    }
    const exists = await EventRegistration.findOne({ ticketCode: rawTicketCode }).select('_id').lean();
    if (exists) {
      throw new Error(`Ticket code "${rawTicketCode}" is already in use`);
    }
    customTicketCode = rawTicketCode;
  }

  const otp = generateOtp();
  const registration = new EventRegistration({
    eventId: event._id,
    apartmentId: event.apartmentId,
    name: trimmedName,
    mobileNumber: profile.mobileNumber || generateSpotMobilePlaceholder(),
    email: profile.email || '',
    institution: String(profile.institution ?? institution ?? '').trim(),
    title: profile.title || '',
    firstName: profile.firstName || '',
    middleName: profile.middleName || '',
    lastName: profile.lastName || '',
    gender: profile.gender || '',
    participantType: profile.participantType || '',
    designation: profile.designation || '',
    idNumber: profile.idNumber || '',
    address: profile.address || '',
    photoUrl: profile.photoUrl || '',
    foodPreference: profile.foodPreference || '',
    paymentMode: profile.paymentMode || '',
    utrNumber: profile.utrNumber || '',
    packageId: packageId || '',
    packageName,
    source,
    otp,
    ticketCode: customTicketCode || generateTicketCode(),
    qrCode: '',
    status: 'registered',
  });
  registration.qrCode = buildQrPayload(registration, event);

  // Small code space (5 chars) means collisions are possible — retry a few times.
  // A custom code that turns out to collide (race condition) is not retried —
  // the caller picked it deliberately, so surface the conflict instead.
  for (let attempt = 0; attempt < (customTicketCode ? 1 : 5); attempt += 1) {
    try {
      await registration.save();
      break;
    } catch (err) {
      if (!customTicketCode && err?.code === 11000 && /ticketCode/.test(err.message || '') && attempt < 4) {
        registration.ticketCode = generateTicketCode();
        registration.qrCode = buildQrPayload(registration, event);
        continue;
      }
      if (customTicketCode && err?.code === 11000 && /ticketCode/.test(err.message || '')) {
        throw new Error(`Ticket code "${customTicketCode}" is already in use`);
      }
      if (err?.code === 11000 && /mobileNumber/.test(err.message || '')) {
        throw new Error('A participant with this mobile number is already registered for this event');
      }
      throw err;
    }
  }

  await ManagedEvent.updateOne({ _id: event._id }, { $inc: { bookedCount: 1 } });

  return registration;
}

// POST /api/managed-events/:id/registrations/spot
// @access  Private (management)
const createSpotRegistration = async (req, res) => {
  try {
    const apartmentId = resolveApartmentId(req);
    const event = await ManagedEvent.findById(req.params.id);
    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' });
    }
    if (apartmentId && event.apartmentId.toString() !== apartmentId) {
      return res.status(403).json({ success: false, error: 'Not authorized for this event' });
    }

    const { packageId, ticketCode } = req.body;
    let registration;
    try {
      const profile = parseParticipantProfile(req.body, { strict: true });
      if (!String(packageId || '').trim()) throw new Error('Package is required');
      const chosenPackage = (event.packages || []).find((p) => p.id === String(packageId).trim());
      if (chosenPackage && Number(chosenPackage.rate) > 0 && !profile.paymentMode) {
        throw new Error('Payment mode is required');
      }
      if (chosenPackage && Number(chosenPackage.rate) === 0) {
        profile.paymentMode = '';
        profile.utrNumber = '';
      }
      if (req.file) profile.photoUrl = await uploadParticipantPhoto(req.file);
      registration = await createParticipantRegistration(event, { packageId, ticketCode, source: 'spot', profile });
    } catch (err) {
      return res.status(400).json({ success: false, error: err.message || 'Failed to register participant' });
    }

    res.status(201).json({
      success: true,
      message: 'Participant registered',
      registration: registrationDto(registration, event),
    });
  } catch (error) {
    console.error('createSpotRegistration error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// PUT /api/managed-events/:id/registrations/:regId
// @access  Private (management)
const updateRegistration = async (req, res) => {
  try {
    const apartmentId = resolveApartmentId(req);
    const event = await ManagedEvent.findById(req.params.id);
    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' });
    }
    if (apartmentId && event.apartmentId.toString() !== apartmentId) {
      return res.status(403).json({ success: false, error: 'Not authorized for this event' });
    }

    const reg = await EventRegistration.findOne({ _id: req.params.regId, eventId: event._id });
    if (!reg) {
      return res.status(404).json({ success: false, error: 'Registration not found' });
    }

    const { name, institution, packageId, ticketCode } = req.body;
    let profile;
    try {
      profile = parseParticipantProfile(req.body, { strict: false });
      if (req.file) profile.photoUrl = await uploadParticipantPhoto(req.file);
    } catch (err) {
      return res.status(400).json({ success: false, error: err.message || 'Invalid participant details' });
    }
    Object.entries(profile).forEach(([k, v]) => {
      if (k === 'mobileNumber' && !v) return;
      reg[k] = v;
    });
    if (profile.firstName !== undefined || profile.middleName !== undefined || profile.lastName !== undefined) {
      const composed = composeParticipantName(reg);
      if (composed) reg.name = composed;
    }
    if (name != null && profile.firstName === undefined) {
      const trimmedName = String(name).trim();
      if (!trimmedName) {
        return res.status(400).json({ success: false, error: 'Name is required' });
      }
      reg.name = trimmedName;
    }

    if (institution !== undefined) {
      reg.institution = String(institution || '').trim();
    }

    if (packageId !== undefined) {
      if (packageId) {
        const pkg = (event.packages || []).find((p) => p.id === packageId);
        if (!pkg) {
          return res.status(400).json({ success: false, error: 'Selected package not found' });
        }
        reg.packageId = packageId;
        reg.packageName = pkg.name;
      } else {
        reg.packageId = '';
        reg.packageName = '';
      }
    }

    if (ticketCode !== undefined) {
      const rawCode = String(ticketCode || '').trim().toUpperCase();
      if (rawCode && rawCode !== reg.ticketCode) {
        if (!/^[A-Z0-9]{5}$/.test(rawCode)) {
          return res.status(400).json({ success: false, error: 'Ticket code must be exactly 5 letters/digits' });
        }
        const exists = await EventRegistration.findOne({ ticketCode: rawCode, _id: { $ne: reg._id } }).select('_id').lean();
        if (exists) {
          return res.status(400).json({ success: false, error: `Ticket code "${rawCode}" is already in use` });
        }
        reg.ticketCode = rawCode;
        reg.qrCode = buildQrPayload(reg, event);
      }
    }

    await reg.save();

    res.json({
      success: true,
      message: 'Registration updated',
      registration: registrationDto(reg, event),
    });
  } catch (error) {
    if (error?.code === 11000) {
      return res.status(400).json({ success: false, error: 'Ticket code already in use' });
    }
    console.error('updateRegistration error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// DELETE /api/managed-events/:id/registrations/:regId
// @access  Private (management)
const deleteRegistration = async (req, res) => {
  try {
    const apartmentId = resolveApartmentId(req);
    const event = await ManagedEvent.findById(req.params.id);
    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' });
    }
    if (apartmentId && event.apartmentId.toString() !== apartmentId) {
      return res.status(403).json({ success: false, error: 'Not authorized for this event' });
    }

    const reg = await EventRegistration.findOneAndDelete({ _id: req.params.regId, eventId: event._id });
    if (!reg) {
      return res.status(404).json({ success: false, error: 'Registration not found' });
    }

    await ManagedEvent.updateOne({ _id: event._id }, { $inc: { bookedCount: -1 } });

    res.json({
      success: true,
      message: 'Registration deleted',
    });
  } catch (error) {
    console.error('deleteRegistration error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// POST /api/managed-events/:id/registrations/bulk
// Body: { text: "Name, Institution, PackageID\n..." }
// @access  Private (management)
const bulkImportRegistrations = async (req, res) => {
  try {
    const apartmentId = resolveApartmentId(req);
    const event = await ManagedEvent.findById(req.params.id);
    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' });
    }
    if (apartmentId && event.apartmentId.toString() !== apartmentId) {
      return res.status(403).json({ success: false, error: 'Not authorized for this event' });
    }

    const rows = Array.isArray(req.body.participants) ? req.body.participants : [];
    if (rows.length === 0) {
      return res.status(400).json({ success: false, error: 'No participant rows found' });
    }

    const defaultPackageId = String(req.body.packageId || '').trim();
    const packages = event.packages || [];
    const findPackage = (row) => {
      const rawName = String(row.packageName || '').replace(/\s*\(.*\)\s*$/, '').trim().toLowerCase();
      if (rawName) return packages.find((pk) => pk.name.toLowerCase() === rawName) || null;
      return packages.find((pk) => pk.id === defaultPackageId) || null;
    };

    const created = [];
    const failed = [];
    for (let i = 0; i < rows.length; i += 1) {
      const row = rows[i] || {};
      const label = `Row ${row.rowNumber || i + 1}`;
      try {
        const chosenPackage = findPackage(row);
        if (!chosenPackage) {
          throw new Error(row.packageName ? `Package "${row.packageName}" was not found on this event` : 'Package is required');
        }
        const profile = parseParticipantProfile(row, { strict: true });
        if (Number(chosenPackage.rate) > 0 && !profile.paymentMode) {
          throw new Error('Payment mode is required');
        }
        if (Number(chosenPackage.rate) === 0) {
          profile.paymentMode = '';
          profile.utrNumber = '';
        }
        const photo = String(row.photo || '').trim();
        if (/^https?:\/\//i.test(photo)) profile.photoUrl = photo;
        const registration = await createParticipantRegistration(event, {
          packageId: chosenPackage.id,
          ticketCode: row.ticketCode,
          source: 'bulk',
          profile,
        });
        created.push(registrationDto(registration, event));
      } catch (err) {
        failed.push({ line: `${label}: ${[row.firstName, row.lastName].filter(Boolean).join(' ')}`.trim(), error: err.message || 'Failed to register' });
      }
    }

    res.status(201).json({
      success: true,
      message: `${created.length} participant(s) registered${failed.length ? `, ${failed.length} failed` : ''}`,
      registrations: created,
      failed,
    });
  } catch (error) {
    console.error('bulkImportRegistrations error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};


module.exports = {
  listEvents,
  createEvent,
  getEvent,
  updateEvent,
  deleteEvent,
  listRegistrations,
  createSpotRegistration,
  updateRegistration,
  deleteRegistration,
  bulkImportRegistrations,
};
