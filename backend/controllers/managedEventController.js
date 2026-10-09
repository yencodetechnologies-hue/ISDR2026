const crypto = require('crypto');
const mongoose = require('mongoose');
const ManagedEvent = require('../models/ManagedEvent');
const EventRegistration = require('../models/EventRegistration');
const Apartment = require('../models/Apartment');
const { uploadToCloudinary } = require('../middleware/upload');
const { resolveRegistrationForCode } = require('../utils/passCodeResolver');

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

/**
 * True when another participant (in any event) already has this ID number.
 * "ID1001", "id1001" and "1001" count as the same number, because scanning
 * looks a participant up by any of these forms across all events.
 */
async function idNumberTaken(rawId, excludeRegId) {
  const upper = String(rawId || '').trim().toUpperCase();
  if (!upper) return false;
  const core = upper.startsWith('ID') ? upper.substring(2) : upper;
  const escape = (v) => v.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const filter = {
    idNumber: { $in: [...new Set([upper, core, `ID${core}`])].map((v) => new RegExp(`^${escape(v)}$`, 'i')) },
  };
  if (excludeRegId) filter._id = { $ne: excludeRegId };
  return Boolean(await EventRegistration.exists(filter));
}

/**
 * A new ID number: the first two letters of the package name plus the lowest
 * free number in that prefix's own sequence, four digits from 0001 — e.g. the
 * first "UG students" participant gets UG0001, the next UG0002, while
 * "PG students" counts PG0001, PG0002, … ("ID" when there is no package).
 * Numbers already used with that prefix (in any event) are skipped.
 */
async function generateNextIdNumber(packageName = '') {
  const letters = String(packageName || '').replace(/[^A-Za-z]/g, '').toUpperCase();
  const prefix = letters.length >= 2 ? letters.slice(0, 2) : 'ID';
  const pattern = new RegExp(`^${prefix}(\\d+)$`, 'i');
  const registrations = await EventRegistration.find({ idNumber: pattern }).select('idNumber').lean();
  const used = new Set(
    registrations.map((r) => Number((String(r.idNumber || '').match(pattern) || [])[1]))
  );
  // 4 digits, zero-padded (grows to 5+ digits only after 9999).
  for (let n = 1; ; n += 1) {
    if (used.has(n)) continue;
    const candidate = `${prefix}${String(n).padStart(4, '0')}`;
    if (!(await idNumberTaken(candidate))) return candidate;
  }
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

/** Welcome Kit is once for the whole event. "Welcome Kit", "Welcomekit", and "Welcome-Kit" all match. */
function isWelcomeKit(name) {
  return String(name || '').toLowerCase().replace(/[^a-z0-9]/g, '').includes('welcomekit');
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
    const entryExitDates = Array.isArray(p?.entryExitDates)
      ? p.entryExitDates.map(String).filter(Boolean)
      : [];
    return { id, name, rate, paymentMode, entryExitDates, inclusions };
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
          entryExitDates: Array.isArray(p.entryExitDates) ? p.entryExitDates : [],
          inclusions: normalizeInclusions(p.inclusions),
        }))
      : [],
    isOpen:
      event.isActive &&
      event.status === 'published' &&
      (!event.eventEndDate || new Date(event.eventEndDate) > new Date()),
  };
}

function capsName(value) {
  return String(value || '').trim().toUpperCase();
}

