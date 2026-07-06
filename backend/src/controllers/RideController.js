/**
 * RideController
 * Handles ride booking, fare estimation, ride lifecycle management,
 * and ride history.
 */

const { Op } = require('sequelize');
const { Ride, Customer, Driver, RideStatusLog, Payment, RatingReview, ChatMessage } = require('../models');
const FareService = require('../services/FareService');
const GoogleMapsService = require('../services/GoogleMapsService');
const RideMatchingService = require('../services/RideMatchingService');
const PaymentService = require('../services/PaymentService');
const NotificationService = require('../services/NotificationService');
const { success, error, paginated, created } = require('../utils/response');
const { asyncHandler, ApiError } = require('../middleware/errorHandler');
const logger = require('../utils/logger');

class RideController {
  /**
   * POST /api/v1/rides/estimate
   * Get fare estimate before booking
   */
  getFareEstimate = asyncHandler(async (req, res) => {
    const { pickup_latitude, pickup_longitude, drop_latitude, drop_longitude, promo_code } = req.body;

    // Get route from Google Maps
    const route = await GoogleMapsService.getDirections(
      pickup_latitude, pickup_longitude,
      drop_latitude, drop_longitude
    );

    // Calculate fare
    const fare = await FareService.calculateFare({
      distanceMeters: route.distance_meters,
      durationSeconds: route.duration_seconds,
    });

    let promoDiscount = 0;
    let promoApplied = false;

    // Apply promo if provided
    if (promo_code) {
      const promoResult = await FareService.applyPromo(fare.total_fare, promo_code);
      if (promoResult.promo_applied) {
        promoDiscount = promoResult.discount;
        promoApplied = true;
      }
    }

    const finalFare = parseFloat((fare.total_fare - promoDiscount).toFixed(2));

    return success(res, {
      ...fare,
      promo_discount: promoDiscount,
      promo_applied: promoApplied,
      final_fare: finalFare,
      pickup: { latitude: pickup_latitude, longitude: pickup_longitude },
      drop: { latitude: drop_latitude, longitude: drop_longitude },
      route: {
        distance_meters: route.distance_meters,
        distance_text: route.distance_text,
        duration_seconds: route.duration_seconds,
        duration_text: route.duration_text,
        polyline: route.polyline,
      },
    }, 'Fare estimated successfully');
  });

  /**
   * POST /api/v1/rides/book
   * Book a new ride
   */
  bookRide = asyncHandler(async (req, res) => {
    const {
      pickup_latitude, pickup_longitude, pickup_address, pickup_place_id,
      drop_latitude, drop_longitude, drop_address, drop_place_id,
      route_distance, route_duration, route_polyline,
      payment_method, promo_code,
    } = req.body;

    // Get customer
    const customer = await Customer.findOne({ where: { user_id: req.userId } });
    if (!customer) {
      throw new ApiError(404, 'Customer profile not found', 'CUSTOMER_NOT_FOUND');
    }

    // Get route from Maps
    const route = await GoogleMapsService.getDirections(
      pickup_latitude, pickup_longitude,
      drop_latitude, drop_longitude
    );

    // Calculate fare
    const fare = await FareService.calculateFare({
      distanceMeters: route_distance || route.distance_meters,
      durationSeconds: route_duration || route.duration_seconds,
    });

    let promoDiscount = 0;
    let promoCodeId = null;

    // Apply promo code
    if (promo_code) {
      const promoResult = await FareService.applyPromo(fare.total_fare, promo_code);
      if (promoResult.promo_applied) {
        promoDiscount = promoResult.discount;
        promoCodeId = promoResult.promo_code_id;
      }
    }

    const totalFare = parseFloat((fare.total_fare - promoDiscount).toFixed(2));
    const commissionRate = 10;
    const commissionAmount = parseFloat((totalFare * commissionRate / 100).toFixed(2));
    const driverEarnings = parseFloat((totalFare - commissionAmount).toFixed(2));

    // Create ride
    const ride = await Ride.create({
      customer_id: customer.id,
      pickup_latitude, pickup_longitude, pickup_address, pickup_place_id,
      drop_latitude, drop_longitude, drop_address, drop_place_id,
      route_distance: route_distance || route.distance_meters,
      route_duration: route_duration || route.duration_seconds,
      route_polyline: route_polyline || route.polyline,
      base_fare: fare.base_fare,
      distance_fare: fare.distance_fare,
      time_fare: fare.time_fare,
      night_charges: fare.night_charges,
      peak_charges: fare.peak_charges,
      promo_discount: promoDiscount,
      total_fare: totalFare,
      commission_amount: commissionAmount,
      driver_earnings: driverEarnings,
      payment_method,
      status: 'pending',
    });

    // Log status
    await RideStatusLog.create({
      ride_id: ride.id,
      previous_status: null,
      new_status: 'pending',
      changed_by: 'customer',
      changed_by_id: req.userId,
    });

    // Record promo redemption
    if (promoCodeId) {
      const { PromoRedemption, PromoCode } = require('../models');
      await PromoRedemption.create({
        promo_code_id: promoCodeId,
        user_id: req.userId,
        ride_id: ride.id,
        discount_amount: promoDiscount,
      });
      await PromoCode.increment('usage_count', { where: { id: promoCodeId } });
    }

    // Start driver search
    ride.status = 'searching';
    await ride.save();

    await RideStatusLog.create({
      ride_id: ride.id,
      previous_status: 'pending',
      new_status: 'searching',
      changed_by: 'system',
    });

    // Emit socket event for driver matching (handled by socket layer)
    // Start ride matching in background
    RideMatchingService.startSearch(
      ride,
      async (acceptedRide, driver) => {
        // Driver found - emit to customer
        const io = req.app.get('io');
        if (io) {
          io.to(`customer:${customer.id}`).emit('ride:accepted', {
            ride_id: ride.id,
            driver: driver,
          });
        }
      },
      async (noDriverRide) => {
        const io = req.app.get('io');
        if (io) {
          io.to(`customer:${customer.id}`).emit('ride:no_drivers', {
            ride_id: ride.id,
            message: 'No drivers available. Please try again.',
          });
        }
      }
    );

    logger.info(`Ride ${ride.ride_number} booked by customer ${customer.id}`);

    return created(res, {
      ride: {
        id: ride.id,
        ride_number: ride.ride_number,
        status: ride.status,
        total_fare: ride.total_fare,
        base_fare: ride.base_fare,
        promo_discount: ride.promo_discount,
        pickup_address: ride.pickup_address,
        drop_address: ride.drop_address,
        created_at: ride.created_at,
      },
      fare_breakdown: {
        base_fare: ride.base_fare,
        distance_fare: ride.distance_fare,
        time_fare: ride.time_fare,
        night_charges: ride.night_charges,
        peak_charges: ride.peak_charges,
        promo_discount: ride.promo_discount,
        total_fare: ride.total_fare,
        commission: ride.commission_amount,
        driver_earnings: ride.driver_earnings,
      },
      route: {
        distance_meters: route.distance_meters,
        distance_text: route.distance_text,
        duration_seconds: route.duration_seconds,
        duration_text: route.duration_text,
        polyline: route_polyline || route.polyline,
      },
    }, 'Ride booked successfully');
  });

