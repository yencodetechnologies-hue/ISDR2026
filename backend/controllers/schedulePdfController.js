const SchedulePdf = require('../models/SchedulePdf');
const { uploadPdfToCloudinary } = require('../middleware/upload');

function toDto(doc) {
  if (!doc || !doc.url) {
    return { url: '', fileName: '', updatedAt: null };
  }
  return {
    url: doc.url,
    fileName: doc.fileName || 'schedule.pdf',
    updatedAt: doc.updatedAt,
  };
}

// GET /api/schedule-pdf — any login. url is '' until an admin uploads one.
const getSchedulePdf = async (req, res) => {
  try {
    const doc = await SchedulePdf.findOne({ apartmentId: req.apartmentId });
    res.json({ success: true, ...toDto(doc) });
  } catch (error) {
    console.error('getSchedulePdf error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// POST /api/schedule-pdf  (multipart `pdf`) — admin uploads the PDF to Cloudinary.
const uploadSchedulePdf = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, error: 'Choose a PDF file' });
    }
    const uploaded = await uploadPdfToCloudinary(req.file.buffer, {
      publicId: String(req.apartmentId),
    });
    const fileName = String(req.file.originalname || 'schedule.pdf')
      .replace(/[^\w.\- ()]/g, '')
      .trim() || 'schedule.pdf';
    const doc = await SchedulePdf.findOneAndUpdate(
      { apartmentId: req.apartmentId },
      {
        $set: { fileName, url: uploaded.url, publicId: uploaded.publicId },
        $setOnInsert: { apartmentId: req.apartmentId },
      },
      { upsert: true, new: true }
    );
    res.json({ success: true, ...toDto(doc) });
  } catch (error) {
    console.error('uploadSchedulePdf error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

module.exports = { getSchedulePdf, uploadSchedulePdf };