function registrationDto(reg, event, options = {}) {
  const slim = !!options.slim;
  const firstName = capsName(reg.firstName);
  const middleName = capsName(reg.middleName);
  const lastName = capsName(reg.lastName);
  const composed = [firstName, middleName, lastName].filter(Boolean).join(' ');
  const dto = {
    id: reg._id.toString(),
    eventId: reg.eventId?.toString?.() || String(reg.eventId),
    name: composed || capsName(reg.name),
    mobileNumber: reg.mobileNumber,
    email: reg.email,
    institution: reg.institution || '',
    title: reg.title || '',
    firstName,
    middleName,
    lastName,
    gender: reg.gender || '',
    participantType: /^spot register$/i.test(reg.packageName || '')
      ? ''
      : reg.participantType || 'Delegate',
    participantTypeColor:
      reg.participantTypeColor ||
      (/^spot register$/i.test(reg.packageName || '') ? '' : DEFAULT_PARTICIPANT_TYPE_COLOR),
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
  // A page of the admin list does not need form answers, the pass code, or scan history.
  if (slim) return dto;
  dto.answers = Array.isArray(reg.answers)
    ? reg.answers.map((a) => ({
        questionId: a.questionId,
        label: a.label,
        type: a.type,
        value: a.value,
      }))
    : [];
  dto.otp = reg.otp;
  dto.qrCode = reg.qrCode;
  // Entry/exit scans, one row per event day (India time) — used by the admin Analytics tab.
  dto.attendance = Array.isArray(reg.attendance)
    ? reg.attendance.map((a) => ({ day: a.day, entryAt: a.entryAt || null, exitAt: a.exitAt || null }))
    : [];
  return dto;
}

const PARTICIPANT_PAGE_SIZES = [15, 20, 40, 50];
const LIST_SEARCH_FIELDS = [
  'name',
  'firstName',
  'middleName',
  'lastName',
  'mobileNumber',
  'email',
  'institution',
  'designation',
  'idNumber',
  'packageName',
  'participantType',
];

function escapeRegex(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function istDayBound(day, end) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(day)) return null;
  return new Date(`${day}T${end ? '23:59:59.999' : '00:00:00.000'}+05:30`);
}

/** Filters shared by the paged list and the export download. */
function registrationListFilter(eventId, query) {
  const filter = { eventId };
  const and = [];
  const q = String(query.search || '').trim();
  if (q) {
    const rx = new RegExp(escapeRegex(q), 'i');
    and.push({ $or: LIST_SEARCH_FIELDS.map((field) => ({ [field]: rx })) });
  }

  const pkg = String(query.package || '').trim();
  if (pkg) filter.packageName = pkg;

  const type = String(query.type || '').trim();
  if (type) {
    and.push({ packageName: { $not: /^spot register$/i } });
    if (type === 'Delegate') {
      and.push({
        $or: [{ participantType: 'Delegate' }, { participantType: '' }, { participantType: null }],
      });
    } else {
      filter.participantType = type;
    }
  }

  const status = String(query.status || '').trim();
  if (status) filter.status = status;

  const claim = String(query.claim || '').trim();
  if (claim === 'claimed') and.push({ 'claimedInclusions.0': { $exists: true } });
  if (claim === 'none') {
    and.push({
      $or: [{ claimedInclusions: { $exists: false } }, { claimedInclusions: { $size: 0 } }],
    });
  }

  const prefix = String(query.idPrefix || '').trim().toUpperCase();
  if (/^[A-Z]{2}$/.test(prefix)) {
    filter.idNumber = new RegExp(`^${prefix}`, 'i');
    const from = parseInt(String(query.idFrom || '').replace(/\D/g, ''), 10);
    const to = parseInt(String(query.idTo || '').replace(/\D/g, ''), 10);
    if (!Number.isNaN(from) || !Number.isNaN(to)) {
      const checks = [{ $ne: ['$$n', null] }];
      if (!Number.isNaN(from)) checks.push({ $gte: ['$$n', from] });
      if (!Number.isNaN(to)) checks.push({ $lte: ['$$n', to] });
      and.push({
        $expr: {
          $let: {
            vars: {
              n: {
                $convert: {
                  input: { $substrCP: [{ $toUpper: { $ifNull: ['$idNumber', ''] } }, 2, 12] },
                  to: 'int',
                  onError: null,
                  onNull: null,
                },
              },
            },
            in: { $and: checks },
          },
        },
      });
    }
  }

  const createdFrom = istDayBound(String(query.createdFrom || '').trim(), false);
  const createdTo = istDayBound(String(query.createdTo || '').trim(), true);
  if (createdFrom || createdTo) {
    filter.createdAt = {};
    if (createdFrom) filter.createdAt.$gte = createdFrom;
    if (createdTo) filter.createdAt.$lte = createdTo;
  }

  if (and.length) filter.$and = and;
  return filter;
}