  /**
   * GET /api/v1/rides/active
   * Get customer's active ride
   */
  getActiveRide = asyncHandler(async (req, res) => {
    const customer = await Customer.findOne({ where: { user_id: req.userId } });

    const ride = await Ride.findOne({
      where: {
        customer_id: customer.id,
        status: { [Op.in]: ['searching', 'driver_assigned', 'driver_arrived', 'started'] },
      },
      include: [
        {
          association: 'driver',
          include: [
            { association: 'user', attributes: ['id', 'full_name', 'phone', 'avatar_url'] },
            { association: 'vehicle' },
          ],
        },
        { association: 'statusLogs', order: [['created_at', 'DESC']] },
      ],
      order: [['created_at', 'DESC']],
    });

    if (!ride) {
      return success(res, null, 'No active ride found');
    }

    return success(res, { ride }, 'Active ride fetched');
  });

  /**
   * GET /api/v1/rides/:id
   * Get ride details
   */
  getRideDetails = asyncHandler(async (req, res) => {
    const ride = await Ride.findByPk(req.params.id, {
      include: [
        {
          association: 'customer',
          include: [{ association: 'user', attributes: ['id', 'full_name', 'phone', 'avatar_url'] }],
        },
        {
          association: 'driver',
          include: [
            { association: 'user', attributes: ['id', 'full_name', 'phone', 'avatar_url'] },
            { association: 'vehicle' },
          ],
        },
        { association: 'payment' },
        { association: 'rating' },
        { association: 'statusLogs', order: [['created_at', 'ASC']] },
      ],
    });

    if (!ride) {
      throw new ApiError(404, 'Ride not found', 'RIDE_NOT_FOUND');
    }

    // Check authorization
    const customer = await Customer.findOne({ where: { user_id: req.userId } });
    const driver = await Driver.findOne({ where: { user_id: req.userId } });

    if (
      req.userRole === 'customer' && ride.customer_id !== customer?.id ||
      req.userRole === 'driver' && ride.driver_id !== driver?.id
    ) {
      if (req.userRole !== 'admin') {
        throw new ApiError(403, 'Access denied', 'FORBIDDEN');
      }
    }

    return success(res, { ride }, 'Ride details fetched');
  });

