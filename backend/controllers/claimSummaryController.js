const mongoose = require('mongoose');
const ManagedEvent = require('../models/ManagedEvent');
const EventRegistration = require('../models/EventRegistration');
const EventClaimAttempt = require('../models/EventClaimAttempt');
const { normalizeInclusions } = require('./managedEventController');

/** Every request is scoped to the logged-in management property (from the token). */
function resolveApartmentId(req) {
  return req.apartmentId ? String(req.apartmentId) : null;
}

const istDay = (d) => new Date(d).toLocaleDateString('en-CA', { timeZone: 'Asia/Kolkata' });

function dayRange(startStr, endStr) {
  const out = [];
  let d = new Date(`${startStr}T00:00:00Z`);
  const end = new Date(`${endStr}T00:00:00Z`);
  let guard = 0;
  while (d <= end && guard < 400) {
    out.push(d.toISOString().slice(0, 10));
    d = new Date(d.getTime() + 86400000);
    guard += 1;
  }
  return out;
}

// GET /api/managed-events/summary[?eventId=][&date=YYYY-MM-DD|all]
// Scan overview for management, per inclusion: scanned / not scanned / rejected, plus who rejected.
// Counts are for one event day (default: today, India time) or for every day with date=all.
const claimSummary = async (req, res) => {
  try {
    const apartmentId = resolveApartmentId(req);
    if (!apartmentId) {
      return res.status(400).json({ success: false, error: 'apartmentId is required' });
    }
    const eventFilter = { apartmentId: new mongoose.Types.ObjectId(apartmentId) };
    const eventId = String(req.query.eventId || '').trim();
    if (eventId) {
      if (!mongoose.Types.ObjectId.isValid(eventId)) {
        return res.status(400).json({ success: false, error: 'Invalid event id' });
      }
      eventFilter._id = new mongoose.Types.ObjectId(eventId);
    }
    const events = await ManagedEvent.find(eventFilter).select('title packages eventDate eventEndDate').lean();
    const ids = events.map((e) => e._id);
    const titles = new Map(events.map((e) => [String(e._id), e.title]));

    const eventDays = new Map(
      events.map((e) => [
        String(e._id),
        e.eventDate ? dayRange(istDay(e.eventDate), istDay(e.eventEndDate || e.eventDate)) : [],
      ])
    );
    const allDays = [...new Set([...eventDays.values()].flat())].sort();
    const requested = String(req.query.date || '').trim();
    const today = istDay(new Date());
    const selected = requested === 'all' || requested === 'to-date' ? requested : /^\d{4}-\d{2}-\d{2}$/.test(requested) ? requested : today;
    // 'to-date' covers every event day up to and including today (days still to come are not "not scanned" yet).
    const inRange = (day) => (selected === 'all' ? true : selected === 'to-date' ? day <= today : day === selected);

    const regs = await EventRegistration.find({ eventId: { $in: ids }, status: { $ne: 'cancelled' } })
      .select('eventId packageId packageName claimedInclusions')
      .lean();

    // One row per package + inclusion, so the same inclusion name in two packages is counted separately.
    const rows = new Map();
    const row = (packageName, name) => {
      const key = `${String(packageName).toLowerCase()}|${name.toLowerCase()}`;
      if (!rows.has(key)) rows.set(key, { packageName, name, eligible: 0, scanned: 0, notScanned: 0, rejected: 0 });
      return rows.get(key);
    };

    const packageOf = (event, reg) =>
      (event.packages || []).find((pk) => pk.id === reg.packageId) ||
      (reg.packageName
        ? (event.packages || []).find((pk) => String(pk.name).toLowerCase() === String(reg.packageName).toLowerCase())
        : null);

    const eventById = new Map(events.map((e) => [String(e._id), e]));
    // Every inclusion gets a row (zero counts) even when none of its days fall in the selected range.
    events.forEach((ev) =>
      (ev.packages || []).forEach((pk) => normalizeInclusions(pk.inclusions).forEach((inc) => row(pk.name, inc.name)))
    );
    regs.forEach((reg) => {
      const event = eventById.get(String(reg.eventId));
      const pkg = event && packageOf(event, reg);
      if (!pkg) return;
      normalizeInclusions(pkg.inclusions).forEach((inc) => {
        const scheduled = Array.isArray(inc.dates) && inc.dates.length > 0 ? inc.dates : eventDays.get(String(event._id)) || [];
        scheduled.filter(inRange).forEach((day) => {
          const r = row(pkg.name, inc.name);
          r.eligible += 1;
          const done = (reg.claimedInclusions || []).some(
            (c) => String(c.inclusionName).toLowerCase() === inc.name.toLowerCase() && istDay(c.claimedAt) === day
          );
          if (done) r.scanned += 1;
        });
      });
    });

    // Participants scanned (at least one inclusion claimed) on the selected day, or ever for all days.
    const scannedParticipants = regs.filter((r) =>
      (r.claimedInclusions || []).some((c) => inRange(istDay(c.claimedAt)))
    ).length;

    const attempts = (await EventClaimAttempt.find({ eventId: { $in: ids } }).sort({ createdAt: -1 }).lean()).filter((a) =>
      inRange(istDay(a.createdAt))
    );
    const regById = new Map(regs.map((r) => [String(r._id), r]));
    const attemptPackage = (a) => {
      const reg = regById.get(String(a.registrationId));
      const event = eventById.get(String(a.eventId));
      const pkg = reg && event ? packageOf(event, reg) : null;
      return pkg ? pkg.name : '';
    };
    attempts.forEach((a) => {
      if (a.inclusionName) row(attemptPackage(a), a.inclusionName).rejected += 1;
    });
    rows.forEach((r) => {
      r.notScanned = Math.max(r.eligible - r.scanned, 0);
    });

    const byStaff = new Map();
    attempts.forEach((a) => {
      const key = a.rejectedByName || 'Unknown';
      byStaff.set(key, (byStaff.get(key) || 0) + 1);
    });

    res.json({
      success: true,
      summary: {
        date: selected,
        today,
        days: allDays,
        registered: regs.length,
        scanned: scannedParticipants,
        notScanned: regs.length - scannedParticipants,
        inclusions: [...rows.values()].sort(
          (x, y) => x.packageName.localeCompare(y.packageName) || x.name.localeCompare(y.name)
        ),
        rejected: attempts.length,
        rejectedByStaff: [...byStaff.entries()]
          .map(([name, count]) => ({ name, count }))
          .sort((x, y) => y.count - x.count),
        rejections: attempts.slice(0, 200).map((a) => ({
          id: String(a._id),
          eventTitle: titles.get(String(a.eventId)) || '',
          participantName: a.participantName,
          idNumber: a.idNumber,
          packageName: attemptPackage(a),
          inclusionName: a.inclusionName,
          outcome: a.outcome,
          reason: a.reason,
          rejectedBy: a.rejectedByName || 'Unknown',
          at: a.createdAt,
        })),
      },
    });
  } catch (error) {
    console.error('claimSummary error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

module.exports = { claimSummary };
