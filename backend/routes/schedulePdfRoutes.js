const express = require('express');
const router = express.Router();
const { protect, requireManagement } = require('../middleware/auth');
const { uploadSinglePdf } = require('../middleware/upload');
const { getSchedulePdf, uploadSchedulePdf } = require('../controllers/schedulePdfController');

// Programme PDF: admin uploads it to Cloudinary, every login reads that URL.
router.get('/', protect, getSchedulePdf);
router.post('/', protect, requireManagement, uploadSinglePdf('pdf'), uploadSchedulePdf);

module.exports = router;
