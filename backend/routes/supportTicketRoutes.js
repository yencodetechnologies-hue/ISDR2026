const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const {
  listTickets,
  createTicket,
  getTicket,
  sendMessage,
  closeTicket,
} = require('../controllers/supportTicketController');

// Help & Support: participants raise tickets; event staff and admin reply.
// Who may do what is checked in the controller.
router.get('/', protect, listTickets);
router.post('/', protect, createTicket);
router.get('/:id', protect, getTicket);
router.post('/:id/messages', protect, sendMessage);
router.post('/:id/close', protect, closeTicket);

module.exports = router;
