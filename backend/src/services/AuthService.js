/**
 * AuthService
 * Handles OTP verification, JWT token management, Firebase integration.
 */

const admin = require('firebase-admin');
const config = require('../config');
const { User, Customer, Driver, AdminUser, Wallet } = require('../models');
const { generateTokens, verifyRefreshToken } = require('../middleware/auth');
const { ApiError } = require('../middleware/errorHandler');
const logger = require('../utils/logger');

let firebaseInitialized = false;

/**
 * Initialize Firebase Admin SDK
 */
function initializeFirebase() {
  if (firebaseInitialized) return;
  try {
    if (config.firebase.projectId && config.firebase.privateKey) {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId: config.firebase.projectId,
          privateKey: config.firebase.privateKey.replace(/\\n/g, '\n'),
          clientEmail: config.firebase.clientEmail,
        }),
      });
      firebaseInitialized = true;
      logger.info('Firebase Admin SDK initialized successfully');
    } else {
      logger.warn('Firebase credentials not configured. OTP verification disabled.');
    }
  } catch (error) {
    logger.error('Failed to initialize Firebase:', error.message);
  }
}

class AuthService {
  /**
   * Send OTP to phone number
   */
  async sendOTP(phone) {
    try {
      initializeFirebase();
      if (firebaseInitialized) {
        // In production, use Firebase Auth to send OTP
        // For now, we simulate (real implementation uses Firebase client SDK)
        logger.info(`OTP sent to ${phone}`);
      }
      return { message: 'OTP sent successfully', phone };
    } catch (error) {
      logger.error('Send OTP error:', error);
      throw new ApiError(500, 'Failed to send OTP', 'OTP_SEND_FAILED');
    }
  }

  /**
   * Verify OTP and create/login user
   */
  async verifyOTP(phone, otp, role = 'customer', fullName = null) {
    try {
      initializeFirebase();

      // In production, verify with Firebase Admin SDK
      // For now, accept any 6-digit OTP in development
      if (config.env === 'production' && firebaseInitialized) {
        // const decoded = await admin.auth().verifyIdToken(idToken);
        // phone = decoded.phone_number;
        throw new ApiError(501, 'Production OTP verification not implemented in this context', 'OTP_VERIFY_NOT_IMPLEMENTED');
      }

      // Development OTP verification
      if (otp.length !== 6) {
        throw new ApiError(400, 'Invalid OTP format', 'INVALID_OTP');
      }

      // Find or create user
      let user = await User.findOne({ where: { phone } });

      if (!user) {
        if (!fullName) {
          throw new ApiError(400, 'Full name is required for new users', 'NAME_REQUIRED');
        }
        user = await User.create({
          phone,
          full_name: fullName,
          role,
          is_phone_verified: true,
        });

        // Create role-specific profile
        if (role === 'customer') {
          await Customer.create({ user_id: user.id });
        } else if (role === 'driver') {
          await Driver.create({
            user_id: user.id,
            registration_status: 'pending',
          });
        }

        // Create wallet
        await Wallet.create({ user_id: user.id });
      } else {
        if (!user.is_phone_verified) {
          user.is_phone_verified = true;
        }
        user.last_login_at = new Date();
        await user.save();

        // Ensure role-specific profile exists
        if (role === 'customer') {
          const customer = await Customer.findOne({ where: { user_id: user.id } });
          if (!customer) await Customer.create({ user_id: user.id });
        } else if (role === 'driver') {
          const driver = await Driver.findOne({ where: { user_id: user.id } });
          if (!driver) {
            await Driver.create({ user_id: user.id, registration_status: 'pending' });
          }
        }

        // Ensure wallet exists
        const wallet = await Wallet.findOne({ where: { user_id: user.id } });
        if (!wallet) await Wallet.create({ user_id: user.id });
      }

      // Generate tokens
      const tokens = generateTokens(user);

      // Update FCM token if provided
      // if (fcmToken) { user.fcm_token = fcmToken; await user.save(); }

      // Get profile based on role
      let profile = null;
      if (role === 'customer') {
        profile = await Customer.findOne({ where: { user_id: user.id } });
      } else if (role === 'driver') {
        profile = await Driver.findOne({ where: { user_id: user.id } });
      }

      logger.info(`User ${user.id} (${role}) logged in via OTP`);

      return {
        user: user.getSafeProfile(),
        profile,
        tokens,
        is_new_user: !user.last_login_at || user.created_at.getTime() === user.updated_at.getTime(),
      };
    } catch (error) {
      if (error instanceof ApiError) throw error;
      logger.error('Verify OTP error:', error);
      throw new ApiError(500, 'Failed to verify OTP', 'OTP_VERIFY_FAILED');
    }
  }

  /**
   * Refresh access token
   */
  async refreshToken(refreshToken) {
    try {
      const decoded = verifyRefreshToken(refreshToken);
      const user = await User.findByPk(decoded.userId);

      if (!user || !user.is_active || user.is_blocked) {
        throw new ApiError(401, 'Invalid refresh token', 'INVALID_REFRESH_TOKEN');
      }

      const tokens = generateTokens(user);
      return tokens;
    } catch (error) {
      if (error instanceof ApiError) throw error;
      throw new ApiError(401, 'Invalid or expired refresh token', 'REFRESH_TOKEN_EXPIRED');
    }
  }

  /**
   * Update user profile
   */
  async updateProfile(userId, updateData) {
    const allowedFields = ['full_name', 'email', 'avatar_url'];
    const updates = {};
    
    for (const field of allowedFields) {
      if (updateData[field] !== undefined) {
        updates[field] = updateData[field];
      }
    }

    if (Object.keys(updates).length === 0) {
      throw new ApiError(400, 'No valid fields to update', 'NO_UPDATES');
    }

    const user = await User.findByPk(userId);
    if (!user) {
      throw new ApiError(404, 'User not found', 'USER_NOT_FOUND');
    }

    await user.update(updates);
    return user.getSafeProfile();
  }

  /**
   * Admin login
   */
  async adminLogin(email, password) {
    const adminUser = await AdminUser.findOne({
      where: { email },
      include: [{ association: 'user' }],
    });

    if (!adminUser || !adminUser.is_active) {
      throw new ApiError(401, 'Invalid credentials', 'INVALID_CREDENTIALS');
    }

    const bcrypt = require('bcryptjs');
    const isPasswordValid = await bcrypt.compare(password, adminUser.password_hash);

    if (!isPasswordValid) {
      throw new ApiError(401, 'Invalid credentials', 'INVALID_CREDENTIALS');
    }

    adminUser.last_login_at = new Date();
    await adminUser.save();

    const tokens = generateTokens(adminUser.user);

    return {
      admin: {
        id: adminUser.id,
        email: adminUser.email,
        role: adminUser.role,
        permissions: adminUser.permissions,
        user: adminUser.user?.getSafeProfile(),
      },
      tokens,
    };
  }
}

module.exports = new AuthService();
