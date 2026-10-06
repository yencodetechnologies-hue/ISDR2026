const express = require('express');
const router = express.Router();
const { protect, requireManagement } = require('../middleware/auth');
const { uploadSinglePdf } = require('../middleware/upload');
const { getPaperPosterPdf, uploadPaperPosterPdf } = require('../controllers/paperPosterPdfController');

// Paper and poster PDF: admin uploads it to Cloudinary, every login reads that URL.
router.get('/', protect, getPaperPosterPdf);
router.post('/', protect, requireManagement, (req, res, next) => {
  uploadSinglePdf('pdf')(req, res, (err) => {
    if (!err) return next();
    const tooBig = err.code === 'LIMIT_FILE_SIZE';
    res.status(400).json({
      success: false,
      error: tooBig ? 'PDF is larger than 20 MB. Choose a smaller file.' : err.message || 'Upload failed',
    });
  });
}, uploadPaperPosterPdf);

module.exports = router;