  /**
   * GET /api/v1/rides/history
   * Get ride history with pagination
   */
  getRideHistory = asyncHandler(async (req, res) => {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;

    let whereClause = {};

    if (req.userRole === 'customer') {
      const customer = await Customer.findOne({ where: { user_id: req.userId } });
      whereClause.customer_id = customer.id;
    } else if (req.userRole === 'driver') {
      const driver = await Driver.findOne({ where: { user_id: req.userId } });
      whereClause.driver_id = driver.id;
    }

    const { rows, count } = await Ride.findAndCountAll({
      where: whereClause,
      include: [
        {
          association: 'driver',
          include: [{ association: 'user', attributes: ['id', 'full_name', 'avatar_url'] }],
        },
        { association: 'rating' },
      ],
      order: [['created_at', 'DESC']],
      offset: (page - 1) * limit,
      limit,
    });

    return paginated(res, rows, count, page, limit, 'Ride history fetched');
  });

  /**
   * POST /api/v1/rides/:id/cancel
   * Cancel a ride
   */
  cancelRide = asyncHandler(async (req, res) => {
    const { reason } = req.body;
    const ride = await Ride.findByPk(req.params.id);

    if (!ride) {
      throw new ApiError(404, 'Ride not found', 'RIDE_NOT_FOUND');
    }

    const cancellableStatuses = ['pending', 'searching', 'driver_assigned'];
    if (!cancellableStatuses.includes(ride.status)) {
      throw new ApiError(400, 'Ride cannot be cancelled at this stage', 'CANCELLATION_NOT_ALLOWED');
    }

    const oldStatus = ride.status;
    ride.status = 'cancelled';
    ride.cancellation_reason = reason || 'Cancelled by user';
    ride.cancelled_by = req.userRole === 'customer' ? 'customer' : req.userRole === 'driver' ? 'driver' : 'admin';
    ride.cancelled_at = new Date();
    await ride.save();

    // Log status change
    await RideStatusLog.create({
      ride_id: ride.id,
      previous_status: oldStatus,
      new_status: 'cancelled',
      changed_by: ride.cancelled_by,
      changed_by_id: req.userId,
      metadata: { reason: reason || 'User cancelled' },
    });

    // Cancel active driver search
    RideMatchingService.cancelSearch(ride.id);

    // Free up driver if assigned
    if (ride.driver_id) {
      await Driver.update(
        { is_available: true, current_ride_id: null },
        { where: { id: ride.driver_id } }
      );
    }

    // Apply cancellation charges if applicable
    if (oldStatus === 'driver_assigned') {
      const rates = await FareService.getRates();
      const cancelFee = rates.cancellation_fee_customer || 10;
      ride.cancellation_charges = cancelFee;
      ride.total_fare = parseFloat((parseFloat(ride.total_fare) + cancelFee).toFixed(2));
      await ride.save();
    }

    logger.info(`Ride ${ride.ride_number} cancelled by ${ride.cancelled_by}`);

    return success(res, { ride }, 'Ride cancelled successfully');
  });

  /**
   * POST /api/v1/rides/:id/rate
   * Rate a completed ride
   */
  rateRide = asyncHandler(async (req, res) => {
    const { rating, review } = req.body;
    const ride = await Ride.findByPk(req.params.id);

    if (!ride) {
      throw new ApiError(404, 'Ride not found', 'RIDE_NOT_FOUND');
    }

    if (ride.status !== 'completed') {
      throw new ApiError(400, 'Can only rate completed rides', 'RIDE_NOT_COMPLETED');
    }

    const customer = await Customer.findOne({ where: { user_id: req.userId } });
    if (ride.customer_id !== customer.id) {
      throw new ApiError(403, 'Not your ride to rate', 'FORBIDDEN');
    }

    const existingRating = await RatingReview.findOne({ where: { ride_id: ride.id } });
    if (existingRating) {
      throw new ApiError(400, 'Ride already rated', 'ALREADY_RATED');
    }

    const ratingReview = await RatingReview.create({
      ride_id: ride.id,
      customer_id: ride.customer_id,
      driver_id: ride.driver_id,
      rating: Math.min(5, Math.max(1, rating)),
      review: review || null,
      customer_comment: review || null,
    });

    // Update driver rating
    const driver = await Driver.findByPk(ride.driver_id);
    if (driver) {
      driver.rating_sum = (driver.rating_sum || 0) + rating;
      driver.total_ratings = (driver.total_ratings || 0) + 1;
      driver.rating_avg = parseFloat((driver.rating_sum / driver.total_ratings).toFixed(1));
      await driver.save();
    }

    // Update customer rating (as a rider)
    const customerRating = parseFloat(rating);
    customer.rating = parseFloat(
      (((customer.rating || 0) * (customer.rating_count || 0) + customerRating) / ((customer.rating_count || 0) + 1)).toFixed(1)
    );
    customer.rating_count = (customer.rating_count || 0) + 1;
    await customer.save();

    return created(res, { rating: ratingReview }, 'Rating submitted successfully');
  });
}

module.exports = new RideController();
