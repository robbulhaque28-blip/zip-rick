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
router.post('/book', authenticate, rideController.bookRide);

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


// Get available rides for drivers (searching status)
router.get('/searching/available', authenticate, async (req, res) => {
  try {
    const { Ride } = require('../models');
    const rides = await Ride.findAll({
      where: { status: 'searching', driver_id: null },
      order: [['created_at', 'DESC']],
      limit: 10
    });
    res.json({ success: true, data: rides });
  } catch (e) {
    res.status(500).json({ success: false, error: { message: e.message } });
  }
});

// Driver accepts a ride
router.post('/:id/accept', authenticate, async (req, res) => {
  try {
    const { Ride, Driver, RideStatusLog } = require('../models');
    const driver = await Driver.findOne({ where: { user_id: req.userId } });
    if (!driver) return res.status(404).json({ success: false, error: { message: 'Driver not found' } });
    if (driver.registration_status !== 'approved') {
      return res.status(403).json({ success: false, error: { message: 'Driver not approved yet' } });
    }
    const ride = await Ride.findByPk(req.params.id);
    if (!ride) return res.status(404).json({ success: false, error: { message: 'Ride not found' } });
    if (ride.status !== 'searching') return res.status(400).json({ success: false, error: { message: 'Ride already taken' } });
    
    ride.driver_id = driver.id;
    ride.status = 'driver_assigned';
    ride.driver_assigned_at = new Date();
    await ride.save();
    
    await RideStatusLog.create({
      ride_id: ride.id,
      previous_status: 'searching',
      new_status: 'driver_assigned',
      changed_by: 'driver',
      changed_by_id: req.userId
    });
    
    // Free driver for next ride
    res.json({ success: true, data: { ride }, message: 'Ride accepted' });
  } catch (e) {
    res.status(500).json({ success: false, error: { message: e.message } });
  }
});
module.exports = router;
