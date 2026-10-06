const { execFile } = require('child_process');
const fs = require('fs');
const os = require('os');
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

// Programme schedule PDFs are larger than banner images and are not pictures.
const uploadPdf = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 20 * 1024 * 1024, // 20MB
  },
  fileFilter: (req, file, cb) => {
    const name = String(file.originalname || '').toLowerCase();
    if (file.mimetype === 'application/pdf' || name.endsWith('.pdf')) {
      cb(null, true);
    } else {
      cb(new Error('Only PDF files are allowed'), false);
    }
  },
});

const uploadSinglePdf = (fieldName) => uploadPdf.single(fieldName);

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

function cloudinaryErrorMessage(error) {
  if (!error) return 'Cloudinary upload failed';
  if (typeof error === 'string') return error;
  return error.message || error.error?.message || 'Cloudinary upload failed';
}

// Upload a PDF buffer to Cloudinary and resolve with its URL.
// resourceType "image" stores the PDF the way Cloudinary stores images (a public link).
// "raw" is kept for the programme schedule upload.
const uploadPdfToCloudinary = (fileBuffer, { folder = 'isdr/schedule', publicId, resourceType = 'raw' } = {}) =>
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
    const asImage = resourceType === 'image' || resourceType === 'auto';
    cloudinary.uploader
      .upload_stream(
        {
          folder,
          public_id: publicId,
          resource_type: asImage ? 'image' : 'raw',
          format: 'pdf',
          overwrite: true,
          invalidate: true,
          unique_filename: false,
          use_filename: false,
        },
        (error, result) => {
          if (error) {
            reject(new Error(cloudinaryErrorMessage(error)));
            return;
          }
          const url = String(result.secure_url || '');
          resolve({ url, publicId: result.public_id });
        }
      )
      .end(fileBuffer);
  });

const GS_BINS = process.platform === 'win32' ? ['gswin64c', 'gswin32c', 'gs'] : ['gs'];

function runGhostscript(bin, input, output) {
  return new Promise((resolve, reject) => {
    execFile(
      bin,
      [
        '-sDEVICE=pdfwrite',
        '-dCompatibilityLevel=1.4',
        '-dPDFSETTINGS=/ebook',
        '-dNOPAUSE',
        '-dQUIET',
        '-dBATCH',
        `-sOutputFile=${output}`,
        input,
      ],
      { timeout: 120000 },
      (error) => (error ? reject(error) : resolve())
    );
  });
}

// Shrink a PDF with Ghostscript (/ebook) when the binary is installed.
// Returns the original buffer when Ghostscript is missing or the result is not smaller.
const compressPdfBuffer = async (fileBuffer) => {
  if (!fileBuffer || !fileBuffer.length) return fileBuffer;
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ug-paper-'));
  const input = path.join(dir, 'in.pdf');
  const output = path.join(dir, 'out.pdf');
  try {
    fs.writeFileSync(input, fileBuffer);
    let compressed = false;
    for (const bin of GS_BINS) {
      try {
        await runGhostscript(bin, input, output);
        compressed = true;
        break;
      } catch (error) {
        if (error && error.code !== 'ENOENT') {
          console.warn(`PDF compress via ${bin} failed:`, error.message || error);
        }
      }
    }
    if (!compressed || !fs.existsSync(output)) return fileBuffer;
    const next = fs.readFileSync(output);
    if (!next.length || next.length >= fileBuffer.length) return fileBuffer;
    return next;
  } catch (error) {
    console.warn('PDF compress skipped:', error.message || error);
    return fileBuffer;
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
};

module.exports = {
  upload,
  uploadSingleImage,
  uploadSinglePdf,
  uploadToCloudinary,
  uploadPdfToCloudinary,
  compressPdfBuffer,
};
