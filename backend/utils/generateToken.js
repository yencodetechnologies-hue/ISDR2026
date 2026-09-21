const jwt = require('jsonwebtoken');

const generateToken = (userId, apartmentId = null, extra = {}) => {
  const payload = { userId, ...(extra && typeof extra === 'object' ? extra : {}) };
  if (apartmentId) {
    payload.apartmentId = apartmentId.toString();
  }
  return jwt.sign(payload, process.env.JWT_SECRET, {
    expiresIn: '7d',
  });
};

module.exports = generateToken;
