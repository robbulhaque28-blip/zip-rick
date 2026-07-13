const fs = require('fs');
const content = 'const { Op } = require(\"sequelize\");\n' +
'const { Ride, Customer, Driver, RideStatusLog, RatingReview } = require(\"../models\");\n' +
'const { success, paginated, created } = require(\"../utils/response\");\n' +
'const { asyncHandler, ApiError } = require(\"../middleware/errorHandler\");\n' +
'\n' +
'function genRideNum() {\n' +
'  const d = new Date();\n' +
'  return \"ZR-\" + d.toISOString().slice(0,10).replace(/-/g,\"\") + \"-\" + Math.random().toString(36).substring(2,7).toUpperCase();\n' +
'}\n' +
'\n' +
'module.exports = {\n' +
'  getFareEstimate: asyncHandler(async (req, res) => {\n' +
'    const FareService = require(\"../services/FareService\");\n' +
'    const p = req.body;\n' +
'    const R = 6371;\n' +
'    const dLat = (p.drop_latitude - p.pickup_latitude) * Math.PI / 180;\n' +
'    const dLon = (p.drop_longitude - p.pickup_longitude) * Math.PI / 180;\n' +
'    const a = Math.sin(dLat/2) * Math.sin(dLat/2) + Math.cos(p.pickup_latitude * Math.PI / 180) * Math.cos(p.drop_latitude * Math.PI / 180) * Math.sin(dLon/2) * Math.sin(dLon/2);\n' +
'    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));\n' +
'    const distanceKm = R * c;\n' +
'    const fare = await FareService.calculateFare({ distanceMeters: distanceKm * 1000, durationSeconds: distanceKm * 180 });\n' +
'    return success(res, { ...fare, distance_km: parseFloat(distanceKm.toFixed(2)) });\n' +
'  }),\n' +
'\n' +
'  bookRide: asyncHandler(async (req, res) => {\n' +
'    const FareService = require(\"../services/FareService\");\n' +
'    const customer = await Customer.findOne({ where: { user_id: req.userId } });\n' +
'    if (!customer) throw new ApiError(404, \"Customer not found\");\n' +
'    const p = req.body;\n' +
'    const R = 6371;\n' +
'    const dLat = (p.drop_latitude - p.pickup_latitude) * Math.PI / 180;\n' +
'    const dLon = (p.drop_longitude - p.pickup_longitude) * Math.PI / 180;\n' +
'    const a = Math.sin(dLat/2) * Math.sin(dLat/2) + Math.cos(p.pickup_latitude * Math.PI / 180) * Math.cos(p.drop_latitude * Math.PI / 180) * Math.sin(dLon/2) * Math.sin(dLon/2);\n' +
'    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));\n' +
'    const distanceKm = R * c;\n' +
'    const fare = await FareService.calculateFare({ distanceMeters: distanceKm * 1000, durationSeconds: distanceKm * 180 });\n' +
'    const ride = await Ride.create({\n' +
'      ride_number: genRideNum(),\n' +
'      customer_id: customer.id,\n' +
'      pickup_latitude: p.pickup_latitude, pickup_longitude: p.pickup_longitude, pickup_address: p.pickup_address,\n' +
'      drop_latitude: p.drop_latitude, drop_longitude: p.drop_longitude, drop_address: p.drop_address,\n' +
'      route_distance: parseFloat((distanceKm * 1000).toFixed(2)),\n' +
'      route_duration: parseInt(distanceKm * 180),\n' +
'      base_fare: parseFloat(fare.base_fare),\n' +
'      distance_fare: parseFloat(fare.distance_fare || 0),\n' +
'      time_fare: parseFloat(fare.time_fare || 0),\n' +
'      waiting_charges: 0, night_charges: parseFloat(fare.night_charges || 0), peak_charges: parseFloat(fare.peak_charges || 0),\n' +
'      promo_discount: 0, cancellation_charges: 0,\n' +
'      total_fare: parseFloat(fare.total_fare),\n' +
'      commission_amount: parseFloat((fare.total_fare * 0.10).toFixed(2)),\n' +
'      driver_earnings: parseFloat((fare.total_fare * 0.90).toFixed(2)),\n' +
'      payment_method: p.payment_method || \"cash\",\n' +
'      status: \"pending\",\n' +
'    });\n' +
'    await RideStatusLog.create({ ride_id: ride.id, previous_status: null, new_status: \"pending\", changed_by: \"customer\" });\n' +
'    ride.status = \"searching\"; await ride.save();\n' +
'    await RideStatusLog.create({ ride_id: ride.id, previous_status: \"pending\", new_status: \"searching\", changed_by: \"system\" });\n' +
'    return created(res, { ride: { id: ride.id, ride_number: ride.ride_number, status: ride.status, total_fare: ride.total_fare, pickup_address: ride.pickup_address, drop_address: ride.drop_address } });\n' +
'  }),\n' +
'\n' +
'  getActiveRide: asyncHandler(async (req, res) => {\n' +
'    const customer = await Customer.findOne({ where: { user_id: req.userId } });\n' +
'    if (!customer) return success(res, null, \"No active ride\");\n' +
'    const ride = await Ride.findOne({ where: { customer_id: customer.id, status: { [Op.in]: [\"searching\",\"driver_assigned\",\"driver_arrived\",\"started\"] } }, order: [[\"created_at\",\"DESC\"]] });\n' +
'    return success(res, { ride });\n' +
'  }),\n' +
'\n' +
'  getRideHistory: asyncHandler(async (req, res) => {\n' +
'    const page = parseInt(req.query.page) || 1; const limit = parseInt(req.query.limit) || 20;\n' +
'    let where = {};\n' +
'    if (req.userRole === \"customer\") { const c = await Customer.findOne({ where: { user_id: req.userId } }); where.customer_id = c.id; }\n' +
'    const { rows, count } = await Ride.findAndCountAll({ where, order: [[\"created_at\",\"DESC\"]], offset: (page-1)*limit, limit });\n' +
'    return paginated(res, rows, count, page, limit);\n' +
'  }),\n' +
'\n' +
'  getRideDetails: asyncHandler(async (req, res) => {\n' +
'    const ride = await Ride.findByPk(req.params.id, { include: [{ association: \"customer\", include: [{ association: \"user\", attributes: [\"full_name\"] }] }, { association: \"driver\", include: [{ association: \"user\", attributes: [\"full_name\",\"phone\"] }] }] });\n' +
'    if (!ride) throw new ApiError(404, \"Ride not found\");\n' +
'    return success(res, { ride });\n' +
'  }),\n' +
'\n' +
'  cancelRide: asyncHandler(async (req, res) => {\n' +
'    const ride = await Ride.findByPk(req.params.id);\n' +
'    if (!ride) throw new ApiError(404, \"Ride not found\");\n' +
'    if (![\"pending\",\"searching\",\"driver_assigned\"].includes(ride.status)) throw new ApiError(400, \"Cannot cancel\");\n' +
'    ride.status = \"cancelled\"; ride.cancelled_by = \"customer\"; ride.cancelled_at = new Date(); await ride.save();\n' +
'    if (ride.driver_id) await Driver.update({ is_available: true, current_ride_id: null }, { where: { id: ride.driver_id } });\n' +
'    return success(res, { ride });\n' +
'  }),\n' +
'\n' +
'  rateRide: asyncHandler(async (req, res) => {\n' +
'    const ride = await Ride.findByPk(req.params.id);\n' +
'    if (!ride) throw new ApiError(404, \"Ride not found\");\n' +
'    if (ride.status !== \"completed\") throw new ApiError(400, \"Can only rate completed rides\");\n' +
'    const customer = await Customer.findOne({ where: { user_id: req.userId } });\n' +
'    if (ride.customer_id !== customer.id) throw new ApiError(403, \"Not your ride\");\n' +
'    const existing = await RatingReview.findOne({ where: { ride_id: ride.id } });\n' +
'    if (existing) throw new ApiError(400, \"Already rated\");\n' +
'    const rating = Math.min(5, Math.max(1, req.body.rating || 5));\n' +
'    await RatingReview.create({ ride_id: ride.id, customer_id: ride.customer_id, driver_id: ride.driver_id, rating, review: req.body.review || \"\" });\n' +
'    return created(res, { rating });\n' +
'  }),\n' +
'};\n';

fs.writeFileSync('src/controllers/RideController.js', content);
console.log('RideController written with all functions');
