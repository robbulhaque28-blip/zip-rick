const admin = require('firebase-admin');
const config = require('../config');
const logger = require('../utils/logger');

let initialized = false;

function initializeFirebase() {
  if (initialized) return;
  
  const privateKey = process.env.FIREBASE_PRIVATE_KEY;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const projectId = process.env.FIREBASE_PROJECT_ID;

  if (!privateKey || !clientEmail || !projectId) {
    logger.warn('Firebase not configured. Push notifications disabled.');
    return;
  }

  try {
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId,
        clientEmail,
        privateKey: privateKey.replace(/\\n/g, '\n'),
      }),
    });
    initialized = true;
    logger.info('Firebase initialized successfully');
  } catch (e) {
    logger.error('Firebase init failed:', e.message);
  }
}

async function sendPushNotification(userId, title, body, data = {}) {
  if (!initialized) return false;
  try {
    const { User } = require('../models');
    const user = await User.findByPk(userId, { attributes: ['fcm_token'] });
    if (!user || !user.fcm_token) return false;

    const message = {
      token: user.fcm_token,
      notification: { title, body },
      data: { ...data, click_action: 'FLUTTER_NOTIFICATION_CLICK' },
    };

    await admin.messaging().send(message);
    return true;
  } catch (e) {
    logger.error('Push notification failed:', e.message);
    return false;
  }
}

async function sendToTopic(topic, title, body, data = {}) {
  if (!initialized) return false;
  try {
    const message = {
      topic,
      notification: { title, body },
      data,
    };
    await admin.messaging().send(message);
    return true;
  } catch (e) {
    logger.error('Topic notification failed:', e.message);
    return false;
  }
}

module.exports = { initializeFirebase, sendPushNotification, sendToTopic };