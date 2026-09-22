const jwt = require('jsonwebtoken');
const Apartment = require('../models/Apartment');
const EventStaff = require('../models/EventStaff');
const EventRegistration = require('../models/EventRegistration');

/**
 * Verifies the Bearer token. The token's userId is the property (Apartment) id for a
 * management login, an event staff account id, or a participant (EventRegistration) id.
 */
const protect = async (req, res, next) => {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer')) {
    return res.status(401).json({ error: 'Not authorized, no token' });
  }

  try {
    const token = header.split(' ')[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    const apartment = await Apartment.findById(decoded.userId).lean();
    if (!apartment) {
      const staff = await EventStaff.findById(decoded.userId).lean();
      if (staff) {
        if (!staff.isActive || staff.status !== 'approved') {
          return res.status(401).json({ error: 'Not authorized, account not found' });
        }
        req.userId = decoded.userId;
        req.userType = 'user';
        req.apartmentId = staff.apartmentId.toString();
        return next();
      }
      const participant = await EventRegistration.findById(decoded.userId).lean();
      if (!participant || participant.status === 'cancelled') {
        return res.status(401).json({ error: 'Not authorized, account not found' });
      }
      req.userId = decoded.userId;
      req.userType = 'participant';
      req.apartmentId = participant.apartmentId.toString();
      return next();
    }

    req.userId = decoded.userId;
    req.userType = 'apartment';
    req.apartmentId = apartment._id.toString();
    req.loginRole = decoded.loginRole || null;
    req.loginMobile = decoded.loginMobile || null;
    next();
  } catch (error) {
    res.status(401).json({ error: 'Not authorized, token failed' });
  }
};

/** Management account must be active to use management routes. */
const requireManagement = async (req, res, next) => {
  try {
    const apartment = await Apartment.findById(req.userId);
    if (!apartment) {
      return res.status(403).json({
        success: false,
        error: 'Not authorized. Only management accounts can perform this action.',
      });
    }
    if (!apartment.isActive) {
      return res.status(403).json({
        success: false,
        error: 'Not authorized. Apartment account is inactive.',
      });
    }
    req.apartmentId = apartment._id.toString();
    next();
  } catch (error) {
    console.error('Management authorization error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Server error during authorization',
    });
  }
};

module.exports = { protect, requireManagement };
