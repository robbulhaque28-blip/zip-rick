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
    const fare = await FareService.calculateFare({ distanceMeters: route.distance_meters, durationSeconds: route.duration_seconds });
    let promoDiscount = 0, promoApplied = false;
    if (req.body.promo_code) { const p = await FareService.applyPromo(fare.total_fare, req.body.promo_code); promoDiscount = p.discount; promoApplied = p.promo_applied; }
    return success(res, { ...fare, promo_discount: promoDiscount, promo_applied: promoApplied, final_fare: parseFloat((fare.total_fare - promoDiscount).toFixed(2)), route }, 'Fare estimated');
  }),
  bookRide: asyncHandler(async (req, res) => {
    const customer = await Customer.findOne({ where: { user_id: req.userId } });
    if (!customer) throw new ApiError(404, 'Customer not found');
    const route = await getRoute(req.body.pickup_latitude, req.body.pickup_longitude, req.body.drop_latitude, req.body.drop_longitude);
    const fare = await FareService.calculateFare({ distanceMeters: req.body.route_distance || route.distance_meters, durationSeconds: req.body.route_duration || route.duration_seconds });
    let promoDiscount = 0, promoCodeId = null;
    if (req.body.promo_code) { const p = await FareService.applyPromo(fare.total_fare, req.body.promo_code); promoDiscount = p.discount; promoCodeId = p.promo_code_id; }
    const totalFare = parseFloat((fare.total_fare - promoDiscount).toFixed(2));
    const commissionAmount = parseFloat((totalFare * 0.10).toFixed(2));
    const driverEarnings = parseFloat((totalFare - commissionAmount).toFixed(2));
    const ride = await Ride.create({
      customer_id: customer.id,
      pickup_latitude: req.body.pickup_latitude,
      pickup_longitude: req.body.pickup_longitude,
      pickup_address: req.body.pickup_address,
      pickup_place_id: req.body.pickup_place_id,
      drop_latitude: req.body.drop_latitude,
      drop_longitude: req.body.drop_longitude,
      drop_address: req.body.drop_address,
      drop_place_id: req.body.drop_place_id,
      route_distance: req.body.route_distance || route.distance_meters,
      route_duration: req.body.route_duration || route.duration_seconds,
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
      status: 'pending'
    });
    await RideStatusLog.create({ ride_id: ride.id, previous_status: null, new_status: 'pending', changed_by: 'customer', changed_by_id: req.userId });
    ride.status = 'searching'; await ride.save();
    await RideStatusLog.create({ ride_id: ride.id, previous_status: 'pending', new_status: 'searching', changed_by: 'system' });
    RideMatchingService.startSearch(ride, null, null);
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
    const customer = await Customer.findOne({ where: { user_id: req.userId } });
    if (!customer) return success(res, null, 'No active ride');
    const ride = await Ride.findOne({
      where: { customer_id: customer.id, status: { [Op.in]: ['searching', 'driver_assigned', 'driver_arrived', 'started'] } },
      include: [{ association: 'driver', include: [{ association: 'user', attributes: ['id', 'full_name', 'phone', 'avatar_url'] }, { association: 'vehicle' }] }],
      order: [['created_at', 'DESC']]
    });
    return success(res, { ride }, ride ? 'Active ride' : 'No active ride');
  }),
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
    return paginated(res, rows, count, page, limit, 'Ride history');
  }),
  getSearchingRides: asyncHandler(async (req, res) => {
    const driver = await Driver.findOne({ where: { user_id: req.userId } });
    if (!driver) throw new ApiError(404, 'Driver not found');
    if (!driver.current_latitude || !driver.current_longitude) {
      return success(res, { rides: [] }, 'No location set. Please go online first.');
    }
    const searchingRides = await Ride.findAll({
      where: { status: 'searching' },
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
      if (dist <= 5) {
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
    if (!['pending', 'searching', 'driver_assigned'].includes(ride.status)) throw new ApiError(400, 'Cannot cancel at this stage');
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
