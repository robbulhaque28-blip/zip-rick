/**
 * Routes Index
 * Aggregates all API routes under a single router.
 */
const router = require('express').Router();
const config = require('../config');

// Import route modules
const authRoutes = require('./auth');
const rideRoutes = require('./rides');
const driverRoutes = require('./drivers');
const customerRoutes = require('./customers');
const paymentRoutes = require('./payments');
const mapRoutes = require('./maps');
const adminRoutes = require('./admin');
const webhookRoutes = require('./webhooks');

// Health check
router.get('/health', (req, res) => {
  res.json({
    success: true,
    data: {
      service: 'zip-rick-api',
      version: '1.0.0',
      environment: config.env,
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
    },
    message: 'API is healthy',
  });
});

// Mount routes
router.use('/auth', authRoutes);
router.use('/rides', rideRoutes);
router.use('/drivers', driverRoutes);
router.use('/customers', customerRoutes);
router.use('/payments', paymentRoutes);
router.use('/maps', mapRoutes);
router.use('/admin', adminRoutes);
router.use('/webhooks', webhookRoutes);

module.exports = router;