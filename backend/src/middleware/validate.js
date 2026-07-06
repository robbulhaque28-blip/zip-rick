/**
 * Request Validation Middleware
 * Uses Joi schemas for validating request body, params, and query.
 */

const Joi = require('joi');
const { error } = require('../utils/response');
const logger = require('../utils/logger');

/**
 * Validate request against a Joi schema
 * @param {Object} schema - Joi schema with optional body, params, query keys
 */
function validate(schema) {
  return (req, res, next) => {
    const validationOptions = {
      abortEarly: false,
      allowUnknown: true,
      stripUnknown: true,
    };

    const errors = [];

    if (schema.body) {
      const { error: bodyError, value } = schema.body.validate(req.body, validationOptions);
      if (bodyError) {
        errors.push(...bodyError.details.map((d) => ({
          field: d.path.join('.'),
          message: d.message.replace(/"/g, ''),
        })));
      } else {
        req.body = value;
      }
    }

    if (schema.params) {
      const { error: paramsError, value } = schema.params.validate(req.params, validationOptions);
      if (paramsError) {
        errors.push(...paramsError.details.map((d) => ({
          field: d.path.join('.'),
          message: d.message.replace(/"/g, ''),
        })));
      } else {
        req.params = value;
      }
    }

    if (schema.query) {
      const { error: queryError, value } = schema.query.validate(req.query, validationOptions);
      if (queryError) {
        errors.push(...queryError.details.map((d) => ({
          field: d.path.join('.'),
          message: d.message.replace(/"/g, ''),
        })));
      } else {
        req.query = value;
      }
    }

    if (errors.length > 0) {
      logger.warn('Validation failed', { path: req.path, errors });
      return error(res, 'Validation failed', 400, 'VALIDATION_ERROR', errors);
    }

    next();
  };
}

/**
 * Common validation schemas
 */
const schemas = {
  pagination: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(100).default(20),
    sort: Joi.string().default('created_at'),
    order: Joi.string().valid('ASC', 'DESC').default('DESC'),
  }),

  phone: Joi.object({
    phone: Joi.string()
      .pattern(/^\+?[1-9]\d{9,14}$/)
      .required()
      .messages({
        'string.pattern.base': 'Phone number must be 10-15 digits with optional country code',
        'any.required': 'Phone number is required',
      }),
  }),

  otp: Joi.object({
    phone: Joi.string()
      .pattern(/^\+?[1-9]\d{9,14}$/)
      .required(),
    otp: Joi.string().length(6).required(),
  }),

  location: Joi.object({
    latitude: Joi.number().min(-90).max(90).required(),
    longitude: Joi.number().min(-180).max(180).required(),
    address: Joi.string().required(),
    place_id: Joi.string().allow('', null),
  }),

  rideBooking: Joi.object({
    pickup_latitude: Joi.number().min(-90).max(90).required(),
    pickup_longitude: Joi.number().min(-180).max(180).required(),
    pickup_address: Joi.string().required(),
    pickup_place_id: Joi.string().allow('', null),
    drop_latitude: Joi.number().min(-90).max(90).required(),
    drop_longitude: Joi.number().min(-180).max(180).required(),
    drop_address: Joi.string().required(),
    drop_place_id: Joi.string().allow('', null),
    route_distance: Joi.number().min(0).required(),
    route_duration: Joi.number().min(0).required(),
    route_polyline: Joi.string().allow('', null),
    payment_method: Joi.string().valid('cash', 'upi').required(),
    promo_code: Joi.string().allow('', null).max(50),
  }),

  uuid: Joi.string().uuid().required(),
};

module.exports = { validate, schemas };