async function registrationListFacets(eventId) {
  const [types, statuses, prefixes, packageNames, packageGroups, totalAll] = await Promise.all([
    EventRegistration.aggregate([
      { $match: { eventId, packageName: { $not: /^spot register$/i } } },
      {
        $group: {
          _id: {
            $cond: [{ $in: [{ $ifNull: ['$participantType', ''] }, ['', null]] }, 'Delegate', '$participantType'],
          },
        },
      },
      { $sort: { _id: 1 } },
    ]),
    EventRegistration.distinct('status', { eventId }),
    EventRegistration.aggregate([
      { $match: { eventId } },
      {
        $project: {
          prefix: { $toUpper: { $substrCP: [{ $ifNull: ['$idNumber', ''] }, 0, 2] } },
        },
      },
      { $match: { prefix: { $regex: '^[A-Z]{2}$' } } },
      { $group: { _id: '$prefix' } },
      { $sort: { _id: 1 } },
    ]),
    EventRegistration.distinct('packageName', { eventId }),
    EventRegistration.aggregate([
      { $match: { eventId } },
      {
        $group: {
          _id: {
            packageId: { $ifNull: ['$packageId', ''] },
            packageName: { $ifNull: ['$packageName', ''] },
          },
          n: { $sum: 1 },
        },
      },
    ]),
    EventRegistration.countDocuments({ eventId }),
  ]);

  return {
    types: types.map((row) => row._id).filter(Boolean),
    statuses: statuses.filter(Boolean).sort(),
    idPrefixes: prefixes.map((row) => row._id),
    packages: packageNames.map((name) => String(name || '').trim()).filter(Boolean).sort((a, b) => a.localeCompare(b)),
    packageCounts: packageGroups.map((row) => ({
      packageId: row._id.packageId || '',
      packageName: row._id.packageName || '',
      n: row.n,
    })),
    totalAll,
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
// No limit: every registration (staff scan, analytics, the Flutter app).
// limit=15|20|40|50: one page for the admin list. export=1: the filtered set for download.
// regId: one full registration (the QR badge, which the page itself omits).
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

    const regId = String(req.query.regId || '').trim();
    if (regId) {
      if (!mongoose.Types.ObjectId.isValid(regId)) {
        return res.status(400).json({ success: false, error: 'Invalid registration' });
      }
      const one = await EventRegistration.findOne({ _id: regId, eventId: event._id })
        .select('-fcmTokens -favoriteSchedules')
        .lean();
      if (!one) return res.status(404).json({ success: false, error: 'Registration not found' });
      return res.json({ success: true, registration: registrationDto(one) });
    }

    const wantsPage = req.query.limit !== undefined && String(req.query.limit) !== '';
    const wantsExport = String(req.query.export || '') === '1';
    if (!wantsPage || wantsExport) {
      const filter = wantsExport ? registrationListFilter(event._id, req.query) : { eventId: event._id };
      const regs = await EventRegistration.find(filter)
        .select('-fcmTokens -favoriteSchedules')
        .sort({ createdAt: -1 })
        .lean();
      return res.json({
        success: true,
        registrations: regs.map((r) => registrationDto(r)),
        count: regs.length,
        total: regs.length,
      });
    }

    const requested = Number(req.query.limit);
    const limit = PARTICIPANT_PAGE_SIZES.includes(requested) ? requested : 15;
    const filter = registrationListFilter(event._id, req.query);
    const [total, facets] = await Promise.all([
      EventRegistration.countDocuments(filter),
      registrationListFacets(event._id),
    ]);
    const pages = Math.max(1, Math.ceil(total / limit));
    const page = Math.min(Math.max(parseInt(req.query.page, 10) || 1, 1), pages);
    const regs = await EventRegistration.find(filter)
      .select('-fcmTokens -favoriteSchedules -attendance -answers -otp -qrCode')
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(limit)
      .lean();

    res.json({
      success: true,
      registrations: regs.map((r) => registrationDto(r, undefined, { slim: true })),
      count: regs.length,
      total,
      totalAll: facets.totalAll,
      page,
      limit,
      pages,
      packages: facets.packages,
      types: facets.types,
      statuses: facets.statuses,
      idPrefixes: facets.idPrefixes,
      packageCounts: facets.packageCounts,
    });
  } catch (error) {
    console.error('listRegistrations error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

const PARTICIPANT_TITLES = ['Dr', 'Mr', 'Mrs', 'Ms', 'Prof'];
const PARTICIPANT_GENDERS = ['male', 'female', 'other'];
const FOOD_PREFERENCES = ['veg', 'non-veg'];
const PARTICIPANT_PAYMENT_MODES = ['cash', 'card', 'upi'];
const DEFAULT_PARTICIPANT_TYPE_COLOR = '#167E5D';

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
    out.firstName = str('firstName').toUpperCase();
  }
  if (has('middleName')) out.middleName = str('middleName').toUpperCase();
  if (has('lastName') || strict) {
    out.lastName = str('lastName').toUpperCase();
  }
  oneOf('gender', 'Gender', PARTICIPANT_GENDERS, (v) => v.toLowerCase());
  if (has('participantType') || strict) {
    const t = str('participantType');
    if (strict && !t) throw new Error('Participant type is required');
    if (t.length > 60) throw new Error('Participant type is too long');
    out.participantType = t;
  }
  if (has('participantTypeColor')) {
    const c = str('participantTypeColor').replace(/^#/, '').toUpperCase();
    if (c && !/^[0-9A-F]{6}$/.test(c)) throw new Error('Enter a valid hex colour, e.g. #167E5D');
    out.participantTypeColor = c ? `#${c}` : '';
  }
  if (has('designation') || strict) {
    out.designation = str('designation');
  }
  if (has('institution') || strict) {
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
  return [p.firstName, p.middleName, p.lastName]
    .map((part) => capsName(part))
    .filter(Boolean)
    .join(' ');
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
  const trimmedName = capsName(profile.firstName ? composeParticipantName(profile) : name || '');
  if (!trimmedName && source !== 'spot') {
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
    if (await idNumberTaken(rawIdNumber)) {
      throw new Error(`ID number "${rawIdNumber}" is already in use by another participant`);
    }
    finalIdNumber = rawIdNumber;
  } else {
    finalIdNumber = await generateNextIdNumber(packageName);
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
    participantTypeColor: profile.participantTypeColor || '',
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
        finalIdNumber = await generateNextIdNumber(packageName);
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
      const profile = parseParticipantProfile(req.body, { strict: false });
      const chosenPackage = (event.packages || []).find((p) => p.id === String(packageId || '').trim());
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
      reg.firstName = capsName(reg.firstName);
      reg.middleName = capsName(reg.middleName);
      reg.lastName = capsName(reg.lastName);
      const composed = composeParticipantName(reg);
      if (reg.name !== composed) {
        reg.name = composed;
        reg.qrCode = buildQrPayload(reg, event);
      }
    }
    if (name != null && profile.firstName === undefined) {
      const trimmedName = String(name).trim().toUpperCase();
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
        if (await idNumberTaken(rawId, reg._id)) {
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

    // Lookup registration by idNumber or qrCode, with support for Admin & Speaker passes
    const reg = await resolveRegistrationForCode(codeToFind, resolveApartmentId(req));

    if (!reg) {
      return res.status(404).json({ success: false, error: 'Participant registration not found' });
    }

    const event = await ManagedEvent.findById(reg.eventId);
    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' });
    }

    const istDay = (d) => new Date(d).toLocaleDateString('en-CA', { timeZone: 'Asia/Kolkata' });
    const today = istDay(new Date());
    const deny = (error) => res.json({ success: false, error, registration: registrationDto(reg, event) });

    if (event.status === 'cancelled') {
      return deny('This event has been cancelled');
    }

    // The inclusion must be in the participant's package and offered today.
    // Admin / speaker / event staff all-access passes can claim everything.
    const allAccess =
      ['Admin', 'Speaker', 'Event Staff'].includes(reg.participantType) || reg.packageId === 'vip-all-access';
    if (!allAccess) {
      const key = (s) => String(s || '').trim().toLowerCase();
      const pkg = (event.packages || []).find(
        (p) => (reg.packageId && p.id === reg.packageId) || (reg.packageName && p.name === reg.packageName)
      );
      const pkgLabel = reg.packageName ? `the ${reg.packageName} package` : 'this participant\'s package';
      const inclusion = pkg && normalizeInclusions(pkg.inclusions).find((i) => key(i.name) === key(inclusionName));
      if (!inclusion) {
        return deny(`"${String(inclusionName).trim()}" is not included in ${pkgLabel}`);
      }
      // Only the days ticked on the event details page. Empty = not offered.
      const days = Array.isArray(inclusion.dates) ? inclusion.dates : [];
      if (!days.includes(today)) {
        const listed = [...days].sort().join(', ');
        return deny(
          listed
            ? `"${inclusion.name}" is not available today. Available on: ${listed}`
            : `"${inclusion.name}" is not available today. No days selected.`
        );
      }
    }

    const claimedList = reg.claimedInclusions || [];
    const sameInclusion = (c) =>
      String(c.inclusionName).trim().toLowerCase() === String(inclusionName).trim().toLowerCase();
    // Welcome Kit is once for the event. Any earlier kit claim blocks another, even on a later day.
    // Every other inclusion stays once per calendar day (India time).
    const welcomeKit = isWelcomeKit(inclusionName);
    const alreadyClaimed = welcomeKit
      ? claimedList.some((c) => isWelcomeKit(c.inclusionName))
      : claimedList.some((c) => sameInclusion(c) && istDay(c.claimedAt || new Date()) === today);

    if (alreadyClaimed) {
      return res.json({
        success: false,
        alreadyClaimed: true,
        error: welcomeKit
          ? 'Welcome Kit has already been claimed.'
          : 'This entitlement has already been redeemed for today.',
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

// India has no DST, so a fixed +5:30 offset matches Asia/Kolkata calendar dates.
const SCAN_IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;
function scanIstDay(d) {
  const t = d instanceof Date ? d.getTime() : new Date(d).getTime();
  if (!Number.isFinite(t)) return '';
  return new Date(t + SCAN_IST_OFFSET_MS).toISOString().slice(0, 10);
}

function scanEventDays(event) {
  if (!event?.eventDate) return [];
  const out = [];
  let d = new Date(`${scanIstDay(event.eventDate)}T00:00:00Z`);
  const end = new Date(`${scanIstDay(event.eventEndDate || event.eventDate)}T00:00:00Z`);
  while (d <= end && out.length < 60) {
    out.push(d.toISOString().slice(0, 10));
    d = new Date(d.getTime() + 86400000);
  }
  return out;
}

function scanPackageOf(event, reg) {
  const packages = event.packages || [];
  return (
    packages.find((p) => reg.packageId && p.id === reg.packageId) ||
    packages.find(
      (p) => reg.packageName && String(p.name).toLowerCase() === String(reg.packageName).toLowerCase()
    ) ||
    null
  );
}

function scanReportName(reg) {
  const composed = [capsName(reg.firstName), capsName(reg.middleName), capsName(reg.lastName)]
    .filter(Boolean)
    .join(' ');
  const base = composed || capsName(reg.name);
  const title = String(reg.title || '').trim();
  return [title, base].filter(Boolean).join(' ');
}

function scanReportType(reg) {
  if (/^spot register$/i.test(reg.packageName || '')) return '';
  return reg.participantType || 'Delegate';
}

function scanAllAccess(reg) {
  return ['Admin', 'Speaker', 'Event Staff'].includes(reg.participantType) || reg.packageId === 'vip-all-access';
}

// GET /api/managed-events/:id/scan-report
// Day-wise entry, exit, and inclusion facts for the admin report. No pass codes or form answers.
const scanReport = async (req, res) => {
  try {
    const apartmentId = resolveApartmentId(req);
    const event = await ManagedEvent.findById(req.params.id)
      .select('apartmentId title eventDate eventEndDate packages')
      .lean();
    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' });
    }
    if (apartmentId && String(event.apartmentId) !== apartmentId) {
      return res.status(403).json({ success: false, error: 'Not authorized for this event' });
    }

    const days = scanEventDays(event);
    const inclusions = [];
    const seenInc = new Set();
    (event.packages || []).forEach((pk) => {
      normalizeInclusions(pk.inclusions).forEach((inc) => {
        const key = inc.name.toLowerCase();
        if (seenInc.has(key)) return;
        seenInc.add(key);
        inclusions.push(inc.name);
      });
    });

    const regs = await EventRegistration.find({ eventId: event._id, status: { $ne: 'cancelled' } })
      .select('name title firstName middleName lastName participantType packageId packageName idNumber attendance claimedInclusions')
      .lean();

    const rows = regs.map((reg) => {
      const pkg = scanPackageOf(event, reg);
      const allowed =
        pkg && Array.isArray(pkg.entryExitDates) && pkg.entryExitDates.length
          ? pkg.entryExitDates.map(String)
          : days;
      const access = scanAllAccess(reg);
      const attByDay = new Map((reg.attendance || []).map((a) => [a.day, a]));
      const pkgIncs = new Map(
        (pkg ? normalizeInclusions(pkg.inclusions) : []).map((inc) => [inc.name.toLowerCase(), inc])
      );
      const claimAt = new Map();
      (reg.claimedInclusions || []).forEach((c) => {
        const key = `${String(c.inclusionName || '').trim().toLowerCase()}|${scanIstDay(c.claimedAt)}`;
        const prev = claimAt.get(key);
        const at = c.claimedAt ? new Date(c.claimedAt).toISOString() : null;
        if (!prev || (at && at < prev)) claimAt.set(key, at);
      });
      return {
        id: String(reg._id),
        idNumber: reg.idNumber || '',
        name: scanReportName(reg),
        packageName: reg.packageName || (pkg ? pkg.name : ''),
        participantType: scanReportType(reg),
        days: days.map((day) => {
          const att = attByDay.get(day) || {};
          const entryEligible = access || allowed.includes(day);
          return {
            day,
            entryEligible,
            entryAt: entryEligible && att.entryAt ? new Date(att.entryAt).toISOString() : null,
            exitEligible: entryEligible,
            exitAt: entryEligible && att.exitAt ? new Date(att.exitAt).toISOString() : null,
            inclusions: inclusions.map((name) => {
              const inc = pkgIncs.get(name.toLowerCase());
              const eligible = !!(inc && Array.isArray(inc.dates) && inc.dates.map(String).includes(day));
              return {
                name,
                eligible,
                claimedAt: eligible ? claimAt.get(`${name.toLowerCase()}|${day}`) || null : null,
              };
            }),
          };
        }),
      };
    });

    rows.sort((a, b) => String(a.idNumber).localeCompare(String(b.idNumber)) || String(a.name).localeCompare(String(b.name)));

    res.json({ success: true, report: { title: event.title || 'Event', days, inclusions, rows } });
  } catch (error) {
    console.error('scanReport error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

module.exports = {
  normalizeInclusions,
  createParticipantRegistration,
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
  scanReport,
};
