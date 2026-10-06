const Exhibitor = require('../models/Exhibitor');
const { uploadToCloudinary } = require('../middleware/upload');

const toDto = (e) => ({
  id: e._id.toString(),
  shopName: e.shopName,
  photo: e.photo || '',
  category: e.category,
  location: e.location,
  createdAt: e.createdAt,
});

/** A1, A2, … then B1, B2, … Locations that are not a stall code stay at the end. */
function stallRank(location) {
  const match = String(location || '').trim().toUpperCase().match(/^([A-Z])\s*(\d+)/);
  if (!match) return { letter: 'ZZ', num: 9999 };
  return { letter: match[1], num: Number(match[2]) };
}

function byStall(a, b) {
  const left = stallRank(a.location);
  const right = stallRank(b.location);
  if (left.letter !== right.letter) return left.letter < right.letter ? -1 : 1;
  if (left.num !== right.num) return left.num - right.num;
  return String(a.shopName || '').localeCompare(String(b.shopName || ''));
}

// GET /api/exhibitors — the property's exhibitors, A stall then B stall (any login).
const listExhibitors = async (req, res) => {
  try {
    const list = await Exhibitor.find({ apartmentId: req.apartmentId });
    list.sort(byStall);
    res.json({ success: true, exhibitors: list.map(toDto) });
  } catch (error) {
    console.error('listExhibitors error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// POST /api/exhibitors  (multipart: shopName, category, location, optional `photo`)
const createExhibitor = async (req, res) => {
  try {
    const shopName = String(req.body.shopName || '').trim();
    const category = String(req.body.category || '').trim();
    const location = String(req.body.location || '').trim();
    if (!shopName) return res.status(400).json({ success: false, error: 'Shop name is required' });
    if (!category) return res.status(400).json({ success: false, error: 'Category is required' });
    if (!location) return res.status(400).json({ success: false, error: 'Location is required' });

    const photo = req.file ? await uploadToCloudinary(req.file.buffer, 'isdr/exhibitors') : '';
    const exhibitor = await Exhibitor.create({
      apartmentId: req.apartmentId,
      shopName,
      photo,
      category,
      location,
    });
    res.status(201).json({ success: true, exhibitor: toDto(exhibitor) });
  } catch (error) {
    console.error('createExhibitor error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

// DELETE /api/exhibitors/:id
const deleteExhibitor = async (req, res) => {
  try {
    const removed = await Exhibitor.findOneAndDelete({
      _id: req.params.id,
      apartmentId: req.apartmentId,
    });
    if (!removed) return res.status(404).json({ success: false, error: 'Exhibitor not found' });
    res.json({ success: true });
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(404).json({ success: false, error: 'Exhibitor not found' });
    }
    console.error('deleteExhibitor error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

module.exports = { listExhibitors, createExhibitor, deleteExhibitor };
