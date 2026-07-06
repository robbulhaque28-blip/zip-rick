/**
 * Auth Routes
 * OTP authentication, profile management, admin login.
 */

const router = require('express').Router();
const authController = require('../controllers/AuthController');
const { authenticate, authorize } = require('../middleware/auth');
const { validate, schemas } = require('../middleware/validate');
const rateLimit = require('express-rate-limit');

// Rate limiters
const authLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 30,
  message: { success: false, error: { code: 'RATE_LIMIT', message: 'Too many requests' } },
});

/**
 * @swagger
 * /auth/send-otp:
 *   post:
 *     tags: [Auth]
 *     summary: Send OTP to phone number
 */
router.post('/send-otp', authLimiter, validate({ body: schemas.phone }), authController.sendOTP);

/**
 * @swagger
 * /auth/verify-otp:
 *   post:
 *     tags: [Auth]
 *     summary: Verify OTP and login/register
 */
router.post('/verify-otp', authLimiter, validate({ body: schemas.otp }), authController.verifyOTP);

/**
 * @swagger
 * /auth/refresh:
 *   post:
 *     tags: [Auth]
 *     summary: Refresh access token
 */
router.post('/refresh', authController.refreshToken);

/**
 * @swagger
 * /auth/me:
 *   get:
 *     tags: [Auth]
 *     summary: Get current user profile
 */
router.get('/me', authenticate, authController.getProfile);

/**
 * @swagger
 * /auth/profile:
 *   put:
 *     tags: [Auth]
 *     summary: Update user profile
 */
router.put('/profile', authenticate, authController.updateProfile);

/**
 * @swagger
 * /auth/update-fcm:
 *   post:
 *     tags: [Auth]
 *     summary: Update FCM token
 */
router.post('/update-fcm', authenticate, authController.updateFCMToken);

/**
 * Admin auth routes
 */
router.post('/admin/login', authLimiter, authController.adminLogin);

module.exports = router;
