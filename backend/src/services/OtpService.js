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

/**
 * Generate a random 6-digit OTP
 */
function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

/**
 * Send OTP via Fast2SMS
 * @param {string} phone - Phone number with country code (e.g., +919999999999)
 */
async function sendOTP(phone) {
  const otp = generateOTP();
  const apiKey = config.sms.fast2smsApiKey;
  
  // Always store OTP regardless of API key
  otpStore.set(phone, { otp, expiresAt: Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000 });
  logger.info(`OTP for ${phone}: ${otp} (expires in ${OTP_EXPIRY_MINUTES} min)`);

  // If no API key configured, just log it (development mode)
  if (!apiKey || apiKey === 'your-fast2sms-api-key') {
    logger.warn(`Fast2SMS API key not configured. OTP ${otp} would be sent to ${phone}`);
    return { message: 'OTP sent (dev mode - check server logs)', otp };
  }

  try {
    // Clean phone number: remove + and any non-digits
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

    logger.info(`Fast2SMS response for ${phone}: ${JSON.stringify(response.data)}`);
    return { message: 'OTP sent successfully', otp: undefined };
  } catch (error) {
    const errorMsg = error.response?.data?.message || error.message;
    logger.error(`Fast2SMS error for ${phone}: ${errorMsg}`);
    throw new Error('Failed to send SMS. Please try again.');
  }
}

/**
 * Verify OTP
 * @param {string} phone - Phone number
 * @param {string} otp - OTP entered by user
 */
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
  
  // OTP verified - remove from store
  otpStore.delete(phone);
  return true;
}

module.exports = { sendOTP, verifyOTP };
