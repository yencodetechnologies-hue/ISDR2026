const UgPaperPdf = require('../models/UgPaperPdf');
const { uploadPdfToCloudinary, compressPdfBuffer } = require('../middleware/upload');

function toDto(doc) {
  if (!doc || !doc.url) {
    return { url: '', fileName: '', updatedAt: null };
  }
  return {
    url: doc.url,
    fileName: doc.fileName || 'ug-paper.pdf',
    updatedAt: doc.updatedAt,
  };
}

// GET /api/ug-paper-pdf — any login. url is '' until an admin uploads one.
const getUgPaperPdf = async (req, res) => {
  try {
    const doc = await UgPaperPdf.findOne({ apartmentId: req.apartmentId });
    res.json({ success: true, ...toDto(doc) });
  } catch (error) {
    console.error('getUgPaperPdf error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// POST /api/ug-paper-pdf  (multipart `pdf`) — admin replaces the Cloudinary PDF.
const uploadUgPaperPdf = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, error: 'Choose a PDF file' });
    }
    const compressed = await compressPdfBuffer(req.file.buffer);
    const uploaded = await uploadPdfToCloudinary(compressed, {
      folder: 'isdr/ug-paper',
      publicId: String(req.apartmentId),
    });
    const fileName = String(req.file.originalname || 'ug-paper.pdf')
      .replace(/[^\w.\- ()]/g, '')
      .trim() || 'ug-paper.pdf';
    const doc = await UgPaperPdf.findOneAndUpdate(
      { apartmentId: req.apartmentId },
      {
        $set: { fileName, url: uploaded.url, publicId: uploaded.publicId },
        $setOnInsert: { apartmentId: req.apartmentId },
      },
      { upsert: true, new: true }
    );
    res.json({ success: true, ...toDto(doc) });
  } catch (error) {
    console.error('uploadUgPaperPdf error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

module.exports = { getUgPaperPdf, uploadUgPaperPdf };
