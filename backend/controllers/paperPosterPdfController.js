const PaperPosterPdf = require('../models/PaperPosterPdf');
const { uploadPdfToCloudinary, compressPdfBuffer } = require('../middleware/upload');

function toDto(doc) {
  if (!doc || !doc.url) {
    return { url: '', fileName: '', updatedAt: null };
  }
  return {
    url: doc.url,
    fileName: doc.fileName || 'paper-poster.pdf',
    updatedAt: doc.updatedAt,
  };
}

// GET /api/paper-poster-pdf — any login. url is '' until an admin uploads one.
const getPaperPosterPdf = async (req, res) => {
  try {
    const doc = await PaperPosterPdf.findOne({ apartmentId: req.apartmentId });
    res.json({ success: true, ...toDto(doc) });
  } catch (error) {
    console.error('getPaperPosterPdf error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// POST /api/paper-poster-pdf  (multipart `pdf`) — admin replaces the Cloudinary PDF.
const uploadPaperPosterPdf = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, error: 'Choose a PDF file' });
    }
    const original = req.file.buffer;
    const compressed = await compressPdfBuffer(original);
    const options = {
      folder: 'isdr/paper-poster',
      publicId: String(req.apartmentId),
      resourceType: 'image',
    };
    let uploaded;
    try {
      uploaded = await uploadPdfToCloudinary(compressed, options);
    } catch (firstError) {
      if (compressed === original) throw firstError;
      console.warn('Compressed PDF rejected, uploading the original:', firstError.message || firstError);
      uploaded = await uploadPdfToCloudinary(original, options);
    }
    if (!uploaded.url) {
      throw new Error('Cloudinary did not return a link');
    }
    const fileName = String(req.file.originalname || 'paper-poster.pdf')
      .replace(/[^\w.\- ()]/g, '')
      .trim() || 'paper-poster.pdf';
    const doc = await PaperPosterPdf.findOneAndUpdate(
      { apartmentId: req.apartmentId },
      {
        $set: { fileName, url: uploaded.url, publicId: uploaded.publicId },
        $setOnInsert: { apartmentId: req.apartmentId },
      },
      { upsert: true, new: true }
    );
    res.json({ success: true, ...toDto(doc) });
  } catch (error) {
    console.error('uploadPaperPosterPdf error:', error);
    const raw = error?.message || 'Server error';
    const forbidden = /403|forbidden|missing permissions|not allowed to create/i.test(raw);
    res.status(forbidden ? 403 : 500).json({
      success: false,
      error: forbidden
        ? 'Cloudinary refused the upload. This API key cannot create files. In the Cloudinary console, open Settings, API Keys, and allow the create action for this key. Then upload the PDF again — the link will show here.'
        : raw,
    });
  }
};

module.exports = { getPaperPosterPdf, uploadPaperPosterPdf };
