const express = require('express');
const router = express.Router();
const { protect, requireManagement } = require('../middleware/auth');
const {
  listCourses,
  createCourse,
  updateCourse,
  deleteCourse,
} = require('../controllers/preconferenceController');

// Management adds, edits, and removes courses; every login on the property can list them.
router.get('/', protect, listCourses);
router.post('/', protect, requireManagement, createCourse);
router.put('/:id', protect, requireManagement, updateCourse);
router.delete('/:id', protect, requireManagement, deleteCourse);

module.exports = router;
