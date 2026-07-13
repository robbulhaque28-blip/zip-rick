const fs = require('fs');

// 1. Fix FareService
const fareService = 
'const fareRates = Object.freeze({\n' +
'  base_fare: 30,\n' +
'  per_km: 12,\n' +
'  per_minute: 1,\n' +
'  minimum_fare: 30,\n' +
'  waiting_charge_per_min: 2,\n' +
'  night_charge_multiplier: 1.5,\n' +
'  night_start_hour: 22,\n' +
'  night_end_hour: 6,\n' +
'  peak_multiplier: 1.2,\n' +
'  peak_hours: [{ start: 8, end: 10 }, { start: 17, end: 20 }],\n' +
'  cancellation_fee_customer: 10,\n' +
'});\n' +
'\n' +
'async function getRates() {\n' +
'  try {\n' +
'    const { SystemSetting } = require("../models");\n' +
'    const setting = await SystemSetting.findOne({ where: { key: "fare_rates" } });\n' +
'    if (setting && setting.value) return Object.assign({}, fareRates, setting.value);\n' +
'  } catch (e) {}\n' +
'  return fareRates;\n' +
'}\n' +
'\n' +
'function isNight(hour, rates) {\n' +
'  const s = rates.night_start_hour, e = rates.night_end_hour;\n' +
'  return s > e ? (hour >= s || hour < e) : (hour >= s && hour < e);\n' +
'}\n' +
'\n' +
'function isPeak(hour, rates) {\n' +
'  return rates.peak_hours.some(function(p) { return hour >= p.start && hour < p.end; });\n' +
'}\n' +
'\n' +
'async function calculateFare(params) {\n' +
'  const rates = await getRates();\n' +
'  const hour = new Date().getHours();\n' +
'  const distKm = params.distanceMeters / 1000;\n' +
'  const durMin = params.durationSeconds / 60;\n' +
'  const base = parseFloat(rates.base_fare);\n' +
'  const distFare = parseFloat((distKm * rates.per_km).toFixed(2));\n' +
'  const timeFare = parseFloat((durMin * rates.per_minute).toFixed(2));\n' +
'  let nightCharge = 0;\n' +
'  if (isNight(hour, rates)) nightCharge = parseFloat(((base + distFare) * (rates.night_charge_multiplier - 1)).toFixed(2));\n' +
'  let peakCharge = 0;\n' +
'  if (isPeak(hour, rates)) peakCharge = parseFloat(((base + distFare) * (rates.peak_multiplier - 1)).toFixed(2));\n' +
'  let total = base + distFare + timeFare + nightCharge + peakCharge;\n' +
'  if (total < rates.minimum_fare) total = parseFloat(rates.minimum_fare);\n' +
'  return {\n' +
'    base_fare: base,\n' +
'    distance_fare: distFare,\n' +
'    time_fare: timeFare,\n' +
'    night_charges: nightCharge,\n' +
'    peak_charges: peakCharge,\n' +
'    waiting_charges: 0,\n' +
'    promo_discount: 0,\n' +
'    total_fare: parseFloat(total.toFixed(2)),\n' +
'  };\n' +
'}\n' +
'\n' +
'async function applyPromo(totalFare, promoCode) {\n' +
'  if (!promoCode) return { discount: 0, promo_applied: false };\n' +
'  try {\n' +
'    const { PromoCode } = require("../models");\n' +
'    const Op = require("sequelize").Op;\n' +
'    const promo = await PromoCode.findOne({\n' +
'      where: { code: promoCode, is_active: true,\n' +
'        starts_at: { [Op.lte]: new Date() },\n' +
'        expires_at: { [Op.gte]: new Date() }\n' +
'      }\n' +
'    });\n' +
'    if (!promo) return { discount: 0, promo_applied: false };\n' +
'    let discount = promo.discount_type === "percentage"\n' +
'      ? Math.min((totalFare * promo.discount_value) / 100, promo.max_discount || 999999)\n' +
'      : parseFloat(promo.discount_value);\n' +
'    if (discount > totalFare) discount = totalFare;\n' +
'    return { discount: parseFloat(discount.toFixed(2)), promo_applied: true, promo_code_id: promo.id };\n' +
'  } catch (e) {\n' +
'    return { discount: 0, promo_applied: false };\n' +
'  }\n' +
'}\n' +
'\n' +
'module.exports = { calculateFare, applyPromo, getRates };\n';

