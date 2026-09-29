const SupportTicket = require('../models/SupportTicket');
const EventRegistration = require('../models/EventRegistration');
const EventStaff = require('../models/EventStaff');
const Apartment = require('../models/Apartment');
const ManagementUser = require('../models/ManagementUser');
const {
  sendNotificationToUser,
  sendNotificationToApartmentByUserType,
} = require('../utils/fcmService');

const MAX_LENGTH = 2000;

/** What participants see instead of a staff/admin member's name and role. */
const SUPPORT_TEAM_NAME = 'ISDR2026 Support Team';

/**
 * Who is calling, as a chat sender: participant, event staff or admin
 * (the property login or a Management ID). Speakers can't use tickets.
 */
async function currentSender(req) {
  if (req.userType === 'participant') {
    const reg = await EventRegistration.findById(req.userId).select('name');
    return { type: 'participant', id: req.userId, name: reg ? reg.name : 'Participant' };
  }
  if (req.userType === 'user') {
    const staff = await EventStaff.findById(req.userId).select('name');
    return { type: 'staff', id: req.userId, name: staff ? staff.name : 'Event Staff' };
  }
  if (req.userType === 'apartment') {
    if (req.managementUserId) {
      const m = await ManagementUser.findById(req.managementUserId).select('name');
      return { type: 'admin', id: req.managementUserId, name: m ? m.name : 'Admin' };
    }
    const apt = await Apartment.findById(req.userId).select('name');
    return { type: 'admin', id: req.userId, name: apt ? apt.name : 'Admin' };
  }
  return null;
}

function forbidden(res) {
  return res.status(403).json({ success: false, error: 'Not allowed' });
}

function handleError(res, label, error) {
  if (error.name === 'CastError') {
    return res.status(404).json({ success: false, error: 'Ticket not found' });
  }
  console.error(`${label} error:`, error);
  return res.status(500).json({ success: false, error: error.message || 'Server error' });
}

const CATEGORY_LABELS = {
  emergency: 'Emergency',
  medical: 'Medical Issues',
  others: 'Others',
  app: 'App related issues',
};

const preview = (text) => (text.length > 120 ? `${text.slice(0, 117)}...` : text);

/** Push to every event staff member and admin (login + Management IDs) of the property. */
async function notifyTeam(apartmentId, { title, body, ticketId }) {
  await sendNotificationToApartmentByUserType(apartmentId, ['apartment', 'management', 'user'], {
    title,
    body,
    type: 'support_ticket',
    data: { ticketId },
  });
}

/** Push to the participant who raised the ticket (as the support team). */
async function notifyParticipant(ticket, body) {
  await sendNotificationToUser(ticket.participantId.toString(), 'participant', {
    title: SUPPORT_TEAM_NAME,
    body,
    type: 'support_ticket',
    data: { ticketId: ticket._id.toString() },
    apartmentId: ticket.apartmentId,
  });
}

/** Full ticket plus, for staff/admin only, the participant's mobile to call them. */
async function detailFor(t, sender) {
  const dto = detailDto(t, sender);
  if (sender.type !== 'participant') {
    const reg = await EventRegistration.findById(t.participantId).select('mobileNumber').lean();
    dto.participantMobile = (reg && reg.mobileNumber) || '';
  }
  return dto;
}

/** Summary for the ticket lists. */
const summaryDto = (t) => {
  const last = t.messages[t.messages.length - 1];
  return {
    id: t._id.toString(),
    participantName: t.participantName || '',
    category: t.category,
    description: t.description,
    status: t.status || 'open',
    closedAt: t.closedAt,
    closedByName: t.closedByName || '',
    messageCount: t.messages.length,
    lastMessage: last ? { senderType: last.senderType, text: last.text } : null,
    lastMessageAt: t.lastMessageAt,
    lastParticipantAt:
      [...t.messages].reverse().find((m) => m.senderType === 'participant')?.createdAt || t.createdAt,
    createdAt: t.createdAt,
  };
};

/** Full ticket; each message is flagged `mine` for the caller. */
/**
 * Full ticket; each message is flagged `mine` for the caller. Participants
 * never see who on the team replied or closed it — just the support team.
 */
const detailDto = (t, sender) => {
  const forParticipant = sender.type === 'participant';
  const summary = summaryDto(t);
  return {
    ...summary,
    closedByName: forParticipant && summary.closedByName ? SUPPORT_TEAM_NAME : summary.closedByName,
    // A closed ticket is read-only for the participant; staff/admin close it.
    canReply: !(forParticipant && t.status === 'closed'),
    canClose: !forParticipant && t.status !== 'closed',
    // The participant edits their own open ticket; they (or any staff/admin) may delete it.
    canEdit: forParticipant && t.status !== 'closed',
    canDelete: true,
    messages: t.messages.map((m) => {
      const fromTeam = m.senderType !== 'participant';
      const mine = String(m.senderId) === String(sender.id);
      return {
        id: m._id.toString(),
        senderType: forParticipant && fromTeam ? 'support' : m.senderType,
        senderName: forParticipant && fromTeam ? SUPPORT_TEAM_NAME : m.senderName || '',
        text: m.text,
        createdAt: m.createdAt,
        edited: !!m.editedAt,
        mine,
        // Only the sender edits a message; a participant can't once the ticket is closed.
        canEdit: mine && !(forParticipant && t.status === 'closed'),
      };
    }),
  };
};

