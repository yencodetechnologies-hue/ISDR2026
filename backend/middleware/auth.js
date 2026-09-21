const jwt = require('jsonwebtoken');
const Apartment = require('../models/Apartment');

/**
 * Verifies the Bearer token. Only management (apartment) accounts exist in this
 * backend, so the token's userId is always the property (Apartment) id.
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
      return res.status(401).json({ error: 'Not authorized, account not found' });
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
