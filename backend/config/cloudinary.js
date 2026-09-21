const cloudinary = require('cloudinary').v2;

function ensureCloudinaryConfigured() {
  cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET,
  });
}

// Configure at import time, and let callers re-configure after env vars are loaded.
ensureCloudinaryConfigured();
cloudinary.ensureConfigured = ensureCloudinaryConfigured;

module.exports = cloudinary;
