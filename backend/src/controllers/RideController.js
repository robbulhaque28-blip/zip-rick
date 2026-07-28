const { Op } = require('sequelize');
const { Ride, Customer, Driver, RideStatusLog, RatingReview } = require('../models');
const FareService = require('../services/FareService');
const GoogleMapsService = require('../services/GoogleMapsService');
const RideMatchingService = require('../services/RideMatchingService');
const NotificationService = require('../services/NotificationService');
const { success, error, paginated, created } = require('../utils/response');
const { asyncHandler, ApiError } = require('../middleware/errorHandler');
const logger = require('../utils/logger');

// Haversine fallback when Google Maps API is unavailable
function haversineRoute(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat/2)**2 + Math.cos(lat1*Math.PI/180) * Math.cos(lat2*Math.PI/180) * Math.sin(dLng/2)**2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  const km = R * c;
  return {
    distance_meters: parseFloat((km * 1000).toFixed(2)),
    duration_seconds: Math.ceil(km * 180), // ~20 km/h average
    polyline: '',
    distance_text: `${km.toFixed(1)} km`,
    duration_text: `${Math.ceil(km * 3)} mins`,
  };
}

async function getRoute(pickup_lat, pickup_lng, drop_lat, drop_lng) {
  try {
    const route = await GoogleMapsService.getDirections(pickup_lat, pickup_lng, drop_lat, drop_lng);
    return route;
  } catch (err) {
    logger.warn(`Google Maps API failed, using Haversine fallback: ${err.message}`);
    return haversineRoute(pickup_lat, pickup_lng, drop_lat, drop_lng);
  }
}

