const PreconferenceCourse = require('../models/PreconferenceCourse');

const toDto = (row) => ({
  id: row._id.toString(),
  serialNo: row.serialNo,
  date: row.date,
  course: row.course,
  venue: row.venue,
  createdAt: row.createdAt,
});

const readFields = (body) => {
  const serialNo = Number(body.serialNo);
  const date = String(body.date || '').trim();
  const course = String(body.course || '').trim();
  const venue = String(body.venue || '').trim();
  if (!Number.isInteger(serialNo) || serialNo < 1) {
    return { error: 'S No must be a whole number starting at 1' };
  }
  if (!date) return { error: 'Date is required' };
  if (!course) return { error: 'Pre conference course is required' };
  if (!venue) return { error: 'Venue is required' };
  return { serialNo, date, course, venue };
};

const sendError = (res, error, label) => {
  if (error.code === 11000) {
    return res.status(400).json({ success: false, error: 'That S No is already used' });
  }
  if (error.name === 'CastError') {
    return res.status(404).json({ success: false, error: 'Course not found' });
  }
  console.error(`${label} error:`, error);
  return res.status(500).json({ success: false, error: error.message || 'Server error' });
};

// GET /api/preconference — any login on the property.
const listCourses = async (req, res) => {
  try {
    const list = await PreconferenceCourse.find({ apartmentId: req.apartmentId }).sort({
      serialNo: 1,
      createdAt: 1,
    });
    res.json({ success: true, courses: list.map(toDto) });
  } catch (error) {
    sendError(res, error, 'listCourses');
  }
};

// POST /api/preconference
const createCourse = async (req, res) => {
  try {
    const fields = readFields(req.body);
    if (fields.error) return res.status(400).json({ success: false, error: fields.error });
    const course = await PreconferenceCourse.create({
      apartmentId: req.apartmentId,
      ...fields,
    });
    res.status(201).json({ success: true, course: toDto(course) });
  } catch (error) {
    sendError(res, error, 'createCourse');
  }
};

// PUT /api/preconference/:id
const updateCourse = async (req, res) => {
  try {
    const fields = readFields(req.body);
    if (fields.error) return res.status(400).json({ success: false, error: fields.error });
    const course = await PreconferenceCourse.findOneAndUpdate(
      { _id: req.params.id, apartmentId: req.apartmentId },
      fields,
      { new: true, runValidators: true }
    );
    if (!course) return res.status(404).json({ success: false, error: 'Course not found' });
    res.json({ success: true, course: toDto(course) });
  } catch (error) {
    sendError(res, error, 'updateCourse');
  }
};

// DELETE /api/preconference/:id
const deleteCourse = async (req, res) => {
  try {
    const removed = await PreconferenceCourse.findOneAndDelete({
      _id: req.params.id,
      apartmentId: req.apartmentId,
    });
    if (!removed) return res.status(404).json({ success: false, error: 'Course not found' });
    res.json({ success: true });
  } catch (error) {
    sendError(res, error, 'deleteCourse');
  }
};

module.exports = { listCourses, createCourse, updateCourse, deleteCourse };
