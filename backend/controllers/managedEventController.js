const crypto = require('crypto');
const mongoose = require('mongoose');
const ManagedEvent = require('../models/ManagedEvent');
const EventRegistration = require('../models/EventRegistration');
const Apartment = require('../models/Apartment');
const { uploadToCloudinary } = require('../middleware/upload');

/** Every request is scoped to the logged-in management property (from the token or query for participants). */
function resolveApartmentId(req) {
  return req.apartmentId
    ? String(req.apartmentId)
    : req.query.apartmentId
    ? String(req.query.apartmentId)
    : req.headers['x-apartment-id']
    ? String(req.headers['x-apartment-id'])
    : null;
}

function generateOtp() {
  return crypto.randomInt(100000, 999999).toString();
}

async function generateNextIdNumber(eventId) {
  const registrations = await EventRegistration.find({ eventId })
    .select('idNumber')
    .lean();
  let maxNumber = 1000;
  for (const r of registrations) {
    const raw = String(r.idNumber || '').trim().toUpperCase();
    const digits = raw.startsWith('ID') ? raw.substring(2) : raw;
    const num = parseInt(digits, 10);
    if (!isNaN(num) && num > maxNumber && (raw === `ID${num}` || raw === String(num))) {
      maxNumber = num;
    }
  }
  return `ID${maxNumber + 1}`;
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
  if (typeof raw === 'string') {
    try { raw = JSON.parse(raw); } catch (_) { raw = []; }
  }
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
    idNumber: registration.idNumber,
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
    photoUrl: event.photoUrl || '',
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
    otp: reg.otp,
    qrCode: reg.qrCode,
    status: reg.status,
    checkedInAt: reg.checkedInAt,
    claimedInclusions: Array.isArray(reg.claimedInclusions)
      ? reg.claimedInclusions.map((c) => ({
          id: c._id?.toString(),
          inclusionName: c.inclusionName,
          claimedAt: c.claimedAt,
          reclaimedByAdmin: !!c.reclaimedByAdmin,
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
    const filter = apartmentId
      ? { apartmentId: new mongoose.Types.ObjectId(apartmentId) }
      : {};
    const events = await ManagedEvent.find(filter).sort({ eventDate: -1 });
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

    let photoUrl = '';
    if (req.file) {
      photoUrl = await uploadToCloudinary(req.file.buffer, 'apartment_management/events');
    } else if (req.body.photoUrl) {
      photoUrl = String(req.body.photoUrl).trim();
    }

    const event = await ManagedEvent.create({
      apartmentId,
      title: String(title).trim(),
      description: String(description || '').trim(),
      venue: String(venue || '').trim(),
      photoUrl,
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
    const event = await ManagedEvent.findById(req.params.id);
    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' });
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
      clearPhoto,
      photoUrl,
    } = req.body;
    if (title != null) event.title = String(title).trim();
    if (description != null) event.description = String(description).trim();
    if (venue != null) event.venue = String(venue).trim();
    if (eventDate != null) event.eventDate = new Date(eventDate);
    if (eventEndDate !== undefined) {
      event.eventEndDate = eventEndDate ? new Date(eventEndDate) : null;
    }
    if (req.file) {
      event.photoUrl = await uploadToCloudinary(req.file.buffer, 'apartment_management/events');
    } else if (clearPhoto === 'true' || clearPhoto === true) {
      event.photoUrl = '';
    } else if (photoUrl !== undefined) {
      event.photoUrl = String(photoUrl || '').trim();
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

// Every participant logs in with this password until they change it.
const DEFAULT_PARTICIPANT_PASSWORD = '123456';

function generateSpotMobilePlaceholder() {
  return `SPOT${crypto.randomBytes(4).toString('hex').toUpperCase()}`;
}

/** Shared by spot + bulk import: builds and saves one registration for a management-created participant. */
async function createParticipantRegistration(event, { name, institution, packageId, idNumber, source, profile = {} }) {
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

  const rawIdNumber = String(profile.idNumber ?? idNumber ?? '').trim();
  let finalIdNumber = '';

  if (rawIdNumber) {
    const exists = await EventRegistration.findOne({ eventId: event._id, idNumber: rawIdNumber }).select('_id').lean();
    if (exists) {
      throw new Error(`ID number "${rawIdNumber}" is already in use by another participant`);
    }
    finalIdNumber = rawIdNumber;
  } else {
    finalIdNumber = await generateNextIdNumber(event._id);
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
    idNumber: finalIdNumber,
    address: profile.address || '',
    photoUrl: profile.photoUrl || '',
    foodPreference: profile.foodPreference || '',
    paymentMode: profile.paymentMode || '',
    utrNumber: profile.utrNumber || '',
    packageId: packageId || '',
    packageName,
    source,
    password: DEFAULT_PARTICIPANT_PASSWORD,
    otp,
    qrCode: '',
    status: 'registered',
  });
  registration.qrCode = buildQrPayload(registration, event);

  for (let attempt = 0; attempt < (rawIdNumber ? 1 : 5); attempt += 1) {
    try {
      await registration.save();
      break;
    } catch (err) {
      if (!rawIdNumber && err?.code === 11000 && /idNumber/.test(err.message || '') && attempt < 4) {
        finalIdNumber = await generateNextIdNumber(event._id);
        registration.idNumber = finalIdNumber;
        registration.qrCode = buildQrPayload(registration, event);
        continue;
      }
      if (rawIdNumber && err?.code === 11000 && /idNumber/.test(err.message || '')) {
        throw new Error(`ID number "${rawIdNumber}" is already in use`);
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

    const { packageId, idNumber } = req.body;
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
      }
      if (req.file) profile.photoUrl = await uploadParticipantPhoto(req.file);
      if (idNumber) {
        profile.idNumber = profile.idNumber || idNumber;
      }
      registration = await createParticipantRegistration(event, { packageId, idNumber: profile.idNumber, source: 'spot', profile });
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

    const { name, institution, packageId, idNumber } = req.body;
    let profile;
    try {
      profile = parseParticipantProfile(req.body, { strict: false });
      if (req.file) profile.photoUrl = await uploadParticipantPhoto(req.file);
    } catch (err) {
      return res.status(400).json({ success: false, error: err.message || 'Invalid participant details' });
    }
    const incomingId = idNumber !== undefined ? idNumber : profile.idNumber;
    delete profile.idNumber;

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

    if (incomingId !== undefined) {
      const rawId = String(incomingId || '').trim();
      if (!rawId) {
        return res.status(400).json({ success: false, error: 'ID number cannot be empty' });
      }
      if (rawId !== reg.idNumber) {
        const exists = await EventRegistration.findOne({
          eventId: event._id,
          idNumber: rawId,
          _id: { $ne: reg._id },
        }).select('_id').lean();
        if (exists) {
          return res.status(400).json({ success: false, error: `ID number "${rawId}" is already in use` });
        }
        reg.idNumber = rawId;
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
      return res.status(400).json({ success: false, error: 'ID number or mobile number already in use' });
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
        }
        const photo = String(row.photo || '').trim();
        if (/^https?:\/\//i.test(photo)) profile.photoUrl = photo;
        if (row.idNumber) {
          profile.idNumber = profile.idNumber || row.idNumber;
        }
        const registration = await createParticipantRegistration(event, {
          packageId: chosenPackage.id,
          idNumber: profile.idNumber,
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

/** Claims an event package inclusion (e.g. Lunch, Kit, Dinner) for a participant by QR payload or ID number */
const claimInclusion = async (req, res) => {
  try {
    const { inclusionName, packageId, qrData, idNumber } = req.body;
    if (!inclusionName) {
      return res.status(400).json({ success: false, error: 'Inclusion name is required' });
    }

    const codeToFind = (idNumber || qrData || '').trim();
    if (!codeToFind) {
      return res.status(400).json({ success: false, error: 'ID number or QR data is required' });
    }

    const upper = codeToFind.toUpperCase();
    const withPrefix = upper.startsWith('ID') ? upper : `ID${upper}`;
    const withoutPrefix = upper.startsWith('ID') ? upper.substring(2) : upper;

    // Lookup registration by idNumber or qrCode
    const reg = await EventRegistration.findOne({
      $or: [
        { idNumber: codeToFind },
        { idNumber: upper },
        { idNumber: withPrefix },
        { idNumber: withoutPrefix },
        { qrCode: codeToFind },
      ],
      status: { $ne: 'cancelled' },
    });

    if (!reg) {
      return res.status(404).json({ success: false, error: 'Participant registration not found' });
    }

    const event = await ManagedEvent.findById(reg.eventId);
    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' });
    }

    // Check if already claimed today
    const istDay = (d) => new Date(d).toLocaleDateString('en-CA', { timeZone: 'Asia/Kolkata' });
    const today = istDay(new Date());

    const claimedList = reg.claimedInclusions || [];
    const alreadyClaimed = claimedList.some(
      (c) =>
        String(c.inclusionName).trim().toLowerCase() === String(inclusionName).trim().toLowerCase() &&
        istDay(c.claimedAt || new Date()) === today
    );

    if (alreadyClaimed) {
      return res.json({
        success: false,
        alreadyClaimed: true,
        error: 'This entitlement has already been redeemed for today.',
        registration: registrationDto(reg, event),
      });
    }

    // Register the claim
    reg.claimedInclusions.push({
      inclusionName: String(inclusionName).trim(),
      claimedAt: new Date(),
      claimedBy: req.user?._id || null,
    });
    await reg.save();

    res.json({
      success: true,
      message: 'Benefit claim registered successfully',
      registration: registrationDto(reg, event),
    });
  } catch (error) {
    console.error('claimInclusion error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// POST /api/managed-events/:id/registrations/:regId/claims/:claimId/reclaim —
// management re-registers this exact claim (e.g. after a mis-scan) by
// updating its own date/time and tagging it as reclaimed by admin — in place,
// not a new entry. Can be done any number of times.
const reclaimInclusion = async (req, res) => {
  try {
    const event = await ManagedEvent.findById(req.params.id);
    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' });
    }
    const reg = await EventRegistration.findOne({ _id: req.params.regId, eventId: event._id });
    if (!reg) {
      return res.status(404).json({ success: false, error: 'Registration not found' });
    }
    const claim = reg.claimedInclusions.id(req.params.claimId);
    if (!claim) {
      return res.status(404).json({ success: false, error: 'Claim not found' });
    }
    claim.claimedAt = new Date();
    claim.claimedBy = req.userId || null;
    claim.reclaimedByAdmin = true;
    await reg.save();
    res.json({ success: true, registration: registrationDto(reg, event) });
  } catch (error) {
    console.error('reclaimInclusion error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// GET /api/managed-events/my-registration — the logged-in participant's own ticket
const getMyRegistration = async (req, res) => {
  try {
    if (req.userType !== 'participant') {
      return res.status(403).json({ success: false, error: 'Only participant accounts can use this route' });
    }
    const reg = await EventRegistration.findById(req.userId);
    if (!reg) {
      return res.status(404).json({ success: false, error: 'Registration not found' });
    }
    const event = await ManagedEvent.findById(reg.eventId);
    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' });
    }
    const pkg = (event.packages || []).find((p) => p.id === reg.packageId);
    res.json({
      success: true,
      registration: registrationDto(reg, event),
      availableInclusions: pkg ? normalizeInclusions(pkg.inclusions) : [],
    });
  } catch (error) {
    console.error('getMyRegistration error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

module.exports = {
  normalizeInclusions,
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
  claimInclusion,
  reclaimInclusion,
  getMyRegistration,
};
