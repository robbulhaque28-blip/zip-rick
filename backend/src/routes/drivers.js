const router = require("express").Router();
const { authenticate, authorize } = require("../middleware/auth");
const { asyncHandler, ApiError } = require("../middleware/errorHandler");
const { success, paginated } = require("../utils/response");
const { Driver, DriverDocument, Vehicle, Ride, Customer } = require("../models");

router.use(authenticate);
router.use(authorize("driver", "admin"));

// Get driver profile
router.get("/profile", asyncHandler(async (req, res) => {
  const driver = await Driver.findOne({ where: { user_id: req.userId }, include: [{ association: "user", attributes: ["id","full_name","phone","avatar_url"] }, "documents", "vehicle"] });
  if (!driver) throw new ApiError(404, "Driver not found");
  return success(res, { driver });
}));

// Update driver profile
router.put("/profile", asyncHandler(async (req, res) => {
  const driver = await Driver.findOne({ where: { user_id: req.userId } });
  if (!driver) throw new ApiError(404, "Driver not found");
  ["date_of_birth","gender","address","city","state","pincode"].forEach(f => { if (req.body[f] !== undefined) driver[f] = req.body[f]; });
  await driver.save();
  return success(res, { driver }, "Profile updated");
}));

router.post("/documents", asyncHandler(async (req, res) => {
  const driver = await Driver.findOne({ where: { user_id: req.userId } });
  const doc = await DriverDocument.create({ driver_id: driver.id, document_type: req.body.document_type, document_url: req.body.document_url });
  driver.is_documents_uploaded = true; await driver.save();
  return success(res, { document: doc }, "Document uploaded");
}));

router.post("/vehicle", asyncHandler(async (req, res) => {
  const driver = await Driver.findOne({ where: { user_id: req.userId } });
  const [v] = await Vehicle.findOrCreate({ where: { driver_id: driver.id }, defaults: { driver_id: driver.id, ...req.body } });
  if (req.body.vehicle_number) Object.assign(v, req.body);
  await v.save();
  return success(res, { vehicle: v }, "Vehicle saved");
}));

// Get driver commission due
router.get("/commission/due", asyncHandler(async (req, res) => {
  const driver = await Driver.findOne({ where: { user_id: req.userId } });
  if (!driver) throw new ApiError(404, "Driver not found");
  return success(res, {
    commission_due: parseFloat(driver.commission_due || 0),
    total_earnings: parseFloat(driver.total_earnings || 0),
    total_commission_paid: parseFloat(driver.total_commission_paid || 0),
  }, "Commission due");
}));

// Pay commission (settle dues)
router.post("/commission/pay", asyncHandler(async (req, res) => {
  const driver = await Driver.findOne({ where: { user_id: req.userId } });
  if (!driver) throw new ApiError(404, "Driver not found");
  const { amount } = req.body;
  const due = parseFloat(driver.commission_due || 0);
  if (!amount || amount <= 0) throw new ApiError(400, "Invalid amount");
  if (amount > due) throw new ApiError(400, "Amount exceeds due");
  driver.commission_due = parseFloat((due - amount).toFixed(2));
  driver.total_commission_paid = parseFloat((parseFloat(driver.total_commission_paid || 0) + amount).toFixed(2));
  await driver.save();
  return success(res, { commission_due: driver.commission_due, total_commission_paid: driver.total_commission_paid }, "Commission paid");
}));

router.get("/earnings", asyncHandler(async (req, res) => {
  const driver = await Driver.findOne({ where: { user_id: req.userId } });
  if (!driver) throw new ApiError(404, "Driver not found");
  const today = new Date(); today.setHours(0,0,0,0);
  const weekStart = new Date(today); weekStart.setDate(weekStart.getDate() - weekStart.getDay());
  const todayE = await Ride.sum("driver_earnings", { where: { driver_id: driver.id, status: "completed", ride_completed_at: { [require("sequelize").Op.gte]: today } } }) || 0;
  const weekE = await Ride.sum("driver_earnings", { where: { driver_id: driver.id, status: "completed", ride_completed_at: { [require("sequelize").Op.gte]: weekStart } } }) || 0;
  return success(res, { total_earnings: driver.total_earnings, total_rides: driver.total_rides, today_earnings: todayE, week_earnings: weekE, rating_avg: driver.rating_avg });
}));

router.post("/toggle-online", asyncHandler(async (req, res) => {
  const driver = await Driver.findOne({ where: { user_id: req.userId } });
  if (driver.registration_status !== "approved") throw new ApiError(403, "Not approved");
  driver.is_online = !driver.is_online;
  driver.is_available = driver.is_online;
  await driver.save();
  return success(res, { is_online: driver.is_online });
}));

module.exports = router;