/**
 * AuthController
 * Handles OTP authentication, user registration, token refresh.
 */

const authService = require('../services/AuthService');
const { success, created, error } = require('../utils/response');
const { asyncHandler } = require('../middleware/errorHandler');

class AuthController {
  /**
   * POST /api/v1/auth/send-otp
   * Send OTP to phone number
   */
  sendOTP = asyncHandler(async (req, res) => {
    const { phone } = req.body;
    const result = await authService.sendOTP(phone);
    return success(res, result, 'OTP sent successfully');
  });

  /**
   * POST /api/v1/auth/verify-otp
   * Verify OTP and login/register
   */
  verifyOTP = asyncHandler(async (req, res) => {
    const { phone, otp, role, full_name } = req.body;
    const result = await authService.verifyOTP(phone, otp, role || 'customer', full_name);
    return success(res, result, result.is_new_user ? 'Account created successfully' : 'Login successful');
  });

  /**
   * POST /api/v1/auth/refresh
   * Refresh access token
   */
  refreshToken = asyncHandler(async (req, res) => {
    const { refresh_token } = req.body;
    if (!refresh_token) {
      return error(res, 'Refresh token is required', 400, 'REFRESH_TOKEN_REQUIRED');
    }
    const tokens = await authService.refreshToken(refresh_token);
    return success(res, tokens, 'Token refreshed successfully');
  });

  /**
   * PUT /api/v1/auth/profile
   * Update user profile
   */
  updateProfile = asyncHandler(async (req, res) => {
    const profile = await authService.updateProfile(req.userId, req.body);
    return success(res, profile, 'Profile updated successfully');
  });

  /**
   * GET /api/v1/auth/me
   * Get current user profile
   */
  getProfile = asyncHandler(async (req, res) => {
    const { User, Customer, Driver } = require('../models');
    const user = await User.findByPk(req.userId);

    let profile = null;
    if (req.userRole === 'customer') {
      profile = await Customer.findOne({
        where: { user_id: req.userId },
        include: [{ association: 'savedPlaces' }],
      });
    } else if (req.userRole === 'driver') {
      profile = await Driver.findOne({
        where: { user_id: req.userId },
        include: [
          { association: 'documents' },
          { association: 'vehicle' },
        ],
      });
    }

    return success(res, { user: user.getSafeProfile(), profile }, 'Profile fetched successfully');
  });

  /**
   * POST /api/v1/auth/update-fcm
   * Update FCM push notification token
   */
  updateFCMToken = asyncHandler(async (req, res) => {
    const { fcm_token } = req.body;
    const { User } = require('../models');
    await User.update({ fcm_token }, { where: { id: req.userId } });
    return success(res, null, 'FCM token updated');
  });

  /**
   * POST /api/v1/auth/admin/login
   * Admin login
   */
  adminLogin = asyncHandler(async (req, res) => {
    const { email, password } = req.body;
    const result = await authService.adminLogin(email, password);
    return success(res, result, 'Admin login successful');
  });
}

module.exports = new AuthController();
