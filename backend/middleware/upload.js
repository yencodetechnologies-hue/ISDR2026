const path = require('path');
const multer = require('multer');
const cloudinary = require('../config/cloudinary');

// Memory storage: files are streamed straight to Cloudinary.
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB
  },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed!'), false);
    }
  },
});

const uploadSingleImage = (fieldName) => upload.single(fieldName);

// Upload an image buffer to Cloudinary and resolve with its secure URL.
const uploadToCloudinary = (fileBuffer, folder = 'isdr') =>
  new Promise((resolve, reject) => {
    if (!fileBuffer) {
      reject(new Error('No file buffer provided'));
      return;
    }
    cloudinary.ensureConfigured();
    if (
      !process.env.CLOUDINARY_API_KEY ||
      !process.env.CLOUDINARY_API_SECRET ||
      !process.env.CLOUDINARY_CLOUD_NAME
    ) {
      reject(new Error('Cloudinary credentials are not configured'));
      return;
    }
    cloudinary.uploader
      .upload_stream(
        {
          folder,
          resource_type: 'image',
          transformation: [{ width: 1000, height: 1000, crop: 'limit' }],
        },
        (error, result) => (error ? reject(error) : resolve(result.secure_url))
      )
      .end(fileBuffer);
  });

const DOCUMENT_EXTENSIONS = ['.pdf', '.ppt', '.pptx'];

// Session files (PDF / PPT). 10MB is Cloudinary's raw-file limit on the free plan.
const documentUpload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB
  },
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    if (DOCUMENT_EXTENSIONS.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error('Only PDF or PPT files are allowed!'), false);
    }
  },
});

const uploadSingleDocument = (fieldName) => documentUpload.single(fieldName);

// Upload a document buffer to Cloudinary as a raw file; resolves with its URL and id.
const uploadDocumentToCloudinary = (fileBuffer, folder, originalName) =>
  new Promise((resolve, reject) => {
    if (!fileBuffer) {
      reject(new Error('No file buffer provided'));
      return;
    }
    cloudinary.ensureConfigured();
    if (
      !process.env.CLOUDINARY_API_KEY ||
      !process.env.CLOUDINARY_API_SECRET ||
      !process.env.CLOUDINARY_CLOUD_NAME
    ) {
      reject(new Error('Cloudinary credentials are not configured'));
      return;
    }
    // Raw files keep their extension in the public id, so the URL ends in .pdf / .pptx.
    const ext = path.extname(originalName || '').toLowerCase();
    const base =
      path
        .basename(originalName || 'file', ext)
        .replace(/[^a-zA-Z0-9_-]+/g, '_')
        .slice(0, 60) || 'file';
    cloudinary.uploader
      .upload_stream(
        { folder, resource_type: 'raw', public_id: `${base}_${Date.now()}${ext}` },
        (error, result) =>
          error ? reject(error) : resolve({ url: result.secure_url, publicId: result.public_id })
      )
      .end(fileBuffer);
  });

// Remove a file from Cloudinary (best effort — callers ignore failures).
const deleteFromCloudinary = (publicId, resourceType = 'raw') => {
  if (!publicId) return Promise.resolve();
  cloudinary.ensureConfigured();
  return cloudinary.uploader.destroy(publicId, { resource_type: resourceType });
};

module.exports = {
  upload,
  uploadSingleImage,
  uploadToCloudinary,
  uploadSingleDocument,
  uploadDocumentToCloudinary,
  deleteFromCloudinary,
};