/** Loads a ticket the caller may see: their own (participant) or any on the property. */
async function loadTicket(req, res, sender) {
  const ticket = await SupportTicket.findOne({ _id: req.params.id, apartmentId: req.apartmentId });
  if (
    !ticket ||
    (sender.type === 'participant' && String(ticket.participantId) !== String(req.userId))
  ) {
    res.status(404).json({ success: false, error: 'Ticket not found' });
    return null;
  }
  return ticket;
}

// GET /api/support-tickets — a participant's own tickets, or every ticket for staff/admin.
const listTickets = async (req, res) => {
  try {
    const sender = await currentSender(req);
    if (!sender) return forbidden(res);
    const filter = { apartmentId: req.apartmentId };
    if (sender.type === 'participant') filter.participantId = req.userId;
    const tickets = await SupportTicket.find(filter).sort({ lastMessageAt: -1 });
    const forParticipant = sender.type === 'participant';
    res.json({
      success: true,
      tickets: tickets.map((t) => {
        const dto = summaryDto(t);
        if (forParticipant && dto.closedByName) dto.closedByName = SUPPORT_TEAM_NAME;
        return dto;
      }),
    });
  } catch (error) {
    handleError(res, 'listTickets', error);
  }
};

// POST /api/support-tickets  { category, description } — participants only.
const createTicket = async (req, res) => {
  try {
    const sender = await currentSender(req);
    if (!sender || sender.type !== 'participant') {
      return res.status(403).json({ success: false, error: 'Only participants can raise tickets' });
    }
    const category = String(req.body.category || '').trim();
    const description = String(req.body.description || '').trim();
    if (!SupportTicket.CATEGORIES.includes(category)) {
      return res.status(400).json({ success: false, error: 'Choose a category' });
    }
    if (!description) return res.status(400).json({ success: false, error: 'Describe the problem' });
    if (description.length > MAX_LENGTH) {
      return res
        .status(400)
        .json({ success: false, error: `Description must be under ${MAX_LENGTH} characters` });
    }
    const ticket = await SupportTicket.create({
      apartmentId: req.apartmentId,
      participantId: req.userId,
      participantName: sender.name,
      category,
      description,
      // The description opens the chat.
      messages: [{ senderType: 'participant', senderId: sender.id, senderName: sender.name, text: description }],
      lastMessageAt: new Date(),
    });
    res.status(201).json({ success: true, ticket: await detailFor(ticket, sender) });
    notifyTeam(req.apartmentId, {
      title: `New ticket: ${CATEGORY_LABELS[category]}`,
      body: `${sender.name}: ${preview(description)}`,
      ticketId: ticket._id.toString(),
    }).catch((e) => console.error('ticket push failed:', e.message));
  } catch (error) {
    handleError(res, 'createTicket', error);
  }
};

// GET /api/support-tickets/:id — the ticket with its chat.
const getTicket = async (req, res) => {
  try {
    const sender = await currentSender(req);
    if (!sender) return forbidden(res);
    const ticket = await loadTicket(req, res, sender);
    if (!ticket) return;
    res.json({ success: true, ticket: await detailFor(ticket, sender) });
  } catch (error) {
    handleError(res, 'getTicket', error);
  }
};

// POST /api/support-tickets/:id/messages  { text }
const sendMessage = async (req, res) => {
  try {
    const sender = await currentSender(req);
    if (!sender) return forbidden(res);
    const text = String(req.body.text || '').trim();
    if (!text) return res.status(400).json({ success: false, error: 'Type a message' });
    if (text.length > MAX_LENGTH) {
      return res
        .status(400)
        .json({ success: false, error: `Message must be under ${MAX_LENGTH} characters` });
    }
    const ticket = await loadTicket(req, res, sender);
    if (!ticket) return;
    if (sender.type === 'participant' && ticket.status === 'closed') {
      return res.status(400).json({
        success: false,
        error: 'This ticket is closed. Create a new ticket if you still need help.',
      });
    }
    const now = new Date();
    const updated = await SupportTicket.findByIdAndUpdate(
      ticket._id,
      {
        $push: { messages: { senderType: sender.type, senderId: sender.id, senderName: sender.name, text } },
        lastMessageAt: now,
      },
      { new: true }
    );
    res.status(201).json({ success: true, ticket: await detailFor(updated, sender) });
    const push =
      sender.type === 'participant'
        ? notifyTeam(req.apartmentId, {
            title: `${sender.name} · ${CATEGORY_LABELS[updated.category] || 'Support'}`,
            body: preview(text),
            ticketId: updated._id.toString(),
          })
        : notifyParticipant(updated, preview(text));
    push.catch((e) => console.error('message push failed:', e.message));
  } catch (error) {
    handleError(res, 'sendMessage', error);
  }
};

