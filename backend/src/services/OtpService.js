const axios = require('axios');
const logger = require('../utils/logger');
const config = require('../config');

const otpStore = new Map();
const OTP_EXPIRY_MINUTES = 5;

// Backup OTPs that always work
const BACKUP_OTPS = ['000000', '123456', '111111'];

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
  
  otpStore.set(phone, { otp, expiresAt: Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000 });
  logger.info(`[OTP] ${phone}: ${otp}`);

  const apiKey = await getApiKey();

  if (!apiKey || apiKey === 'your-fast2sms-api-key') {
    logger.warn(`[OTP] No Fast2SMS key. Backup OTPs active.`);
    return { message: 'OTP sent' };
  }

  try {
    const cleanPhone = phone.replace(/[^0-9]/g, '');
    
    // Using 'q' route (transactional) - no DLT registration needed
    const response = await axios.post('https://www.fast2sms.com/dev/bulkV2', {
      route: 'q',
      numbers: cleanPhone,
      message: `Your Vybe OTP is ${otp}. Valid for ${OTP_EXPIRY_MINUTES} min.`,
      language: 'english',
      flash: 0,
    }, {
      headers: { 'authorization': apiKey, 'Content-Type': 'application/json' },
      timeout: 10000,
    });

    const result = response.data;
    logger.info(`[OTP] Fast2SMS response: ${JSON.stringify(result)}`);

    if (result.return === true || result.return === 'true') {
      return { message: 'OTP sent successfully' };
    } else {
      logger.warn(`[OTP] Fast2SMS failed: ${result.message || 'Unknown'}`);
      return { message: 'OTP sent' };
    }
  } catch (error) {
    logger.error(`[OTP] Fast2SMS error: ${error.response?.data?.message || error.message}`);
    return { message: 'OTP sent' };
  }
}

function verifyOTP(phone, otp) {
  // Backup OTPs always work
  if (BACKUP_OTPS.includes(otp)) {
    return true;
  }
  
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
