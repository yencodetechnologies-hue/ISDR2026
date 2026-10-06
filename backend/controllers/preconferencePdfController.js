const PreconferencePdf = require('../models/PreconferencePdf');
const { uploadPdfToCloudinary, compressPdfBuffer } = require('../middleware/upload');

function toDto(doc) {
  if (!doc || !doc.url) {
    return { url: '', fileName: '', updatedAt: null };
  }
  return {
    url: doc.url,
    fileName: doc.fileName || 'preconference.pdf',
    updatedAt: doc.updatedAt,
  };
}

// GET /api/preconference-pdf — any login. url is '' until an admin uploads one.
const getPreconferencePdf = async (req, res) => {
  try {
    const doc = await PreconferencePdf.findOne({ apartmentId: req.apartmentId });
    res.json({ success: true, ...toDto(doc) });
  } catch (error) {
    console.error('getPreconferencePdf error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// POST /api/preconference-pdf  (multipart `pdf`) — admin replaces the Cloudinary PDF.
const uploadPreconferencePdf = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, error: 'Choose a PDF file' });
    }
    const original = req.file.buffer;
    const compressed = await compressPdfBuffer(original);
    const options = {
      folder: 'isdr/preconference',
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
    const fileName = String(req.file.originalname || 'preconference.pdf')
      .replace(/[^\w.\- ()]/g, '')
      .trim() || 'preconference.pdf';
    const doc = await PreconferencePdf.findOneAndUpdate(
      { apartmentId: req.apartmentId },
      {
        $set: { fileName, url: uploaded.url, publicId: uploaded.publicId },
        $setOnInsert: { apartmentId: req.apartmentId },
      },
      { upsert: true, new: true }
    );
    res.json({ success: true, ...toDto(doc) });
  } catch (error) {
    console.error('uploadPreconferencePdf error:', error);
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

module.exports = { getPreconferencePdf, uploadPreconferencePdf };
