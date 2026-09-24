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

module.exports = { upload, uploadSingleImage, uploadToCloudinary };
