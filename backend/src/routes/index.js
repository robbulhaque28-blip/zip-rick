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

// Setup endpoint - run once to seed admin user (protected by key)
router.get('/setup', async (req, res) => {
  const setupKey = req.query.key;
  if (setupKey !== 'ziprick2026') {
    return res.status(404).json({ success: false, message: 'Not found' });
  }
  try {
    const { sequelize } = require('../config/db');
    const bcrypt = require('bcryptjs');
    const { v4: uuidv4 } = require('uuid');

    await sequelize.sync({ force: false });

    const password = await bcrypt.hash('Admin@123', 10);
    const userId = uuidv4();
    const adminId = uuidv4();

    await sequelize.query(
      `INSERT INTO users (id, phone, full_name, role, is_phone_verified, created_at, updated_at)
       VALUES ('${userId}', '7000000000', 'Super Admin', 'admin', true, NOW(), NOW())
       ON CONFLICT (phone) DO NOTHING;`
    );

    const user = await sequelize.query(
      `SELECT id FROM users WHERE phone = '7000000000' LIMIT 1;`,
      { type: sequelize.QueryTypes.SELECT }
    );

    if (user && user.length > 0) {
      const existingAdmin = await sequelize.query(
        `SELECT id FROM admin_users WHERE user_id = '${user[0].id}' LIMIT 1;`,
        { type: sequelize.QueryTypes.SELECT }
      );

      if (!existingAdmin || existingAdmin.length === 0) {
        await sequelize.query(
          `INSERT INTO admin_users (id, user_id, email, password_hash, role, permissions, is_active, created_at, updated_at)
           VALUES ('${adminId}', '${user[0].id}', 'admin@ziprick.com', '${password}', 'super_admin', '{"all": true}', true, NOW(), NOW());`
        );
        res.json({ success: true, message: 'Database synced and admin created!' });
      } else {
        res.json({ success: true, message: 'Database synced. Admin already exists.' });
      }
    } else {
      res.json({ success: false, message: 'Failed to find user.' });
    }
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;