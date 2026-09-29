const Apartment = require('../models/Apartment');
const ManagementUser = require('../models/ManagementUser');
const Speaker = require('../models/Speaker');
const EventStaff = require('../models/EventStaff');

/**
 * QR pass numbers for the non-participant logins, like the participants' ID numbers:
 * a role prefix and a 4-digit count from 0001 — ADM0001 (admins: the property login and
 * its Admin IDs), SPK0001 (speakers), STF0001 (event staff).
 */
const GROUPS = {
  ADM: () => [Apartment, ManagementUser],
  SPK: () => [Speaker],
  STF: () => [EventStaff],
};

function prefixFor(Model) {
  if (Model === Apartment || Model === ManagementUser) return 'ADM';
  if (Model === Speaker) return 'SPK';
  if (Model === EventStaff) return 'STF';
  return null;
}

/**
 * Numbers every account of the group that has no pass number yet, oldest first,
 * using the lowest free numbers (so existing accounts are numbered in the order
 * they were created, and new accounts get the next one).
 */
async function assignMissing(prefix) {
  const pattern = new RegExp(`^${prefix}(\\d+)$`);
  const used = new Set();
  const missing = [];
  for (const Model of GROUPS[prefix]()) {
    const docs = await Model.find({}).select('passNumber createdAt').lean();
    for (const d of docs) {
      const m = String(d.passNumber || '').match(pattern);
      if (m) used.add(Number(m[1]));
      else missing.push({ Model, doc: d });
    }
  }
  const time = (d) => (d.createdAt ? new Date(d.createdAt).getTime() : d._id.getTimestamp().getTime());
  missing.sort((a, b) => time(a.doc) - time(b.doc) || String(a.doc._id).localeCompare(String(b.doc._id)));

  let n = 1;
  for (const { Model, doc } of missing) {
    while (used.has(n)) n += 1;
    used.add(n);
    // Only fill an empty pass number, never overwrite one set meanwhile.
    await Model.updateOne(
      { _id: doc._id, $or: [{ passNumber: { $exists: false } }, { passNumber: '' }, { passNumber: null }] },
      { $set: { passNumber: `${prefix}${String(n).padStart(4, '0')}` } }
    );
  }
}

/** The account's pass number (assigning numbers first if it has none); '' for other models. */
async function ensurePassNumber(doc) {
  if (!doc) return '';
  if (doc.passNumber) return doc.passNumber;
  const Model = doc.constructor;
  const prefix = prefixFor(Model);
  if (!prefix) return '';
  await assignMissing(prefix);
  const fresh = await Model.findById(doc._id).select('passNumber').lean();
  doc.passNumber = (fresh && fresh.passNumber) || '';
  return doc.passNumber;
}

module.exports = { ensurePassNumber, assignMissing };
