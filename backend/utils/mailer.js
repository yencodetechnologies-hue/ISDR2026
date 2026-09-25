const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const nodemailer = require('nodemailer');

// Gmail SMTP with an app password (SMTP_USER / SMTP_PASS in .env).
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.SMTP_USER,
    pass: String(process.env.SMTP_PASS || '').replace(/\s+/g, ''),
  },
});

const sendMail = ({ to, subject, text, html }) =>
  transporter.sendMail({
    from: `"ISDR 2026" <${process.env.SMTP_USER}>`,
    to,
    subject,
    text,
    html,
  });

module.exports = { sendMail };
