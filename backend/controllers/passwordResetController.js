const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const Apartment = require('../models/Apartment');
const ManagementUser = require('../models/ManagementUser');
const EventStaff = require('../models/EventStaff');
const EventRegistration = require('../models/EventRegistration');
const PasswordResetOtp = require('../models/PasswordResetOtp');
const { sendMail } = require('../utils/mailer');

const OTP_MINUTES = 10;
const MAX_ATTEMPTS = 5;

const normEmail = (v) => String(v || '').trim().toLowerCase();
const emailFilter = (email) => ({
  email: new RegExp(`^${email.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i'),
});

/** Every login account (admin, admin ID, event staff, participant) with this email. */
async function accountsFor(email) {
  const f = emailFilter(email);
  const [apartments, managers, staff, participants] = await Promise.all([
    Apartment.find(f),
    ManagementUser.find(f),
    EventStaff.find(f),
    EventRegistration.find({ ...f, status: { $ne: 'cancelled' } }),
  ]);
  return { apartments, managers, staff, participants };
}

const countOf = (a) => a.apartments.length + a.managers.length + a.staff.length + a.participants.length;

/** The latest unexpired code for this email, if it matches (counts wrong tries). */
async function checkOtp(email, otp) {
  const record = await PasswordResetOtp.findOne({ email, expiresAt: { $gt: new Date() } }).sort({ createdAt: -1 });
  if (!record) return { ok: false, error: 'OTP expired. Please request a new one.' };
  if (record.attempts >= MAX_ATTEMPTS) return { ok: false, error: 'Too many wrong attempts. Please request a new OTP.' };
  if (!(await bcrypt.compare(String(otp || '').trim(), record.otpHash))) {
    record.attempts += 1;
    await record.save();
    return { ok: false, error: 'Invalid OTP' };
  }
  return { ok: true, record };
}

// POST /api/auth/forgot-password { email } — emails a 6-digit code.
const forgotPassword = async (req, res) => {
  try {
    const email = normEmail(req.body.email);
    if (!email) return res.status(400).json({ success: false, error: 'Email is required' });
    if (!countOf(await accountsFor(email))) {
      return res.status(404).json({ success: false, error: 'No account found with this email' });
    }

    const otp = crypto.randomInt(100000, 1000000).toString();
    await PasswordResetOtp.deleteMany({ email });
    await PasswordResetOtp.create({
      email,
      otpHash: await bcrypt.hash(otp, 10),
      expiresAt: new Date(Date.now() + OTP_MINUTES * 60000),
    });

    await sendMail({
      to: email,
      subject: 'ISDR 2026 - Password reset code',
      text: `Your ISDR 2026 password reset code is ${otp}. It is valid for ${OTP_MINUTES} minutes. If you did not request this, ignore this email.`,
      html: `<div style="font-family:Arial,sans-serif;max-width:420px">
        <h2 style="color:#1e3a8a">ISDR 2026</h2>
        <p>Your password reset code is:</p>
        <p style="font-size:30px;font-weight:bold;letter-spacing:8px;color:#2563eb">${otp}</p>
        <p>It is valid for ${OTP_MINUTES} minutes.</p>
        <p style="color:#6b7280;font-size:12px">If you did not request this, you can ignore this email.</p>
      </div>`,
    });

    res.json({ success: true, message: 'OTP sent to your email' });
  } catch (error) {
    console.error('forgotPassword error:', error);
    res.status(500).json({ success: false, error: 'Could not send the OTP email. Please try again.' });
  }
};

// POST /api/auth/verify-otp { email, otp }
const verifyOtp = async (req, res) => {
  try {
    const result = await checkOtp(normEmail(req.body.email), req.body.otp);
    if (!result.ok) return res.status(400).json({ success: false, error: result.error });
    res.json({ success: true, message: 'OTP verified' });
  } catch (error) {
    console.error('verifyOtp error:', error);
    res.status(500).json({ success: false, error: 'Server error' });
  }
};

// POST /api/auth/reset-password { email, otp, newPassword }
// Sets the new password on every account that uses this email.
const resetPassword = async (req, res) => {
  try {
    const email = normEmail(req.body.email);
    const newPassword = String(req.body.newPassword || '');
    if (newPassword.length < 6) {
      return res.status(400).json({ success: false, error: 'Password must be at least 6 characters' });
    }
    const result = await checkOtp(email, req.body.otp);
    if (!result.ok) return res.status(400).json({ success: false, error: result.error });

    const accounts = await accountsFor(email);
    if (!countOf(accounts)) {
      return res.status(404).json({ success: false, error: 'No account found with this email' });
    }
    // Models with a pre-save hook hash the password themselves; ManagementUser does not.
    for (const doc of [...accounts.apartments, ...accounts.staff, ...accounts.participants]) {
      doc.password = newPassword;
      await doc.save();
    }
    const hashed = await bcrypt.hash(newPassword, 10);
    for (const doc of accounts.managers) {
      doc.password = hashed;
      await doc.save();
    }
    await PasswordResetOtp.deleteMany({ email });

    res.json({ success: true, message: 'Password reset successfully' });
  } catch (error) {
    console.error('resetPassword error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

module.exports = { forgotPassword, verifyOtp, resetPassword };
