/**
 * Swagger/OpenAPI Documentation Configuration
 */

const swaggerJsdoc = require('swagger-jsdoc');
const config = require('../config');

const swaggerDefinition = {
  openapi: '3.0.0',
  info: {
    title: 'Vybe API',
    version: '1.0.0',
    description: `
      Vybe Ride-Hailing Platform API
      
      A production-grade ride-hailing platform exclusively for E-Rickshaws.
      
      ## Features
      - OTP Authentication
      - Ride Booking & Matching
      - Live Tracking
      - Payments (Cash & UPI)
      - Driver Management
      - Admin Dashboard
      
      ## Authentication
      Most endpoints require a JWT token in the Authorization header:
      \`\`\`
      Authorization: Bearer <your_jwt_token>
      \`\`\`
    `,
    contact: {
      name: 'Vybe Support',
      email: 'support@vybe.com',
    },
  },
  servers: [
    {
      url: `http://localhost:${config.port}${config.apiPrefix}`,
      description: 'Development server',
    },
    {
      url: 'https://api.vybe.com/v1',
      description: 'Production server',
    },
  ],
  components: {
    securitySchemes: {
      bearerAuth: {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
        description: 'Enter JWT token obtained from /auth/verify-otp',
      },
    },
    schemas: {
      Error: {
        type: 'object',
        properties: {
          success: { type: 'boolean', example: false },
          error: {
            type: 'object',
            properties: {
              code: { type: 'string' },
              message: { type: 'string' },
            },
          },
          timestamp: { type: 'string', format: 'date-time' },
        },
      },
      Ride: {
        type: 'object',
        properties: {
          id: { type: 'string', format: 'uuid' },
          ride_number: { type: 'string' },
          status: { type: 'string', enum: ['pending', 'searching', 'driver_assigned', 'driver_arrived', 'started', 'completed', 'cancelled'] },
          total_fare: { type: 'number' },
          pickup_address: { type: 'string' },
          drop_address: { type: 'string' },
          created_at: { type: 'string', format: 'date-time' },
        },
      },
      FareEstimate: {
        type: 'object',
        properties: {
          base_fare: { type: 'number' },
          distance_fare: { type: 'number' },
          time_fare: { type: 'number' },
          night_charges: { type: 'number' },
          peak_charges: { type: 'number' },
          total_fare: { type: 'number' },
          distance_km: { type: 'number' },
          duration_min: { type: 'number' },
        },
      },
    },
  },
  paths: {
    '/auth/send-otp': {
      post: {
        tags: ['Auth'],
        summary: 'Send OTP to phone number',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['phone'],
                properties: {
                  phone: { type: 'string', example: '+919999999999', description: 'Indian phone number with country code' },
                },
              },
            },
          },
        },
        responses: { '200': { description: 'OTP sent successfully' }, '400': { description: 'Invalid phone number' } },
      },
    },
    '/auth/verify-otp': {
      post: {
        tags: ['Auth'],
        summary: 'Verify OTP and login/register',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['phone', 'otp'],
                properties: {
                  phone: { type: 'string', example: '+919999999999' },
                  otp: { type: 'string', example: '123456' },
                  role: { type: 'string', enum: ['customer', 'driver'], default: 'customer' },
                  full_name: { type: 'string', example: 'John Doe', description: 'Required for new users' },
                },
              },
            },
          },
        },
        responses: {
          '200': { description: 'Login successful' },
          '201': { description: 'Account created' },
          '400': { description: 'Invalid OTP' },
        },
      },
    },
    '/rides/estimate': {
      post: {
        tags: ['Rides'],
        summary: 'Get fare estimate',
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['pickup_latitude', 'pickup_longitude', 'drop_latitude', 'drop_longitude'],
                properties: {
                  pickup_latitude: { type: 'number' },
                  pickup_longitude: { type: 'number' },
                  drop_latitude: { type: 'number' },
                  drop_longitude: { type: 'number' },
                  promo_code: { type: 'string' },
                },
              },
            },
          },
        },
        responses: { '200': { description: 'Fare estimated' } },
      },
    },
    '/rides/book': {
      post: {
        tags: ['Rides'],
        summary: 'Book a new ride',
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['pickup_latitude', 'pickup_longitude', 'pickup_address', 'drop_latitude', 'drop_longitude', 'drop_address', 'route_distance', 'route_duration', 'payment_method'],
                properties: {
                  pickup_latitude: { type: 'number' },
                  pickup_longitude: { type: 'number' },
                  pickup_address: { type: 'string' },
                  drop_latitude: { type: 'number' },
                  drop_longitude: { type: 'number' },
                  drop_address: { type: 'string' },
                  payment_method: { type: 'string', enum: ['cash', 'upi'] },
                  promo_code: { type: 'string' },
                },
              },
            },
          },
        },
        responses: { '201': { description: 'Ride booked' } },
      },
    },
    '/health': {
      get: {
        tags: ['System'],
        summary: 'Health check',
        responses: { '200': { description: 'API is healthy' } },
      },
    },
  },
};

const options = {
  swaggerDefinition,
  apis: ['./src/routes/*.js'],
};

const swaggerSpec = swaggerJsdoc(options);

module.exports = swaggerSpec;
