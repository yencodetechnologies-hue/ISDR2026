const mongoose = require('mongoose');
const EventRegistration = require('../models/EventRegistration');
const ManagedEvent = require('../models/ManagedEvent');
const Apartment = require('../models/Apartment');
const ManagementUser = require('../models/ManagementUser');
const Speaker = require('../models/Speaker');
const EventStaff = require('../models/EventStaff');

/**
 * Resolves an EventRegistration document for any scanned QR data or ID number.
 * Supports:
 *  1. Regular delegate ticket payloads and ID numbers.
 *  2. Admin pass numbers: ADM0001 (and the older ADM-XXXXXX / ADMXXXXXX codes)
 *  3. Speaker pass numbers: SPK0001 (and SPK-XXXXXX / SPKXXXXXX)
 *  4. Event Staff pass numbers: STF0001 (and STF-XXXXXX / STFXXXXXX)
 *
 * If a pass code belongs to an Admin, Speaker, or Event Staff without an existing
 * registration record, an all-access registration is automatically provisioned
 * so that meal/inclusion claims and attendance entry/exit scans succeed immediately.
 */
async function resolveRegistrationForCode(rawCode, apartmentIdHint = null) {
  const code = String(rawCode || '').trim();
  if (!code) return null;

  const upper = code.toUpperCase();
  const withPrefix = upper.startsWith('ID') ? upper : `ID${upper}`;
  const withoutPrefix = upper.startsWith('ID') ? upper.substring(2) : upper;

  // 1. Direct search in EventRegistration (handles regular delegates and already-provisioned passes)
  let reg = await EventRegistration.findOne({
    $or: [
      { idNumber: code },
      { idNumber: upper },
      { idNumber: withPrefix },
      { idNumber: withoutPrefix },
      { qrCode: code },
      { qrCode: upper },
    ],
    status: { $ne: 'cancelled' },
  });

  if (reg) return reg;

  // 2. Role pass: saved pass number (ADM0001) or the older code from the account id
  //    (ADM-XXXXXX, or ADMXXXXXX without the dash).
  const numberMatch = upper.match(/^(ADM|SPK|STF)(\d{4,})$/);
  const match = upper.match(/^(ADM|SPK|STF)-?([0-9A-F]{6})$/i);
  let rolePrefix = numberMatch ? numberMatch[1] : match ? match[1].toUpperCase() : null;
  let tailHex = match ? match[2].toLowerCase() : null;
  let rawObjectId = null;

  // Saved pass numbers first (a 4-digit number can't be mistaken for a 6-char id tail).
  let byNumber = null;
  if (numberMatch) {
    const models =
      rolePrefix === 'ADM' ? [Apartment, ManagementUser] : rolePrefix === 'SPK' ? [Speaker] : [EventStaff];
    for (const Model of models) {
      const found = await Model.findOne({ passNumber: upper }).lean();
      if (found) {
        byNumber = { Model, user: found };
        break;
      }
    }
    if (!byNumber && !tailHex) return null;
  }

  if (!rolePrefix && mongoose.Types.ObjectId.isValid(code)) {
    rawObjectId = code;
  }

  if (!rolePrefix && !rawObjectId) {
    return null;
  }

  // 3. Resolve identity based on role and tail hex or raw ObjectId
  let user = null;
  let role = '';
  let roleTitle = '';
  let userApartmentId = apartmentIdHint;

  if (byNumber) {
    user = byNumber.user;
    if (byNumber.Model === Speaker) {
      role = 'Speaker';
      roleTitle = 'Faculty / Speaker';
      userApartmentId = user.apartmentId?.toString() || userApartmentId;
    } else if (byNumber.Model === Apartment) {
      role = 'Admin';
      roleTitle = 'Organizing Committee / Admin';
      userApartmentId = user._id.toString();
    } else if (byNumber.Model === ManagementUser) {
      role = 'Admin';
      roleTitle = user.roleTitle || 'Admin Member';
      userApartmentId = user.apartmentId?.toString();
    } else {
      role = 'Event Staff';
      roleTitle = user.roleTitle || 'Event Staff';
      userApartmentId = user.apartmentId?.toString();
    }
  }

  // Case A: Speaker
  if (!user && (rolePrefix === 'SPK' || (!rolePrefix && rawObjectId))) {
    if (rawObjectId) {
      user = await Speaker.findById(rawObjectId).lean();
    } else {
      const speakers = await Speaker.find({}).lean();
      user = speakers.find((s) => s._id.toString().toLowerCase().endsWith(tailHex));
    }
    if (user) {
      role = 'Speaker';
      roleTitle = 'Faculty / Speaker';
      userApartmentId = user.apartmentId?.toString() || userApartmentId;
    }
  }

  // Case B: Admin / Management
  if (!user && (rolePrefix === 'ADM' || (!rolePrefix && rawObjectId))) {
    if (rawObjectId) {
      user = await Apartment.findById(rawObjectId).lean();
      if (user) {
        role = 'Admin';
        roleTitle = 'Organizing Committee / Admin';
        userApartmentId = user._id.toString();
      } else {
        user = await ManagementUser.findById(rawObjectId).lean();
        if (user) {
          role = 'Admin';
          roleTitle = user.roleTitle || 'Admin Member';
          userApartmentId = user.apartmentId?.toString();
        }
      }
    } else {
      const apartments = await Apartment.find({}).lean();
      user = apartments.find((a) => a._id.toString().toLowerCase().endsWith(tailHex));
      if (user) {
        role = 'Admin';
        roleTitle = 'Organizing Committee / Admin';
        userApartmentId = user._id.toString();
      } else {
        const mgmtUsers = await ManagementUser.find({}).lean();
        user = mgmtUsers.find((u) => u._id.toString().toLowerCase().endsWith(tailHex));
        if (user) {
          role = 'Admin';
          roleTitle = user.roleTitle || 'Admin Member';
          userApartmentId = user.apartmentId?.toString();
        }
      }
    }
  }

  // Case C: Event Staff
  if (!user && (rolePrefix === 'STF' || (!rolePrefix && rawObjectId))) {
    if (rawObjectId) {
      user = await EventStaff.findById(rawObjectId).lean();
    } else {
      const staffList = await EventStaff.find({}).lean();
      user = staffList.find((s) => s._id.toString().toLowerCase().endsWith(tailHex));
    }
    if (user) {
      role = 'Event Staff';
      roleTitle = user.roleTitle || 'Event Staff';
      userApartmentId = user.apartmentId?.toString();
    }
  }

  if (!user) return null;

  // 4. Resolve the ManagedEvent
  let event = null;
  if (userApartmentId && mongoose.Types.ObjectId.isValid(userApartmentId)) {
    event = await ManagedEvent.findOne({
      apartmentId: new mongoose.Types.ObjectId(userApartmentId),
    }).sort({ eventDate: -1 });
  }
  if (!event) {
    event = await ManagedEvent.findOne({}).sort({ eventDate: -1 });
  }
  if (!event) return null;

  const userMobile = (user.mobileNumber || user.contactPhone || '9999999999').trim();

  // 5. Look for an existing EventRegistration for this account
  reg = await EventRegistration.findOne({
    eventId: event._id,
    $or: [
      { idNumber: upper },
      { qrCode: upper },
      { mobileNumber: userMobile },
    ],
    status: { $ne: 'cancelled' },
  });

  if (reg) {
    let modified = false;
    if (reg.idNumber !== upper) {
      reg.idNumber = upper;
      modified = true;
    }
    if (reg.qrCode !== upper) {
      reg.qrCode = upper;
      modified = true;
    }
    if (modified) await reg.save();
    return reg;
  }

  // 6. Automatically provision an all-access registration for this role
  reg = new EventRegistration({
    eventId: event._id,
    apartmentId: event.apartmentId,
    name: user.name || role,
    mobileNumber: userMobile,
    email: user.email || '',
    institution: user.name ? `${user.name} (${role})` : role,
    title: role === 'Speaker' ? 'Dr' : '',
    participantType: role,
    designation: roleTitle,
    idNumber: upper,
    qrCode: upper,
    packageId: 'vip-all-access',
    packageName: `${role} Pass (All Access)`,
    source: 'spot',
    status: 'registered',
    otp: '000000',
    claimedInclusions: [],
    attendance: [],
  });

  await reg.save();
  return reg;
}

module.exports = { resolveRegistrationForCode };
