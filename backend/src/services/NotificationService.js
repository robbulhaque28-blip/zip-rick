/**
 * NotificationService
 * Handles push notifications via Firebase Cloud Messaging (FCM),
 * in-app notifications, and notification management.
 */

const { Notification, User } = require('../models');
const logger = require('../utils/logger');

class NotificationService {
  constructor() {
    this.fcmInitialized = false;
  }

  /**
   * Initialize FCM
   */
  _initFCM() {
    if (this.fcmInitialized) return;
    try {
      const admin = require('firebase-admin');
      if (admin.apps.length > 0) {
        this.fcmInitialized = true;
      }
    } catch (error) {
      logger.warn('FCM not available:', error.message);
    }
  }

  /**
   * Send push notification to a user
   */
  async sendPush(userId, title, body, data = {}, type = 'general') {
    this._initFCM();

    try {
      const user = await User.findByPk(userId);
      if (!user || !user.fcm_token) {
        logger.debug(`No FCM token for user ${userId}`);
        return false;
      }

      if (this.fcmInitialized) {
        const admin = require('firebase-admin');
        await admin.messaging().send({
          token: user.fcm_token,
          notification: { title, body },
          data: { ...data, type },
          android: {
            priority: 'high',
            notification: {
              channel_id: 'zip_rick_' + type,
              sound: 'default',
            },
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
              },
            },
          },
        });
      }

      // Also save to in-app notifications
      await this.createInApp(userId, type, title, body, data);

      logger.debug(`Push notification sent to user ${userId}: ${title}`);
      return true;
    } catch (error) {
      logger.error(`Failed to send push to user ${userId}:`, error.message);
      return false;
    }
  }

  /**
   * Send push to multiple users (broadcast)
   */
  async sendBulkPush(userIds, title, body, data = {}, type = 'general') {
    const results = await Promise.allSettled(
      userIds.map((userId) => this.sendPush(userId, title, body, data, type))
    );
    const sent = results.filter((r) => r.status === 'fulfilled' && r.value).length;
    logger.info(`Bulk push: sent ${sent}/${userIds.length} notifications`);
    return { sent, total: userIds.length };
  }

  /**
   * Create in-app notification
   */
  async createInApp(userId, type, title, body, data = null, imageUrl = null, deepLink = null) {
    try {
      const notification = await Notification.create({
        user_id: userId,
        type,
        title,
        body,
        data,
        image_url: imageUrl,
        deep_link: deepLink,
      });
      return notification;
    } catch (error) {
      logger.error('Failed to create in-app notification:', error.message);
      return null;
    }
  }

  /**
   * Get user notifications with pagination
   */
  async getUserNotifications(userId, page = 1, limit = 20) {
    const offset = (page - 1) * limit;
    const { rows, count } = await Notification.findAndCountAll({
      where: { user_id: userId },
      order: [['created_at', 'DESC']],
      offset,
      limit,
    });
    return { notifications: rows, total: count, page, limit, unread_count: rows.filter((n) => !n.is_read).length };
  }

  /**
   * Mark notification as read
   */
  async markAsRead(notificationId, userId) {
    const notification = await Notification.findOne({
      where: { id: notificationId, user_id: userId },
    });
    if (notification) {
      notification.is_read = true;
      notification.read_at = new Date();
      await notification.save();
    }
    return notification;
  }

  /**
   * Mark all notifications as read for a user
   */
  async markAllAsRead(userId) {
    await Notification.update(
      { is_read: true, read_at: new Date() },
      { where: { user_id: userId, is_read: false } }
    );
    return true;
  }

  /**
   * Get unread notification count
   */
  async getUnreadCount(userId) {
    return Notification.count({ where: { user_id: userId, is_read: false } });
  }

  /**
   * Delete a notification
   */
  async deleteNotification(notificationId, userId) {
    await Notification.destroy({ where: { id: notificationId, user_id: userId } });
    return true;
  }

  // ====================
  // Notification Templates
  // ====================

  async notifyRideRequested(driverId, rideData) {
    return this.sendPush(
      driverId,
      'New Ride Request',
      `Pickup: ${rideData.pickup_address?.substring(0, 50)}`,
      { type: 'ride_requested', ride_id: rideData.id, screen: 'ride_request' },
      'ride_request'
    );
  }

  async notifyRideAccepted(customerId, rideData, driverName) {
    return this.sendPush(
      customerId,
      'Ride Accepted',
      `${driverName} is on their way!`,
      { type: 'ride_accepted', ride_id: rideData.id, screen: 'ride_tracking' },
      'ride_accepted'
    );
  }

  async notifyDriverArrived(customerId, rideData) {
    return this.sendPush(
      customerId,
      'Driver Arrived',
      'Your E-Rickshaw driver has arrived at the pickup location.',
      { type: 'driver_arrived', ride_id: rideData.id, screen: 'ride_tracking' },
      'driver_arrived'
    );
  }

  async notifyRideStarted(customerId, rideData) {
    return this.sendPush(
      customerId,
      'Ride Started',
      'Your ride has started. Enjoy your journey!',
      { type: 'ride_started', ride_id: rideData.id, screen: 'ride_tracking' },
      'ride_started'
    );
  }

  async notifyRideCompleted(customerId, rideData) {
    return this.sendPush(
      customerId,
      'Ride Completed',
      `Thank you for riding with Zip-Rick! Please rate your experience.`,
      { type: 'ride_completed', ride_id: rideData.id, screen: 'rate_ride' },
      'ride_completed'
    );
  }

  async notifyDriverApproved(driverId) {
    return this.sendPush(
      driverId,
      'Registration Approved',
      'Congratulations! Your Zip-Rick driver account has been approved. Start earning now!',
      { type: 'driver_approved', screen: 'driver_home' },
      'driver_approved'
    );
  }

  async notifyDriverRejected(driverId, reason) {
    return this.sendPush(
      driverId,
      'Registration Update',
      `Your registration was not approved. Reason: ${reason || 'Please contact support for details.'}`,
      { type: 'driver_rejected', screen: 'driver_registration' },
      'driver_rejected'
    );
  }

  async notifyPaymentSuccess(customerId, rideData, amount) {
    return this.sendPush(
      customerId,
      'Payment Successful',
      `₹${amount} paid successfully for your ride.`,
      { type: 'payment_success', ride_id: rideData.id, screen: 'ride_history' },
      'payment'
    );
  }

  async notifyPromotion(userId, promoTitle, promoBody) {
    return this.sendPush(
      userId,
      promoTitle || 'Special Offer!',
      promoBody || 'Check out our latest promotions.',
      { type: 'promotion', screen: 'promotions' },
      'promotion'
    );
  }
}

module.exports = new NotificationService();
