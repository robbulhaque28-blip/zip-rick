/**
 * Ride Routes
 * Fare estimation, booking, tracking, history, cancellation, rating.
 */

const router = require('express').Router();
const rideController = require('../controllers/RideController');
const { authenticate, authorize } = require('../middleware/auth');
const { validate, schemas } = require('../middleware/validate');

// All ride routes require authentication
router.use(authenticate);

/**
 * @swagger
 * /rides/estimate:
 *   post:
 *     tags: [Rides]
 *     summary: Get fare estimate
 */
router.post('/estimate', rideController.getFareEstimate);

/**
 * @swagger
 * /rides/book:
 *   post:
 *     tags: [Rides]
 *     summary: Book a new ride
 */
router.post('/book', validate({ body: schemas.rideBooking }), rideController.bookRide);

/**
 * @swagger
 * /rides/active:
 *   get:
 *     tags: [Rides]
 *     summary: Get customer's active ride
 */
router.get('/active', rideController.getActiveRide);

/**
 * @swagger
 * /rides/history:
 *   get:
 *     tags: [Rides]
 *     summary: Get ride history with pagination
 */
router.get('/history', rideController.getRideHistory);

/**
 * @swagger
 * /rides/{id}:
 *   get:
 *     tags: [Rides]
 *     summary: Get ride details
 */
router.get('/:id', rideController.getRideDetails);

/**
 * @swagger
 * /rides/{id}/cancel:
 *   post:
 *     tags: [Rides]
 *     summary: Cancel a ride
 */
router.post('/:id/cancel', rideController.cancelRide);

/**
 * @swagger
 * /rides/{id}/rate:
 *   post:
 *     tags: [Rides]
 *     summary: Rate a completed ride
 */
router.post('/:id/rate', rideController.rateRide);

module.exports = router;
