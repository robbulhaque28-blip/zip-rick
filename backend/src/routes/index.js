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
      service: 'vybe-api',
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

// Support tickets for customers and drivers
const { SupportTicket, SupportTicketMessage } = require('../models');
const { authenticate } = require('../middleware/auth');

router.post('/support/tickets', authenticate, async (req, res) => {
  try {
    const ticket = await SupportTicket.create({
      user_id: req.userId,
      subject: req.body.subject || 'Support Request',
      description: req.body.description || '',
      priority: req.body.priority || 'medium',
    });
    if (req.body.message) {
      await SupportTicketMessage.create({
        ticket_id: ticket.id,
        sender_id: req.userId,
        sender_role: req.userRole,
        message: req.body.message,
      });
    }
    res.json({ success: true, data: { ticket } });
  } catch (e) {
    res.status(500).json({ success: false, error: { message: e.message } });
  }
});

router.get('/support/tickets', authenticate, async (req, res) => {
  try {
    const tickets = await SupportTicket.findAll({
      where: { user_id: req.userId },
      include: [{ association: 'messages', order: [['created_at', 'DESC']] }],
      order: [['created_at', 'DESC']],
    });
    res.json({ success: true, data: tickets });
  } catch (e) {
    res.status(500).json({ success: false, error: { message: e.message } });
  }
});

router.post('/support/tickets/:id/messages', authenticate, async (req, res) => {
  try {
    const ticket = await SupportTicket.findOne({ where: { id: req.params.id, user_id: req.userId } });
    if (!ticket) return res.status(404).json({ success: false, error: { message: 'Ticket not found' } });
    const msg = await SupportTicketMessage.create({
      ticket_id: ticket.id,
      sender_id: req.userId,
      sender_role: req.userRole,
      message: req.body.message,
    });
    ticket.status = 'open';
    await ticket.save();
    res.json({ success: true, data: { message: msg } });
  } catch (e) {
    res.status(500).json({ success: false, error: { message: e.message } });
  }
});

// SOS emergency endpoint
router.post('/sos', authenticate, async (req, res) => {
  try {
    const emergencyTicket = await SupportTicket.create({
      user_id: req.userId,
      subject: '🚨 SOS EMERGENCY',
      description: req.body.description || 'Emergency help requested',
      priority: 'urgent',
      status: 'open',
    });
    // Notify admin via socket if available
    const { getIO } = require('../sockets');
    const io = getIO();
    if (io) {
      io.to('role:admin').emit('sos:alert', {
        ticket_id: emergencyTicket.id,
        user_id: req.userId,
        location: req.body.location || null,
        timestamp: new Date(),
      });
    }
    res.json({ success: true, data: { ticket: emergencyTicket }, message: 'SOS alert sent. Help is on the way!' });
  } catch (e) {
    res.status(500).json({ success: false, error: { message: e.message } });
  }
});
// Referral system
const { Referral, Customer, User } = require('../models');

router.get('/referral/code', authenticate, async (req, res) => {
  try {
    const customer = await Customer.findOne({ where: { user_id: req.userId } });
    if (!customer) return res.status(404).json({ success: false, error: { message: 'Customer not found' } });
    res.json({ success: true, data: { referral_code: customer.referral_code, loyalty_points: customer.loyalty_points } });
  } catch (e) {
    res.status(500).json({ success: false, error: { message: e.message } });
  }
});

router.post('/referral/apply', authenticate, async (req, res) => {
  try {
    const { code } = req.body;
    if (!code) return res.status(400).json({ success: false, error: { message: 'Referral code required' } });

    const referrer = await Customer.findOne({ where: { referral_code: code.toUpperCase() } });
    if (!referrer) return res.status(404).json({ success: false, error: { message: 'Invalid referral code' } });

    const customer = await Customer.findOne({ where: { user_id: req.userId } });
    if (!customer) return res.status(404).json({ success: false, error: { message: 'Customer not found' } });
    if (customer.referred_by) return res.status(400).json({ success: false, error: { message: 'Already referred' } });
    if (referrer.id === customer.id) return res.status(400).json({ success: false, error: { message: 'Cannot refer yourself' } });

    customer.referred_by = referrer.id;
    customer.loyalty_points = (customer.loyalty_points || 0) + 50;
    await customer.save();

    referrer.loyalty_points = (referrer.loyalty_points || 0) + 100;
    await referrer.save();

    await Referral.create({
      referrer_id: referrer.id,
      referred_id: customer.id,
      reward_amount: 100,
      status: 'completed',
    });

    res.json({ success: true, message: 'Referral applied! You earned 50 points.', data: { loyalty_points: customer.loyalty_points } });
  } catch (e) {
    res.status(500).json({ success: false, error: { message: e.message } });
  }
});

router.get('/referral/stats', authenticate, async (req, res) => {
  try {
    const customer = await Customer.findOne({ where: { user_id: req.userId } });
    if (!customer) return res.status(404).json({ success: false, error: { message: 'Customer not found' } });
    const count = await Referral.count({ where: { referrer_id: customer.id, status: 'completed' } });
    res.json({ success: true, data: { referral_code: customer.referral_code, total_referrals: count, loyalty_points: customer.loyalty_points } });
  } catch (e) {
    res.status(500).json({ success: false, error: { message: e.message } });
  }
});

// Emergency Contacts
router.get('/emergency-contacts', authenticate, async (req, res) => {
  try {
    const EmergencyContact = require('../models').EmergencyContact;
    const contacts = await EmergencyContact.findAll({ where: { user_id: req.userId } });
    res.json({ success: true, data: contacts });
  } catch (e) {
    res.status(500).json({ success: false, error: { message: e.message } });
  }
});

router.post('/emergency-contacts', authenticate, async (req, res) => {
  try {
    const EmergencyContact = require('../models').EmergencyContact;
    const contact = await EmergencyContact.create({
      user_id: req.userId,
      name: req.body.name,
      phone: req.body.phone,
      relation: req.body.relation || '',
    });
    res.json({ success: true, data: contact });
  } catch (e) {
    res.status(500).json({ success: false, error: { message: e.message } });
  }
});

router.delete('/emergency-contacts/:id', authenticate, async (req, res) => {
  try {
    const EmergencyContact = require('../models').EmergencyContact;
    await EmergencyContact.destroy({ where: { id: req.params.id, user_id: req.userId } });
    res.json({ success: true, message: 'Deleted' });
  } catch (e) {
    res.status(500).json({ success: false, error: { message: e.message } });
  }
});
module.exports = router;