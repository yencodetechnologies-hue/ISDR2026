const EventRegistration = require('../models/EventRegistration');

/**
 * Schedules can be limited to event packages (`packageIds`). A participant sees
 * a schedule when it has no packages (older schedules — for everyone) or when
 * it lists their own package. Speakers, staff and management see everything.
 */

/** The logged-in participant's package id; null for any other login. */
async function participantPackageId(req) {
  if (req.userType !== 'participant') return null;
  const reg = await EventRegistration.findById(req.userId).select('packageId');
  return reg ? String(reg.packageId || '') : '';
}

/**
 * Mongo filter for the schedules a participant in [packageId] may see, or {}
 * when [packageId] is null (not a participant). Older schedule documents have
 * no `packageIds` field at all, so "missing" counts as "for everyone" too.
 */
function visibleScheduleFilter(packageId) {
  if (packageId === null) return {};
  const forEveryone = [{ packageIds: { $exists: false } }, { packageIds: { $size: 0 } }];
  return { $or: packageId ? [...forEveryone, { packageIds: packageId }] : forEveryone };
}

/** Same rule for one loaded schedule. */
function isScheduleVisible(schedule, packageId) {
  if (packageId === null) return true;
  const ids = schedule.packageIds || [];
  return ids.length === 0 || (!!packageId && ids.includes(packageId));
}

module.exports = { participantPackageId, visibleScheduleFilter, isScheduleVisible };
