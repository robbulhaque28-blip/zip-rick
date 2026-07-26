const admin = require('firebase-admin');
const logger = require('../utils/logger');

let initialized = false;
let initError = null;
let activeProjectId = null;

function initializeFirebase() {
  if (initialized) return;

  const privateKey = process.env.FIREBASE_PRIVATE_KEY;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const projectId = process.env.FIREBASE_PROJECT_ID;

  const missing = [];
  if (!projectId) missing.push('FIREBASE_PROJECT_ID');
  if (!clientEmail) missing.push('FIREBASE_CLIENT_EMAIL');
  if (!privateKey) missing.push('FIREBASE_PRIVATE_KEY');

  if (missing.length) {
    initError = 'Missing environment variables: ' + missing.join(', ');
    logger.warn('[PUSH] Firebase NOT configured. Push notifications are disabled. ' + initError);
    return;
  }

  try {
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId,
        clientEmail,
        // Render stores newlines as the two characters \n, so restore them.
        privateKey: privateKey.replace(/\\n/g, '\n'),
      }),
    });
    initialized = true;
    activeProjectId = projectId;
    initError = null;
    logger.info('[PUSH] Firebase initialized. project_id=' + projectId + ' client_email=' + clientEmail);
  } catch (e) {
    initError = e.message;
    logger.error('[PUSH] Firebase init FAILED: ' + e.message);
  }
}

/**
 * Report configuration state without ever exposing the private key.
 * Lets the admin dashboard show exactly why push is or is not working.
 */
function getStatus() {
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL || null;
  return {
    initialized,
    project_id: activeProjectId || process.env.FIREBASE_PROJECT_ID || null,
    client_email: clientEmail,
    private_key_present: !!process.env.FIREBASE_PRIVATE_KEY,
    private_key_looks_valid: !!(process.env.FIREBASE_PRIVATE_KEY || '').includes('BEGIN PRIVATE KEY'),
    error: initError,
  };
}

/**
 * Send a push to one user.
 *
 * Returns a result object rather than a bare boolean so callers can tell the
 * difference between "no token stored", "token belongs to a different
 * Firebase project" and "Firebase is not configured at all". Previously every
 * one of these just returned false and vanished.
 */
async function sendPushDetailed(userId, title, body, data = {}) {
  if (!initialized) {
    return { ok: false, reason: 'not_configured', detail: initError };
  }
  try {
    const { User } = require('../models');
    const user = await User.findByPk(userId, { attributes: ['id', 'fcm_token'] });
    if (!user) return { ok: false, reason: 'no_user' };
    if (!user.fcm_token) return { ok: false, reason: 'no_token' };

    // Firebase requires every data value to be a string.
    const stringData = {};
    for (const k of Object.keys(data || {})) {
      if (data[k] !== undefined && data[k] !== null) stringData[k] = String(data[k]);
    }
    stringData.click_action = 'FLUTTER_NOTIFICATION_CLICK';

    const channelId = stringData.android_channel_id;

    const message = {
      token: user.fcm_token,
      notification: { title, body },
      data: stringData,
      android: {
        priority: 'high',
        notification: channelId
          ? { channelId, priority: 'high', defaultSound: true }
          : { priority: 'high', defaultSound: true },
      },
    };

    const id = await admin.messaging().send(message);
    return { ok: true, messageId: id };
  } catch (e) {
    const code = e.errorInfo?.code || e.code || 'unknown';

    // A token minted by a DIFFERENT Firebase project, or one belonging to an
    // uninstalled app, is permanently dead. Clear it so we stop retrying and
    // so the next app launch registers a fresh, valid one.
    if (
      code === 'messaging/registration-token-not-registered' ||
      code === 'messaging/invalid-registration-token' ||
      code === 'messaging/invalid-argument'
    ) {
      try {
        const { User } = require('../models');
        await User.update({ fcm_token: null }, { where: { id: userId } });
        logger.warn('[PUSH] Cleared dead FCM token for user ' + userId + ' (' + code + ')');
      } catch (clearErr) { /* best effort */ }
      return { ok: false, reason: 'stale_token', detail: code };
    }

    logger.error('[PUSH] send failed for user ' + userId + ': ' + code + ' ' + e.message);
    return { ok: false, reason: 'send_failed', detail: code + ' ' + e.message };
  }
}

// Backwards-compatible boolean wrapper for existing call sites.
async function sendPushNotification(userId, title, body, data = {}) {
  const r = await sendPushDetailed(userId, title, body, data);
  return r.ok;
}

async function sendToTopic(topic, title, body, data = {}) {
  if (!initialized) return false;
  try {
    await admin.messaging().send({ topic, notification: { title, body }, data });
    return true;
  } catch (e) {
    logger.error('[PUSH] Topic notification failed: ' + e.message);
    return false;
  }
}

module.exports = {
  initializeFirebase,
  sendPushNotification,
  sendPushDetailed,
  sendToTopic,
  getStatus,
};
