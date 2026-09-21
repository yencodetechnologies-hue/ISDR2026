const express = require('express');
const router = express.Router();
const { protect, requireManagement } = require('../middleware/auth');
const { uploadSingleImage } = require('../middleware/upload');
const {
  listEvents,
  createEvent,
  getEvent,
  updateEvent,
  deleteEvent,
  listRegistrations,
  createSpotRegistration,
  updateRegistration,
  deleteRegistration,
  bulkImportRegistrations,
} = require('../controllers/managedEventController');

// Events
router.get('/', protect, requireManagement, listEvents);
router.post('/', protect, requireManagement, createEvent);
router.get('/:id', protect, requireManagement, getEvent);
router.put('/:id', protect, requireManagement, updateEvent);
router.delete('/:id', protect, requireManagement, deleteEvent);

// Registrations (participants)
router.get('/:id/registrations', protect, requireManagement, listRegistrations);
router.post(
  '/:id/registrations/spot',
  protect,
  requireManagement,
  uploadSingleImage('photo'),
  createSpotRegistration
);
router.post('/:id/registrations/bulk', protect, requireManagement, bulkImportRegistrations);
router.put(
  '/:id/registrations/:regId',
  protect,
  requireManagement,
  uploadSingleImage('photo'),
  updateRegistration
);
router.delete('/:id/registrations/:regId', protect, requireManagement, deleteRegistration);

module.exports = router;
