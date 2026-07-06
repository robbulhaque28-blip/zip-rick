/**
 * Global Error Handling Middleware
 * Catches unhandled errors, formats them consistently, and logs them.
 */

const logger = require('../utils/logger');
const config = require('../config');

/**
 * Custom API Error class
 */
class ApiError extends Error {
  constructor(statusCode, message, code = null, details = null) {
    super(message);
    this.statusCode = statusCode;
    this.code = code || 'API_ERROR';
    this.details = details;
    this.isOperational = true;
    Error.captureStackTrace(this, this.constructor);
  }
}

/**
 * 404 handler - Route not found
 */
function notFound(req, res, next) {
  const err = new ApiError(404, `Route ${req.method} ${req.originalUrl} not found`, 'ROUTE_NOT_FOUND');
  next(err);
}

/**
 * Global error handler
 */
function errorHandler(err, req, res, _next) {
  // Log error
  logger.error('Error caught:', {
    message: err.message,
    code: err.code,
    statusCode: err.statusCode || 500,
    path: req.originalUrl,
    method: req.method,
    stack: err.stack,
    ip: req.ip,
  });

  // Determine status code
  const statusCode = err.statusCode || err.status || 500;

  // Build error response
  const errorResponse = {
    success: false,
    error: {
      code: err.code || 'INTERNAL_ERROR',
      message: statusCode === 500 && config.env === 'production'
        ? 'Internal Server Error'
        : err.message,
    },
    timestamp: new Date().toISOString(),
  };

  // Add validation details in non-production
  if (err.details && config.env !== 'production') {
    errorResponse.error.details = err.details;
  }

  // Sequelize validation errors
  if (err.name === 'SequelizeValidationError' || err.name === 'SequelizeUniqueConstraintError') {
    errorResponse.error.code = 'DB_VALIDATION_ERROR';
    errorResponse.error.message = 'Database validation failed';
    errorResponse.error.details = err.errors?.map((e) => ({
      field: e.path,
      message: e.message,
      value: e.value,
    }));
    return res.status(400).json(errorResponse);
  }

  if (err.name === 'SequelizeForeignKeyConstraintError') {
    errorResponse.error.code = 'FK_CONSTRAINT_ERROR';
    errorResponse.error.message = 'Referenced record not found';
    return res.status(400).json(errorResponse);
  }

  // Rate limit error
  if (err.name === 'RateLimitError') {
    errorResponse.error.code = 'RATE_LIMIT_EXCEEDED';
    errorResponse.error.message = 'Too many requests, please try again later';
    return res.status(429).json(errorResponse);
  }

  // Multer errors (file upload)
  if (err.code === 'LIMIT_FILE_SIZE') {
    errorResponse.error.code = 'FILE_TOO_LARGE';
    errorResponse.error.message = 'File size exceeds the maximum limit';
    return res.status(400).json(errorResponse);
  }

  // Send response
  res.status(statusCode).json(errorResponse);
}

/**
 * Wrap async route handlers to catch errors
 */
function asyncHandler(fn) {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

module.exports = {
  ApiError,
  notFound,
  errorHandler,
  asyncHandler,
};
