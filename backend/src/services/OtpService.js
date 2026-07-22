const axios = require('axios');
const logger = require('../utils/logger');
const config = require('../config');

// In-memory OTP store (phone -> { otp, expiresAt })
const otpStore = new Map();
const OTP_EXPIRY_MINUTES = 5;

// Clean up expired OTPs every 5 minutes
setInterval(() => {
  const now = Date.now();
  for (const [phone, data] of otpStore.entries()) {
    if (data.expiresAt < now) otpStore.delete(phone);
  }
}, 5 * 60 * 1000);

function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

async function getApiKey() {
  try {
    const { SystemSetting } = require('../models');
    const s = await SystemSetting.findOne({ where: { key: 'fast2sms_api_key' } });
    if (s && s.value && s.value !== 'your-fast2sms-api-key') return s.value;
  } catch (e) {}
  return config.sms.fast2smsApiKey;
}

async function sendOTP(phone) {
  const otp = generateOTP();
  
  // Always store OTP regardless
  otpStore.set(phone, { otp, expiresAt: Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000 });
  logger.info(`[OTP] ${phone}: ${otp} (expires in ${OTP_EXPIRY_MINUTES} min)`);

  const apiKey = await getApiKey();

  // If no API key configured, return OTP directly (dev mode)
  if (!apiKey || apiKey === 'your-fast2sms-api-key') {
    logger.warn(`[OTP] No Fast2SMS key. Dev mode - returning OTP: ${otp}`);
    return { message: 'Dev mode', otp };
  }

  // Try to send SMS via Fast2SMS
  try {
    const cleanPhone = phone.replace(/[^0-9]/g, '');
    
    const response = await axios.post('https://www.fast2sms.com/dev/bulkV2', {
      route: 'otp',
      numbers: cleanPhone,
      flash: 0,
      variables_values: otp,
    }, {
      headers: {
        'authorization': apiKey,
        'Content-Type': 'application/json'
      },
      timeout: 10000,
    });

    const result = response.data;
    logger.info(`[OTP] Fast2SMS response: ${JSON.stringify(result)}`);

    // Fast2SMS returns { return: true/false }
    if (result.return === true || result.return === 'true') {
      return { message: 'OTP sent successfully' };
    } else {
      // Fast2SMS failed - fall back to dev mode
      logger.warn(`[OTP] Fast2SMS failed: ${result.message || 'Unknown error'}. Falling back to dev mode.`);
      return { message: 'Dev mode (SMS failed - check logs for OTP)', otp };
    }
  } catch (error) {
    const errorMsg = error.response?.data?.message || error.message;
    logger.error(`[OTP] Fast2SMS error: ${errorMsg}. Falling back to dev mode.`);
    // Fallback: return OTP directly so user can still login
    return { message: 'Dev mode (SMS failed - check logs for OTP)', otp };
  }
}

function verifyOTP(phone, otp) {
  const stored = otpStore.get(phone);
  
  if (!stored) {
    throw new Error('OTP not found or expired. Please request a new OTP.');
  }
  
  if (Date.now() > stored.expiresAt) {
    otpStore.delete(phone);
    throw new Error('OTP has expired. Please request a new OTP.');
  }
  
  if (stored.otp !== otp) {
    throw new Error('Invalid OTP. Please try again.');
  }
  
  otpStore.delete(phone);
  return true;
}

module.exports = { sendOTP, verifyOTP };