fs.writeFileSync('src/services/FareService.js', fareService);
console.log('FareService fixed');

// 2. Fix RideController - ride_number generation
const rideController = 
'const { Op } = require("sequelize");\n' +
'const { Ride, Customer, Driver, RideStatusLog, RatingReview } = require("../models");\n' +
'const { success, paginated, created } = require("../utils/response");\n' +
'const { asyncHandler, ApiError } = require("../middleware/errorHandler");\n' +
'\n' +
'function genNum() {\n' +
'  const d = new Date();\n' +
'  return "ZR-" + d.toISOString().slice(0,10).replace(/-/g,"") + "-" + Math.random().toString(36).substring(2,7).toUpperCase();\n' +
'}\n' +
'\n' +
'module.exports = {\n' +
'  getFareEstimate: asyncHandler(async (req, res) => {\n' +
'    const FareService = require("../services/FareService");\n' +
'    const { pickup_latitude, pickup_longitude, drop_latitude, drop_longitude } = req.body;\n' +
'    const R = 6371;\n' +
'    const dLat = (drop_latitude - pickup_latitude) * Math.PI / 180;\n' +
'    const dLon = (drop_longitude - pickup_longitude) * Math.PI / 180;\n' +
'    const a = Math.sin(dLat/2) * Math.sin(dLat/2) + Math.cos(pickup_latitude * Math.PI / 180) * Math.cos(drop_latitude * Math.PI / 180) * Math.sin(dLon/2) * Math.sin(dLon/2);\n' +
'    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));\n' +
'    const km = R * c;\n' +
'    const fare = await FareService.calculateFare({ distanceMeters: km * 1000, durationSeconds: km * 180 });\n' +
'    return success(res, Object.assign({}, fare, { distance_km: parseFloat(km.toFixed(2)) }));\n' +
'  }),\n' +
'  bookRide: asyncHandler(async (req, res) => {\n' +
'    const FareService = require("../services/FareService");\n' +
'    const c = await Customer.findOne({ where: { user_id: req.userId } });\n' +
'    if (!c) throw new ApiError(404, "Customer not found");\n' +
'    const b = req.body;\n' +
'    const R = 6371;\n' +
'    const dLat = (b.drop_latitude - b.pickup_latitude) * Math.PI / 180;\n' +
'    const dLon = (b.drop_longitude - b.pickup_longitude) * Math.PI / 180;\n' +
'    const a = Math.sin(dLat/2) * Math.sin(dLat/2) + Math.cos(b.pickup_latitude * Math.PI / 180) * Math.cos(b.drop_latitude * Math.PI / 180) * Math.sin(dLon/2) * Math.sin(dLon/2);\n' +
'    const cc = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));\n' +
'    const km = R * cc;\n' +
'    const fare = await FareService.calculateFare({ distanceMeters: km * 1000, durationSeconds: km * 180 });\n' +
'    const ride = await Ride.create({\n' +
'      ride_number: genNum(),\n' +
'      customer_id: c.id,\n' +
'      pickup_latitude: b.pickup_latitude, pickup_longitude: b.pickup_longitude, pickup_address: b.pickup_address,\n' +
'      drop_latitude: b.drop_latitude, drop_longitude: b.drop_longitude, drop_address: b.drop_address,\n' +
'      route_distance: parseFloat((km * 1000).toFixed(2)),\n' +
'      route_duration: parseInt(km * 180),\n' +
'      base_fare: parseFloat(fare.base_fare),\n' +
'      distance_fare: parseFloat(fare.distance_fare || 0),\n' +
'      time_fare: parseFloat(fare.time_fare || 0),\n' +
'      waiting_charges: 0, night_charges: parseFloat(fare.night_charges || 0), peak_charges: parseFloat(fare.peak_charges || 0),\n' +
'      promo_discount: 0, cancellation_charges: 0,\n' +
'      total_fare: parseFloat(fare.total_fare),\n' +
'      commission_amount: parseFloat((fare.total_fare * 0.10).toFixed(2)),\n' +
'      driver_earnings: parseFloat((fare.total_fare * 0.90).toFixed(2)),\n' +
'      payment_method: b.payment_method || "cash",\n' +
'      status: "pending",\n' +
'    });\n' +
'    await RideStatusLog.create({ ride_id: ride.id, previous_status: null, new_status: "pending", changed_by: "customer" });\n' +
'    ride.status = "searching"; await ride.save();\n' +
'    await RideStatusLog.create({ ride_id: ride.id, previous_status: "pending", new_status: "searching", changed_by: "system" });\n' +
'    return created(res, { ride: { id: ride.id, ride_number: ride.ride_number, status: ride.status, total_fare: ride.total_fare, pickup_address: ride.pickup_address, drop_address: ride.drop_address } });\n' +
'  }),\n' +
'  getActiveRide: asyncHandler(async (req, res) => {\n' +
'    const c = await Customer.findOne({ where: { user_id: req.userId } });\n' +
'    if (!c) return success(res, null);\n' +
'    const ride = await Ride.findOne({ where: { customer_id: c.id, status: { [Op.in]: ["searching","driver_assigned","driver_arrived","started"] } }, order: [["created_at","DESC"]] });\n' +
'    return success(res, { ride });\n' +
'  }),\n' +
'  getRideHistory: asyncHandler(async (req, res) => {\n' +
'    const p = parseInt(req.query.page) || 1; const l = parseInt(req.query.limit) || 20;\n' +
'    let w = {};\n' +
'    if (req.userRole === "customer") { const x = await Customer.findOne({ where: { user_id: req.userId } }); w.customer_id = x.id; }\n' +
'    const r = await Ride.findAndCountAll({ where: w, order: [["created_at","DESC"]], offset: (p-1)*l, limit: l });\n' +
'    return paginated(res, r.rows, r.count, p, l);\n' +
'  }),\n' +
'  getRideDetails: asyncHandler(async (req, res) => {\n' +
'    const ride = await Ride.findByPk(req.params.id);\n' +
'    if (!ride) throw new ApiError(404, "Ride not found");\n' +
'    return success(res, { ride });\n' +
'  }),\n' +
'  cancelRide: asyncHandler(async (req, res) => {\n' +
'    const ride = await Ride.findByPk(req.params.id);\n' +
'    if (!ride) throw new ApiError(404, "Ride not found");\n' +
'    if (!["pending","searching","driver_assigned"].includes(ride.status)) throw new ApiError(400, "Cannot cancel");\n' +
'    ride.status = "cancelled"; ride.cancelled_by = "customer"; ride.cancelled_at = new Date(); await ride.save();\n' +
'    return success(res, { ride });\n' +
'  }),\n' +
'  rateRide: asyncHandler(async (req, res) => {\n' +
'    const ride = await Ride.findByPk(req.params.id);\n' +
'    if (!ride) throw new ApiError(404, "Ride not found");\n' +
'    if (ride.status !== "completed") throw new ApiError(400, "Can only rate completed rides");\n' +
'    const c = await Customer.findOne({ where: { user_id: req.userId } });\n' +
'    if (ride.customer_id !== c.id) throw new ApiError(403, "Not your ride");\n' +
'    const existing = await RatingReview.findOne({ where: { ride_id: ride.id } });\n' +
'    if (existing) throw new ApiError(400, "Already rated");\n' +
'    await RatingReview.create({ ride_id: ride.id, customer_id: ride.customer_id, driver_id: ride.driver_id, rating: Math.min(5, Math.max(1, req.body.rating || 5)) });\n' +
'    return created(res, null);\n' +
'  }),\n' +
'};\n';

fs.writeFileSync('src/controllers/RideController.js', rideController);
console.log('RideController fixed');

console.log('All fixes applied!');
