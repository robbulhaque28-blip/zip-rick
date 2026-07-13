const { Op } = require("sequelize");
const { Ride, Customer, Driver, RideStatusLog, RatingReview } = require("../models");
const { success, paginated, created } = require("../utils/response");
const { asyncHandler, ApiError } = require("../middleware/errorHandler");

function genNum() {
  const d = new Date();
  return "ZR-" + d.toISOString().slice(0,10).replace(/-/g,"") + "-" + Math.random().toString(36).substring(2,7).toUpperCase();
}

module.exports = {
  getFareEstimate: asyncHandler(async (req, res) => {
    const FareService = require("../services/FareService");
    const { pickup_latitude, pickup_longitude, drop_latitude, drop_longitude } = req.body;
    const R = 6371;
    const dLat = (drop_latitude - pickup_latitude) * Math.PI / 180;
    const dLon = (drop_longitude - pickup_longitude) * Math.PI / 180;
    const a = Math.sin(dLat/2) * Math.sin(dLat/2) + Math.cos(pickup_latitude * Math.PI / 180) * Math.cos(drop_latitude * Math.PI / 180) * Math.sin(dLon/2) * Math.sin(dLon/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    const km = R * c;
    const fare = await FareService.calculateFare({ distanceMeters: km * 1000, durationSeconds: km * 180 });
    return success(res, Object.assign({}, fare, { distance_km: parseFloat(km.toFixed(2)) }));
  }),
  bookRide: asyncHandler(async (req, res) => {
    const FareService = require("../services/FareService");
    const c = await Customer.findOne({ where: { user_id: req.userId } });
    if (!c) throw new ApiError(404, "Customer not found");
    const b = req.body;
    const R = 6371;
    const dLat = (b.drop_latitude - b.pickup_latitude) * Math.PI / 180;
    const dLon = (b.drop_longitude - b.pickup_longitude) * Math.PI / 180;
    const a = Math.sin(dLat/2) * Math.sin(dLat/2) + Math.cos(b.pickup_latitude * Math.PI / 180) * Math.cos(b.drop_latitude * Math.PI / 180) * Math.sin(dLon/2) * Math.sin(dLon/2);
    const cc = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    const km = R * cc;
    const fare = await FareService.calculateFare({ distanceMeters: km * 1000, durationSeconds: km * 180 });
    const ride = await Ride.create({
      ride_number: genNum(),
      customer_id: c.id,
      pickup_latitude: b.pickup_latitude, pickup_longitude: b.pickup_longitude, pickup_address: b.pickup_address,
      drop_latitude: b.drop_latitude, drop_longitude: b.drop_longitude, drop_address: b.drop_address,
      route_distance: parseFloat((km * 1000).toFixed(2)),
      route_duration: parseInt(km * 180),
      base_fare: parseFloat(fare.base_fare),
      distance_fare: parseFloat(fare.distance_fare || 0),
      time_fare: parseFloat(fare.time_fare || 0),
      waiting_charges: 0, night_charges: parseFloat(fare.night_charges || 0), peak_charges: parseFloat(fare.peak_charges || 0),
      promo_discount: 0, cancellation_charges: 0,
      total_fare: parseFloat(fare.total_fare),
      commission_amount: parseFloat((fare.total_fare * 0.10).toFixed(2)),
      driver_earnings: parseFloat((fare.total_fare * 0.90).toFixed(2)),
      payment_method: b.payment_method || "cash",
      status: "pending",
    });
    await RideStatusLog.create({ ride_id: ride.id, previous_status: null, new_status: "pending", changed_by: "customer" });
    ride.status = "searching"; await ride.save();
    await RideStatusLog.create({ ride_id: ride.id, previous_status: "pending", new_status: "searching", changed_by: "system" });
    return created(res, { ride: { id: ride.id, ride_number: ride.ride_number, status: ride.status, total_fare: ride.total_fare, pickup_address: ride.pickup_address, drop_address: ride.drop_address } });
  }),
  getActiveRide: asyncHandler(async (req, res) => {
    const c = await Customer.findOne({ where: { user_id: req.userId } });
    if (!c) return success(res, null);
    const ride = await Ride.findOne({ where: { customer_id: c.id, status: { [Op.in]: ["searching","driver_assigned","driver_arrived","started"] } }, order: [["created_at","DESC"]] });
    return success(res, { ride });
  }),
  getRideHistory: asyncHandler(async (req, res) => {
    const p = parseInt(req.query.page) || 1; const l = parseInt(req.query.limit) || 20;
    let w = {};
    if (req.userRole === "customer") { const x = await Customer.findOne({ where: { user_id: req.userId } }); w.customer_id = x.id; }
    const r = await Ride.findAndCountAll({ where: w, order: [["created_at","DESC"]], offset: (p-1)*l, limit: l });
    return paginated(res, r.rows, r.count, p, l);
  }),
  getRideDetails: asyncHandler(async (req, res) => {
    const ride = await Ride.findByPk(req.params.id);
    if (!ride) throw new ApiError(404, "Ride not found");
    return success(res, { ride });
  }),
  cancelRide: asyncHandler(async (req, res) => {
    const ride = await Ride.findByPk(req.params.id);
    if (!ride) throw new ApiError(404, "Ride not found");
    if (!["pending","searching","driver_assigned"].includes(ride.status)) throw new ApiError(400, "Cannot cancel");
    ride.status = "cancelled"; ride.cancelled_by = "customer"; ride.cancelled_at = new Date(); await ride.save();
    return success(res, { ride });
  }),
  rateRide: asyncHandler(async (req, res) => {
    const ride = await Ride.findByPk(req.params.id);
    if (!ride) throw new ApiError(404, "Ride not found");
    if (ride.status !== "completed") throw new ApiError(400, "Can only rate completed rides");
    const c = await Customer.findOne({ where: { user_id: req.userId } });
    if (ride.customer_id !== c.id) throw new ApiError(403, "Not your ride");
    const existing = await RatingReview.findOne({ where: { ride_id: ride.id } });
    if (existing) throw new ApiError(400, "Already rated");
    await RatingReview.create({ ride_id: ride.id, customer_id: ride.customer_id, driver_id: ride.driver_id, rating: Math.min(5, Math.max(1, req.body.rating || 5)) });
    return created(res, null);
  }),
};
