const fs = require('fs');
const content = 
'const { Op } = require("sequelize");\n' +
'const { Ride, Customer, Driver, RideStatusLog, RatingReview } = require("../models");\n' +
'const { success, created } = require("../utils/response");\n' +
'const { asyncHandler, ApiError } = require("../middleware/errorHandler");\n' +
'\n' +
'function genRideNum() {\n' +
'  const d = new Date();\n' +
'  return "ZR-" + d.toISOString().slice(0,10).replace(/-/g,"") + "-" + Math.random().toString(36).substring(2,7).toUpperCase();\n' +
'}\n' +
'\n' +
'module.exports = {\n' +
'  getFareEstimate: asyncHandler(async (req, res) => {\n' +
'    const { pickup_latitude, pickup_longitude, drop_latitude, drop_longitude } = req.body;\n' +
'    const R = 6371;\n' +
'    const dLat = (drop_latitude - pickup_latitude) * Math.PI / 180;\n' +
'    const dLon = (drop_longitude - pickup_longitude) * Math.PI / 180;\n' +
'    const a = Math.sin(dLat/2) * Math.sin(dLat/2) + Math.cos(pickup_latitude * Math.PI / 180) * Math.cos(drop_latitude * Math.PI / 180) * Math.sin(dLon/2) * Math.sin(dLon/2);\n' +
'    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));\n' +
'    const distanceKm = R * c;\n' +
'    const FareService = require("../services/FareService");\n' +
'    const fare = await FareService.calculateFare({ distanceMeters: distanceKm * 1000, durationSeconds: distanceKm * 180 });\n' +
'    return success(res, { ...fare, distance_km: parseFloat(distanceKm.toFixed(2)) }, "Fare estimated");\n' +
'  }),\n' +
'  bookRide: asyncHandler(async (req, res) => {\n' +
'    const customer = await Customer.findOne({ where: { user_id: req.userId } });\n' +
'    if (!customer) throw new ApiError(404, "Customer not found");\n' +
'    const { pickup_latitude, pickup_longitude, pickup_address, drop_latitude, drop_longitude, drop_address } = req.body;\n' +
'    const R = 6371;\n' +
'    const dLat = (drop_latitude - pickup_latitude) * Math.PI / 180;\n' +
'    const dLon = (drop_longitude - pickup_longitude) * Math.PI / 180;\n' +
'    const a = Math.sin(dLat/2) * Math.sin(dLat/2) + Math.cos(pickup_latitude * Math.PI / 180) * Math.cos(drop_latitude * Math.PI / 180) * Math.sin(dLon/2) * Math.sin(dLon/2);\n' +
'    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));\n' +
'    const distanceKm = R * c;\n' +
'    const FareService = require("../services/FareService");\n' +
'    const fare = await FareService.calculateFare({ distanceMeters: distanceKm * 1000, durationSeconds: distanceKm * 180 });\n' +
'    const ride = await Ride.create({\n' +
'      ride_number: genRideNum(),\n' +
'      customer_id: customer.id,\n' +
'      pickup_latitude, pickup_longitude, pickup_address,\n' +
'      drop_latitude, drop_longitude, drop_address,\n' +
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
'      payment_method: req.body.payment_method || "cash",\n' +
'      status: "pending",\n' +
'    });\n' +
'    await RideStatusLog.create({ ride_id: ride.id, previous_status: null, new_status: "pending", changed_by: "customer" });\n' +
'    ride.status = "searching"; await ride.save();\n' +
'    await RideStatusLog.create({ ride_id: ride.id, previous_status: "pending", new_status: "searching", changed_by: "system" });\n' +
'    return created(res, { ride: { id: ride.id, ride_number: ride.ride_number, status: ride.status, total_fare: ride.total_fare, pickup_address: ride.pickup_address, drop_address: ride.drop_address } }, "Ride booked");\n' +
'  }),\n' +
'  cancelRide: asyncHandler(async (req, res) => {\n' +
'    const ride = await Ride.findByPk(req.params.id);\n' +
'    if (!ride) throw new ApiError(404, "Ride not found");\n' +
'    if (!["pending", "searching", "driver_assigned"].includes(ride.status)) throw new ApiError(400, "Cannot cancel");\n' +
'    ride.status = "cancelled"; ride.cancelled_by = "customer"; ride.cancelled_at = new Date(); await ride.save();\n' +
'    return success(res, { ride }, "Ride cancelled");\n' +
'  }),\n' +
'};\n';

fs.writeFileSync('src/controllers/RideController.js', content);
console.log('RideController.js written successfully');
