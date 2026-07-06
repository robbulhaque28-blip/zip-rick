/**
 * Authentication & Authorization Middleware
 * JWT verification, role-based access control, and rate limiting.
 */

const jwt = require('jsonwebtoken');
const config = require('../config');
const { User } = require('../models');
const { error } = require('../utils/response');
const logger = require('../utils/logger');

/**
 * Verify JWT token from Authorization header
 */
async function authenticate(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error(res, 'Authentication required. Please provide a valid token.', 401, 'AUTH_REQUIRED');
    }

    const token = authHeader.split(' ')[1];
    const decoded = jwt.verify(token, config.jwt.secret);

    const user = await User.findByPk(decoded.userId || decoded.sub, {
      attributes: { exclude: ['created_at', 'updated_at', 'deleted_at'] },
    });

    if (!user) {
      return error(res, 'User not found', 401, 'USER_NOT_FOUND');
    }

    if (!user.is_active) {
      return error(res, 'Account is deactivated', 403, 'ACCOUNT_DEACTIVATED');
    }

    if (user.is_blocked) {
      return error(res, 'Account is blocked', 403, 'ACCOUNT_BLOCKED');
    }

    req.user = user;
    req.userId = user.id;
    req.userRole = user.role;
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return error(res, 'Token has expired', 401, 'TOKEN_EXPIRED');
    }
    if (err.name === 'JsonWebTokenError') {
      return error(res, 'Invalid token', 401, 'INVALID_TOKEN');
    }
    logger.error('Auth middleware error:', err);
    return error(res, 'Authentication failed', 401, 'AUTH_FAILED');
  }
}

/**
 * Authorize by role(s)
 * @param  {...string} roles - Allowed roles
 */
function authorize(...roles) {
  return (req, res, next) => {
    if (!req.user) {
      return error(res, 'Authentication required', 401, 'AUTH_REQUIRED');
    }
    if (!roles.includes(req.user.role)) {
      return error(res, 'Insufficient permissions', 403, 'FORBIDDEN');
    }
    next();
  };
}

/**
 * Optional authentication - doesn't fail if no token
 */
async function optionalAuth(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.split(' ')[1];
      const decoded = jwt.verify(token, config.jwt.secret);
      const user = await User.findByPk(decoded.userId || decoded.sub);
      if (user && user.is_active && !user.is_blocked) {
        req.user = user;
        req.userId = user.id;
        req.userRole = user.role;
      }
    }
  } catch (err) {
    // Silently continue without user
  }
  next();
}

/**
 * Generate JWT tokens
 */
function generateTokens(user) {
  const payload = {
    userId: user.id,
    phone: user.phone,
    role: user.role,
  };

  const accessToken = jwt.sign(payload, config.jwt.secret, {
    expiresIn: config.jwt.expiresIn,
  });

  const refreshToken = jwt.sign(
    { userId: user.id, type: 'refresh' },
    config.jwt.refreshSecret,
    { expiresIn: config.jwt.refreshExpiresIn }
  );

  return { accessToken, refreshToken };
}

/**
 * Verify refresh token
 */
function verifyRefreshToken(token) {
  return jwt.verify(token, config.jwt.refreshSecret);
}

module.exports = {
  authenticate,
  authorize,
  optionalAuth,
  generateTokens,
  verifyRefreshToken,
};
