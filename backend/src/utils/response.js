/**
 * Standard API Response helpers
 */

/**
 * Send success response
 */
function success(res, data = null, message = 'Success', statusCode = 200) {
  return res.status(statusCode).json({
    success: true,
    data,
    message,
    timestamp: new Date().toISOString(),
  });
}

/**
 * Send error response
 */
function error(res, message = 'Internal Server Error', statusCode = 500, code = null, details = null) {
  const response = {
    success: false,
    error: {
      code: code || 'INTERNAL_ERROR',
      message,
    },
    timestamp: new Date().toISOString(),
  };
  if (details && process.env.NODE_ENV !== 'production') {
    response.error.details = details;
  }
  return res.status(statusCode).json(response);
}

/**
 * Send paginated response
 */
function paginated(res, data, total, page, limit, message = 'Success') {
  const totalPages = Math.ceil(total / limit);
  return res.status(200).json({
    success: true,
    data,
    message,
    pagination: {
      total,
      page,
      limit,
      total_pages: totalPages,
      has_next: page < totalPages,
      has_prev: page > 1,
    },
    timestamp: new Date().toISOString(),
  });
}

/**
 * Send created response (201)
 */
function created(res, data = null, message = 'Created successfully') {
  return success(res, data, message, 201);
}

module.exports = { success, error, paginated, created };