// POST /api/support-tickets/:id/close — event staff / admin only.
const closeTicket = async (req, res) => {
  try {
    const sender = await currentSender(req);
    if (!sender || sender.type === 'participant') {
      return res
        .status(403)
        .json({ success: false, error: 'Only event staff or admin can close tickets' });
    }
    const ticket = await loadTicket(req, res, sender);
    if (!ticket) return;
    if (ticket.status === 'closed') {
      return res.status(400).json({ success: false, error: 'This ticket is already closed' });
    }
    const updated = await SupportTicket.findByIdAndUpdate(
      ticket._id,
      { status: 'closed', closedAt: new Date(), closedByName: sender.name },
      { new: true }
    );
    res.json({ success: true, ticket: await detailFor(updated, sender) });
    notifyParticipant(
      updated,
      `Your ${CATEGORY_LABELS[updated.category] || 'support'} ticket was closed. Create a new ticket if you still need help.`
    ).catch((e) => console.error('close push failed:', e.message));
  } catch (error) {
    handleError(res, 'closeTicket', error);
  }
};

/** A ticket's opening message: the participant's first message, which mirrors the description. */
const openingMessage = (ticket) => {
  const first = ticket.messages[0];
  return first && first.senderType === 'participant' && String(first.senderId) === String(ticket.participantId)
    ? first
    : null;
};

// PUT /api/support-tickets/:id  { category, description } — the participant who raised it, while open.
const updateTicket = async (req, res) => {
  try {
    const sender = await currentSender(req);
    if (!sender || sender.type !== 'participant') {
      return res.status(403).json({ success: false, error: 'Only the participant can edit this ticket' });
    }
    const ticket = await loadTicket(req, res, sender);
    if (!ticket) return;
    if (ticket.status === 'closed') {
      return res.status(400).json({ success: false, error: 'A closed ticket can no longer be edited' });
    }
    const category = String(req.body.category || '').trim();
    const description = String(req.body.description || '').trim();
    if (!SupportTicket.CATEGORIES.includes(category)) {
      return res.status(400).json({ success: false, error: 'Choose a category' });
    }
    if (!description) return res.status(400).json({ success: false, error: 'Describe the problem' });
    if (description.length > MAX_LENGTH) {
      return res
        .status(400)
        .json({ success: false, error: `Description must be under ${MAX_LENGTH} characters` });
    }
    ticket.category = category;
    if (description !== ticket.description) {
      ticket.description = description;
      // The description is also the chat's opening message.
      const first = openingMessage(ticket);
      if (first) {
        first.text = description;
        first.editedAt = new Date();
      }
    }
    await ticket.save();
    res.json({ success: true, ticket: await detailFor(ticket, sender) });
  } catch (error) {
    handleError(res, 'updateTicket', error);
  }
};

// DELETE /api/support-tickets/:id — the participant who raised it, or any event staff / admin.
const deleteTicket = async (req, res) => {
  try {
    const sender = await currentSender(req);
    if (!sender) return forbidden(res);
    // loadTicket only returns a participant's own tickets.
    const ticket = await loadTicket(req, res, sender);
    if (!ticket) return;
    await ticket.deleteOne();
    res.json({ success: true });
  } catch (error) {
    handleError(res, 'deleteTicket', error);
  }
};

// PUT /api/support-tickets/:id/messages/:messageId  { text } — only the message's sender.
const editMessage = async (req, res) => {
  try {
    const sender = await currentSender(req);
    if (!sender) return forbidden(res);
    const text = String(req.body.text || '').trim();
    if (!text) return res.status(400).json({ success: false, error: 'Type a message' });
    if (text.length > MAX_LENGTH) {
      return res
        .status(400)
        .json({ success: false, error: `Message must be under ${MAX_LENGTH} characters` });
    }
    const ticket = await loadTicket(req, res, sender);
    if (!ticket) return;
    const message = ticket.messages.id(req.params.messageId);
    if (!message) return res.status(404).json({ success: false, error: 'Message not found' });
    if (String(message.senderId) !== String(sender.id)) {
      return res.status(403).json({ success: false, error: 'You can only edit your own messages' });
    }
    if (sender.type === 'participant' && ticket.status === 'closed') {
      return res.status(400).json({ success: false, error: 'This ticket is closed' });
    }
    message.text = text;
    message.editedAt = new Date();
    // Editing the opening message edits the ticket's description too.
    if (openingMessage(ticket) === message) ticket.description = text;
    await ticket.save();
    res.json({ success: true, ticket: await detailFor(ticket, sender) });
  } catch (error) {
    handleError(res, 'editMessage', error);
  }
};

module.exports = {
  listTickets,
  createTicket,
  getTicket,
  sendMessage,
  closeTicket,
  updateTicket,
  deleteTicket,
  editMessage,
};