module.exports = {
  getFareEstimate: asyncHandler(async (req, res) => {
    const route = await getRoute(req.body.pickup_latitude, req.body.pickup_longitude, req.body.drop_latitude, req.body.drop_longitude);
    const rideMode = req.body.ride_mode || 'single';
    const fare = await FareService.calculateFare({ distanceMeters: route.distance_meters, durationSeconds: route.duration_seconds, ride_mode: rideMode });
    let promoDiscount = 0, promoApplied = false;
    if (req.body.promo_code) { const p = await FareService.applyPromo(fare.total_fare, req.body.promo_code); promoDiscount = p.discount; promoApplied = p.promo_applied; }
    return success(res, { ...fare, promo_discount: promoDiscount, promo_applied: promoApplied, final_fare: parseFloat((fare.total_fare - promoDiscount).toFixed(2)), route }, 'Fare estimated');
  }),
  bookRide: asyncHandler(async (req, res) => {
    const customer = await Customer.findOne({ where: { user_id: req.userId } });
    if (!customer) throw new ApiError(404, 'Customer not found');

    // Validate the request BEFORE touching routing or fares. Previously an
    // out-of-range latitude or an unknown payment method fell through to a
    // raw 500, and a booking whose pickup equalled its drop was accepted.
    const pLat = parseFloat(req.body.pickup_latitude);
    const pLng = parseFloat(req.body.pickup_longitude);
    const dLat = parseFloat(req.body.drop_latitude);
    const dLng = parseFloat(req.body.drop_longitude);

    const validCoord = (la, lo) =>
      Number.isFinite(la) && Number.isFinite(lo) &&
      la >= -90 && la <= 90 && lo >= -180 && lo <= 180 &&
      !(la === 0 && lo === 0);

    if (!validCoord(pLat, pLng)) throw new ApiError(400, 'Please choose a valid pickup location');
    if (!validCoord(dLat, dLng)) throw new ApiError(400, 'Please choose a valid drop location');

    // Reject a trip that goes nowhere (~11 m at this latitude).
    if (Math.abs(pLat - dLat) < 0.0001 && Math.abs(pLng - dLng) < 0.0001) {
      throw new ApiError(400, 'Pickup and drop cannot be the same place');
    }

    const allowedPayments = ['cash', 'upi', 'card', 'wallet'];
    const paymentMethod = (req.body.payment_method || 'cash').toString().toLowerCase();
    if (!allowedPayments.includes(paymentMethod)) {
      throw new ApiError(400, 'Unsupported payment method');
    }
    req.body.payment_method = paymentMethod;

    const allowedModes = ['single', 'sharing'];
    if (req.body.ride_mode && !allowedModes.includes(req.body.ride_mode)) {
      throw new ApiError(400, 'Unsupported ride type');
    }

    const route = await getRoute(pLat, pLng, dLat, dLng);
    const rideMode = req.body.ride_mode || 'single';
    // Always use the server-calculated route. Trusting req.body.route_distance
    // let the app send a hardcoded 5000m, so the booked fare did not match the estimate.
    const fare = await FareService.calculateFare({ distanceMeters: route.distance_meters, durationSeconds: route.duration_seconds, ride_mode: rideMode });
    let promoDiscount = 0, promoCodeId = null;
    if (req.body.promo_code) { const p = await FareService.applyPromo(fare.total_fare, req.body.promo_code); promoDiscount = p.discount; promoCodeId = p.promo_code_id; }
    const totalFare = parseFloat((fare.total_fare - promoDiscount).toFixed(2));
    const commissionAmount = parseFloat((totalFare * 0.10).toFixed(2));
    const driverEarnings = parseFloat((totalFare - commissionAmount).toFixed(2));
    const ride = await Ride.create({
      customer_id: customer.id,
      pickup_latitude: pLat,
      pickup_longitude: pLng,
      pickup_address: req.body.pickup_address,
      pickup_place_id: req.body.pickup_place_id,
      drop_latitude: dLat,
      drop_longitude: dLng,
      drop_address: req.body.drop_address,
      drop_place_id: req.body.drop_place_id,
      route_distance: route.distance_meters,
      route_duration: route.duration_seconds,
      route_polyline: req.body.route_polyline || route.polyline,
      base_fare: fare.base_fare,
      distance_fare: fare.distance_fare,
      time_fare: fare.time_fare,
      night_charges: fare.night_charges,
      peak_charges: fare.peak_charges,
      promo_discount: promoDiscount,
      total_fare: totalFare,
      commission_amount: commissionAmount,
      driver_earnings: driverEarnings,
      payment_method: req.body.payment_method,
      scheduled_at: req.body.scheduled_at || null,
      status: 'pending'
    });
    await RideStatusLog.create({ ride_id: ride.id, previous_status: null, new_status: 'pending', changed_by: 'customer', changed_by_id: req.userId });
    
    // Check if this is a scheduled ride
    const isScheduled = req.body.scheduled_at && new Date(req.body.scheduled_at) > new Date();
    ride.ride_otp = String(Math.floor(1000 + Math.random() * 9000));
    if (isScheduled) {
      ride.status = 'scheduled';
      await ride.save();
      await RideStatusLog.create({ ride_id: ride.id, previous_status: 'pending', new_status: 'scheduled', changed_by: 'customer' });
      logger.info('Ride ' + ride.ride_number + ' scheduled for ' + req.body.scheduled_at);
    } else {
      ride.status = 'searching';
      await ride.save();
      await RideStatusLog.create({ ride_id: ride.id, previous_status: 'pending', new_status: 'searching', changed_by: 'system' });
      RideMatchingService.startSearch(ride, null, null);
    }
    if (promoCodeId) { const { PromoRedemption, PromoCode } = require('../models'); await PromoRedemption.create({ promo_code_id: promoCodeId, user_id: req.userId, ride_id: ride.id, discount_amount: promoDiscount }); await PromoCode.increment('usage_count', { where: { id: promoCodeId } }); }
    logger.info(`Ride ${ride.ride_number} booked`);
    return created(res, {
      ride: {
        id: ride.id,
        ride_number: ride.ride_number,
        status: ride.status,
        total_fare: ride.total_fare,
        pickup_address: ride.pickup_address,
        drop_address: ride.drop_address,
        created_at: ride.created_at
      },
      fare_breakdown: {
        base_fare: ride.base_fare,
        distance_fare: ride.distance_fare,
        time_fare: ride.time_fare,
        night_charges: ride.night_charges,
        peak_charges: ride.peak_charges,
        promo_discount: ride.promo_discount,
        total_fare: ride.total_fare
      },
      route: {
        distance_meters: route.distance_meters,
        duration_seconds: route.duration_seconds,
        polyline: route.polyline
      }
    }, 'Ride booked');
  }),
  getActiveRide: asyncHandler(async (req, res) => {
    const ACTIVE = ['searching', 'driver_assigned', 'driver_arrived', 'started'];
    const includeBoth = [
      { association: 'driver', include: [{ association: 'user', attributes: ['id', 'full_name', 'phone', 'avatar_url'] }, { association: 'vehicle' }] },
      { association: 'customer', include: [{ association: 'user', attributes: ['id', 'full_name', 'phone', 'avatar_url'] }] },
    ];

    // Driver: return the ride currently assigned to them.
    const driver = await Driver.findOne({ where: { user_id: req.userId } });
    if (driver) {
      const ride = await Ride.findOne({
        where: { driver_id: driver.id, status: { [Op.in]: ['driver_assigned', 'driver_arrived', 'started'] } },
        include: includeBoth,
        order: [['created_at', 'DESC']]
      });
      return success(res, { ride }, ride ? 'Active ride' : 'No active ride');
    }

    // Customer: return their own in-progress ride.
    const customer = await Customer.findOne({ where: { user_id: req.userId } });
    if (!customer) return success(res, { ride: null }, 'No active ride');
    const ride = await Ride.findOne({
      where: { customer_id: customer.id, status: { [Op.in]: ACTIVE } },
      include: includeBoth,
      order: [['created_at', 'DESC']]
    });
    return success(res, { ride }, ride ? 'Active ride' : 'No active ride');
  }),
  // Confirm the signed-in user is actually part of this ride.
  // Without this, ANY logged-in user could read or cancel ANY ride just by
  // knowing its id - exposing both parties' names, the driver's phone number,
  // pickup/drop addresses and the ride OTP.
  _assertRideParticipant: async (ride, req) => {
    if (req.userRole === 'admin') return;
    const customer = await Customer.findOne({ where: { user_id: req.userId } });
    if (customer && ride.customer_id === customer.id) return;
    const driver = await Driver.findOne({ where: { user_id: req.userId } });
    if (driver && ride.driver_id === driver.id) return;
    // Same 404 as a missing ride, so ids cannot be probed for existence.
    throw new ApiError(404, 'Ride not found');
  },

  getRideDetails: asyncHandler(async (req, res) => {
    const ride = await Ride.findByPk(req.params.id, {
      include: [
        { association: 'customer', include: [{ association: 'user', attributes: ['id', 'full_name'] }] },
        { association: 'driver', include: [{ association: 'user', attributes: ['id', 'full_name', 'phone', 'avatar_url'] }, { association: 'vehicle' }] },
        { association: 'payment' },
        { association: 'rating' },
        { association: 'statusLogs' }
      ]
    });
    if (!ride) throw new ApiError(404, 'Ride not found');
    await module.exports._assertRideParticipant(ride, req);
    return success(res, { ride }, 'Ride details');
  }),
  getRideHistory: asyncHandler(async (req, res) => {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    let where = {};
    if (req.userRole === 'customer') {
      const c = await Customer.findOne({ where: { user_id: req.userId } });
      if (c) where.customer_id = c.id;
    } else if (req.userRole === 'driver') {
      const d = await Driver.findOne({ where: { user_id: req.userId } });
      if (d) where.driver_id = d.id;
    }
    const { rows, count } = await Ride.findAndCountAll({
      where,
      include: [{ association: 'driver', include: [{ association: 'user', attributes: ['full_name', 'avatar_url'] }] }, { association: 'rating' }],
      order: [['created_at', 'DESC']],
      offset: (page - 1) * limit,
      limit
    });
    return success(res, { rides: rows, total: count }, 'Ride history');
  }),
  getSearchingRides: asyncHandler(async (req, res) => {
    const driver = await Driver.findOne({ where: { user_id: req.userId } });
    if (!driver) throw new ApiError(404, 'Driver not found');
    if (!driver.current_latitude || !driver.current_longitude) {
      return success(res, { rides: [] }, 'No location set. Please go online first.');
    }
    // Only offer rides requested in the last 5 minutes. Without this, a ride
    // stuck in 'searching' is re-offered forever with its original fare.
    const cutoff = new Date(Date.now() - 5 * 60 * 1000);
    const searchingRides = await Ride.findAll({
      where: { status: 'searching', created_at: { [Op.gte]: cutoff } },
      order: [['created_at', 'DESC']],
      limit: 20,
    });
    const R = 6371;
    const driverLat = parseFloat(driver.current_latitude);
    const driverLng = parseFloat(driver.current_longitude);
    const nearbyRides = [];
    for (const ride of searchingRides) {
      const dLat = (parseFloat(ride.pickup_latitude) - driverLat) * Math.PI / 180;
      const dLng = (parseFloat(ride.pickup_longitude) - driverLng) * Math.PI / 180;
      const a = Math.sin(dLat/2)**2 + Math.cos(driverLat*Math.PI/180) * Math.cos(parseFloat(ride.pickup_latitude)*Math.PI/180) * Math.sin(dLng/2)**2;
      const dist = R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
      if (dist <= 2) {
        nearbyRides.push({
          id: ride.id,
          ride_number: ride.ride_number,
          pickup_address: ride.pickup_address,
          pickup_latitude: ride.pickup_latitude,
          pickup_longitude: ride.pickup_longitude,
          drop_address: ride.drop_address,
          drop_latitude: ride.drop_latitude,
          drop_longitude: ride.drop_longitude,
          total_fare: ride.total_fare,
          distance_km: parseFloat(dist.toFixed(1)),
          route_distance: ride.route_distance,
          route_duration: ride.route_duration,
          payment_method: ride.payment_method,
          created_at: ride.created_at,
        });
      }
    }
    return success(res, { rides: nearbyRides }, 'Available rides');
  }),
  cancelRide: asyncHandler(async (req, res) => {
    const ride = await Ride.findByPk(req.params.id);
    if (!ride) throw new ApiError(404, 'Ride not found');
    await module.exports._assertRideParticipant(ride, req);
    if (!['pending', 'searching', 'driver_assigned', 'scheduled', 'no_driver_found', 'driver_arrived'].includes(ride.status)) throw new ApiError(400, 'Cannot cancel at this stage');
    const oldStatus = ride.status;
    ride.status = 'cancelled';
    ride.cancellation_reason = req.body.reason || 'User cancelled';
    ride.cancelled_by = req.userRole === 'customer' ? 'customer' : req.userRole === 'driver' ? 'driver' : 'system';
    ride.cancelled_at = new Date();
    await ride.save();
    await RideStatusLog.create({ ride_id: ride.id, previous_status: oldStatus, new_status: 'cancelled', changed_by: ride.cancelled_by, changed_by_id: req.userId });
    RideMatchingService.cancelSearch(ride.id);
    // Notify drivers that ride was cancelled
    const { getIO } = require('../sockets');
    const io = getIO();
    if (io && ride.driver_id) {
      const driver = await Driver.findByPk(ride.driver_id);
      if (driver) {
        io.to(`user:${driver.user_id}`).emit('ride:cancelled', { ride_id: ride.id, reason: ride.cancellation_reason });
        await Driver.update({ is_available: true, current_ride_id: null }, { where: { id: ride.driver_id } });
      }
    } else if (ride.driver_id) {
      await Driver.update({ is_available: true, current_ride_id: null }, { where: { id: ride.driver_id } });
    }
    return success(res, { ride }, 'Ride cancelled');
  }),
  verifyOtp: asyncHandler(async (req, res) => {
    const ride = await Ride.findByPk(req.params.id);
    if (!ride) throw new ApiError(404, 'Ride not found');
    if (ride.status !== 'driver_arrived') throw new ApiError(400, 'Driver has not arrived yet');

    // The driver submits the OTP that the customer reads out to them.
    const driver = await Driver.findOne({ where: { user_id: req.userId } });
    if (!driver || ride.driver_id !== driver.id) throw new ApiError(403, 'Not your ride');

    const otp = String(req.body.otp || '').trim();
    if (!ride.ride_otp || otp !== ride.ride_otp) throw new ApiError(400, 'Invalid OTP');

    ride.status = 'started';
    ride.ride_started_at = new Date();
    await ride.save();
    await RideStatusLog.create({ ride_id: ride.id, previous_status: 'driver_arrived', new_status: 'started', changed_by: 'driver', changed_by_id: req.userId });

    try {
      const { getIO } = require('../sockets');
      const io = getIO();
      if (io) {
        const customer = await ride.getCustomer({ include: [{ association: 'user', attributes: ['id'] }] });
        if (customer?.user?.id) io.to('user:' + customer.user.id).emit('ride:started', { ride_id: ride.id });
        io.to('user:' + req.userId).emit('ride:status_updated', { ride_id: ride.id, status: 'started' });
      }
    } catch (e) { logger.error('verifyOtp socket emit failed: ' + e.message); }

    return success(res, { ride }, 'OTP verified, ride started');
  }),
  rateRide: asyncHandler(async (req, res) => {
    const ride = await Ride.findByPk(req.params.id);
    if (!ride) throw new ApiError(404, 'Ride not found');
    if (ride.status !== 'completed') throw new ApiError(400, 'Can only rate completed rides');
    const customer = await Customer.findOne({ where: { user_id: req.userId } });
    if (ride.customer_id !== customer.id) throw new ApiError(403, 'Not your ride');
    const existing = await RatingReview.findOne({ where: { ride_id: ride.id } });
    if (existing) throw new ApiError(400, 'Already rated');
    const rating = Math.min(5, Math.max(1, req.body.rating));
    const review = await RatingReview.create({ ride_id: ride.id, customer_id: ride.customer_id, driver_id: ride.driver_id, rating, review: req.body.review, customer_comment: req.body.review });
    const driver = await Driver.findByPk(ride.driver_id);
    if (driver) {
      driver.rating_sum = (driver.rating_sum || 0) + rating;
      driver.total_ratings = (driver.total_ratings || 0) + 1;
      driver.rating_avg = parseFloat((driver.rating_sum / driver.total_ratings).toFixed(1));
      await driver.save();
    }
    customer.rating = parseFloat((((customer.rating || 0) * (customer.rating_count || 0) + rating) / ((customer.rating_count || 0) + 1)).toFixed(1));
    customer.rating_count = (customer.rating_count || 0) + 1;
    await customer.save();
    return created(res, { rating: review }, 'Rating submitted');
  }),
};
