const express = require('express');
const router = express.Router();
const { protect, requireManagement } = require('../middleware/auth');
const { uploadSingleImage } = require('../middleware/upload');
const { sendNotification } = require('../controllers/eventNotificationController');
const { claimSummary } = require('../controllers/claimSummaryController');
const {
  listSchedules,
  createSchedule,
  deleteSchedule,
} = require('../controllers/eventScheduleController');
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

// Events - GET list and GET by id are readable by any authenticated user/participant/management
router.get('/', protect, listEvents);
// Must come before '/:id'.
router.get('/summary', protect, requireManagement, claimSummary);
router.post('/', protect, requireManagement, createEvent);
router.get('/:id', protect, getEvent);
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

// Schedules (speaker sessions) - GET schedules is viewable by participants & management; create/delete require management
router.get('/:id/schedules', protect, listSchedules);
router.post(
  '/:id/schedules',
  protect,
  requireManagement,
  uploadSingleImage('photo'),
  createSchedule
);
router.delete('/:id/schedules/:scheduleId', protect, requireManagement, deleteSchedule);

// Notifications to an event's participants
router.post('/:id/notifications', protect, requireManagement, sendNotification);

module.exports = router;
