const express = require('express');
const router = express.Router();
const { protect, requireManagement } = require('../middleware/auth');
const { uploadSingleImage } = require('../middleware/upload');
const { sendNotification } = require('../controllers/eventNotificationController');
const { claimSummary } = require('../controllers/claimSummaryController');
const {
  listSchedules,
  createSchedule,
  updateSchedule,
  reorderSchedule,
  deleteSchedule,
  mySpeakerSessions,
  myFavorites,
  toggleFavorite,
  myReminders,
  toggleReminder,
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
  claimInclusion,
  reclaimInclusion,
  getMyRegistration,
} = require('../controllers/managedEventController');

// Events - GET list and GET by id are readable by any authenticated user/participant/management
router.get('/', protect, listEvents);
// Must come before '/:id'.
router.get('/summary', protect, requireManagement, claimSummary);
router.get('/my-registration', protect, getMyRegistration);
router.get('/my-speaker-sessions', protect, mySpeakerSessions);
router.get('/my-favorites', protect, myFavorites);
router.post('/favorites/:scheduleId', protect, toggleFavorite);
// Participant: remind me when a session starts (push)
router.get('/my-reminders', protect, myReminders);
router.post('/reminders/:scheduleId', protect, toggleReminder);
router.post('/claim-inclusion', protect, claimInclusion);
router.post('/', protect, requireManagement, uploadSingleImage('photo'), createEvent);
router.get('/:id', protect, getEvent);
router.put('/:id', protect, requireManagement, uploadSingleImage('photo'), updateEvent);
router.delete('/:id', protect, requireManagement, deleteEvent);

// Registrations (participants) - readable by event staff / management
router.get('/:id/registrations', protect, listRegistrations);
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
router.post(
  '/:id/registrations/:regId/claims/:claimId/reclaim',
  protect,
  requireManagement,
  reclaimInclusion
);

// Schedules (speaker sessions) - GET schedules is viewable by participants & management; create/delete require management
router.get('/:id/schedules', protect, listSchedules);
router.post(
  '/:id/schedules',
  protect,
  requireManagement,
  uploadSingleImage('photo'),
  createSchedule
);
router.put('/:id/schedules/:scheduleId/order', protect, requireManagement, reorderSchedule);
router.put('/:id/schedules/:scheduleId', protect, requireManagement, updateSchedule);
router.delete('/:id/schedules/:scheduleId', protect, requireManagement, deleteSchedule);

// Notifications to an event's participants
router.post('/:id/notifications', protect, requireManagement, sendNotification);

module.exports = router;
