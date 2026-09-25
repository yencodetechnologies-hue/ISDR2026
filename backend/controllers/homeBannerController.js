const HomeBanner = require('../models/HomeBanner');
const { uploadToCloudinary } = require('../middleware/upload');

const toDto = (b) => ({
  enabled: b ? b.enabled !== false : true,
  images: b ? b.images.map((i) => ({ id: i._id.toString(), url: i.url })) : [],
});

/** The property's banner, created (on, no images) the first time it's needed. */
function findOrCreate(apartmentId) {
  return HomeBanner.findOneAndUpdate(
    { apartmentId },
    { $setOnInsert: { apartmentId } },
    { upsert: true, new: true }
  );
}

function handleError(res, label, error) {
  console.error(`${label} error:`, error);
  return res.status(500).json({ success: false, error: error.message || 'Server error' });
}

// GET /api/home-banner — any login on the property.
const getBanner = async (req, res) => {
  try {
    const banner = await HomeBanner.findOne({ apartmentId: req.apartmentId });
    res.json({ success: true, banner: toDto(banner) });
  } catch (error) {
    handleError(res, 'getBanner', error);
  }
};

// PUT /api/home-banner  { enabled }
const setEnabled = async (req, res) => {
  try {
    if (typeof req.body.enabled !== 'boolean') {
      return res.status(400).json({ success: false, error: 'enabled must be true or false' });
    }
    await findOrCreate(req.apartmentId);
    const banner = await HomeBanner.findOneAndUpdate(
      { apartmentId: req.apartmentId },
      { enabled: req.body.enabled },
      { new: true }
    );
    res.json({ success: true, banner: toDto(banner) });
  } catch (error) {
    handleError(res, 'setEnabled', error);
  }
};

// POST /api/home-banner/images  (multipart `image`)
const addImage = async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ success: false, error: 'Choose an image' });
    const url = await uploadToCloudinary(req.file.buffer, 'isdr/home-banner');
    await findOrCreate(req.apartmentId);
    const banner = await HomeBanner.findOneAndUpdate(
      { apartmentId: req.apartmentId },
      { $push: { images: { url } } },
      { new: true }
    );
    res.status(201).json({ success: true, banner: toDto(banner) });
  } catch (error) {
    handleError(res, 'addImage', error);
  }
};

// DELETE /api/home-banner/images/:imageId
const deleteImage = async (req, res) => {
  try {
    const banner = await HomeBanner.findOneAndUpdate(
      { apartmentId: req.apartmentId, 'images._id': req.params.imageId },
      { $pull: { images: { _id: req.params.imageId } } },
      { new: true }
    );
    if (!banner) return res.status(404).json({ success: false, error: 'Image not found' });
    res.json({ success: true, banner: toDto(banner) });
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(404).json({ success: false, error: 'Image not found' });
    }
    handleError(res, 'deleteImage', error);
  }
};

module.exports = { getBanner, setEnabled, addImage, deleteImage };
