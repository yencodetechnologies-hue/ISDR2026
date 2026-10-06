const express = require('express');
const router = express.Router();
const { protect, requireManagement } = require('../middleware/auth');
const { uploadSinglePdf } = require('../middleware/upload');
const { getUgPaperPdf, uploadUgPaperPdf } = require('../controllers/ugPaperPdfController');

// UG paper / e-poster PDF: admin uploads it to Cloudinary, every login reads that URL.
router.get('/', protect, getUgPaperPdf);
router.post('/', protect, requireManagement, uploadSinglePdf('pdf'), uploadUgPaperPdf);

module.exports = router;
