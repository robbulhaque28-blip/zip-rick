/**
 * Razorpay & external webhooks
 */
const router = require('express').Router();
const crypto = require('crypto');
const config = require('../config');
const { asyncHandler } = require('../middleware/errorHandler');
const { success } = require('../utils/response');
const logger = require('../utils/logger');

router.post('/razorpay', asyncHandler(async (req, res) => {
  const signature = req.headers['x-razorpay-signature'];
  const expected = crypto.createHmac('sha256', config.razorpay.keySecret).update(JSON.stringify(req.body)).digest('hex');
  if (signature !== expected && config.env === 'production') return res.status(400).json({ status: 'invalid' });
  logger.info(`Razorpay webhook: ${req.body.event}`);
  return success(res, null, 'Webhook received');
}));

module.exports = router;
