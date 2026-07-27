const router = require("express").Router();
const { authenticate, authorize } = require("../middleware/auth");
const { asyncHandler, ApiError } = require("../middleware/errorHandler");
const { success, paginated } = require("../utils/response");
const { Driver, DriverDocument, Vehicle, Ride, Customer, CommissionPayment, SystemSetting } = require("../models");

// Commission settings live in system_settings so an admin can change the
// threshold and the payout account without a redeploy.
const COMMISSION_DEFAULTS = {
  rate: 10,
  block_threshold: 20,
  upi_id: "",
  bank_account_name: "",
  bank_account_number: "",
  bank_ifsc: "",
  instructions: "Pay your pending commission to the account above, then submit the reference number below.",
};

async function getCommissionSettings() {
  try {
    const row = await SystemSetting.findOne({ where: { key: "commission" } });
    let v = row ? row.value : null;
    if (typeof v === "string") { try { v = JSON.parse(v); } catch (e) { v = null; } }
    return Object.assign({}, COMMISSION_DEFAULTS, v || {});
  } catch (e) {
    return Object.assign({}, COMMISSION_DEFAULTS);
  }
}

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
  if (!driver) throw new ApiError(404, "Driver not found");
  
  let documentUrl = req.body.document_url || '';
  
  // If base64 image data is provided, store it directly
  if (req.body.document_data && req.body.document_data.startsWith('data:image')) {
    documentUrl = req.body.document_data;
  }
  
  const doc = await DriverDocument.create({ 
    driver_id: driver.id, 
    document_type: req.body.document_type, 
    document_url: documentUrl 
  });
  driver.is_documents_uploaded = true; 
  await driver.save();
  return success(res, { document: doc }, "Document uploaded");
}));

router.post("/vehicle", asyncHandler(async (req, res) => {
  const driver = await Driver.findOne({ where: { user_id: req.userId } });
  const [v] = await Vehicle.findOrCreate({ where: { driver_id: driver.id }, defaults: { driver_id: driver.id, ...req.body } });
  if (req.body.vehicle_number) Object.assign(v, req.body);
  await v.save();
  return success(res, { vehicle: v }, "Vehicle saved");
}));

// What the driver owes, plus where to pay it.
router.get("/commission/due", asyncHandler(async (req, res) => {
  const driver = await Driver.findOne({ where: { user_id: req.userId } });
  if (!driver) throw new ApiError(404, "Driver not found");

  const settings = await getCommissionSettings();
  const due = parseFloat(driver.commission_due || 0);
  const threshold = parseFloat(settings.block_threshold || 0);

  // A submitted-but-unconfirmed payment should not be submitted twice.
  const pending = await CommissionPayment.findOne({
    where: { driver_id: driver.id, status: "pending" },
    order: [["created_at", "DESC"]],
  });

  return success(res, {
    commission_due: due,
    total_earnings: parseFloat(driver.total_earnings || 0),
    total_commission_paid: parseFloat(driver.total_commission_paid || 0),
    commission_rate: parseFloat(driver.commission_rate || settings.rate || 10),
    block_threshold: threshold,
    is_blocked: due >= threshold && threshold > 0,
    pending_payment: pending
      ? {
          id: pending.id,
          amount: parseFloat(pending.amount),
          method: pending.method,
          reference: pending.reference,
          submitted_at: pending.submitted_at,
        }
      : null,
    payout: {
      upi_id: settings.upi_id || "",
      bank_account_name: settings.bank_account_name || "",
      bank_account_number: settings.bank_account_number || "",
      bank_ifsc: settings.bank_ifsc || "",
      instructions: settings.instructions || "",
    },
  }, "Commission due");
}));

// Driver's own settlement history.
router.get("/commission/payments", asyncHandler(async (req, res) => {
  const driver = await Driver.findOne({ where: { user_id: req.userId } });
  if (!driver) throw new ApiError(404, "Driver not found");
  const rows = await CommissionPayment.findAll({
    where: { driver_id: driver.id },
    order: [["created_at", "DESC"]],
    limit: 50,
  });
  return success(res, { payments: rows }, "Commission payments");
}));

// Submit a commission payment for admin confirmation.
//
// Fares are cash, so the money moves OUTSIDE the app (UPI or bank transfer).
// The driver reports what they sent; an admin verifies it actually arrived
// before the balance clears. The old version let a driver zero their own
// dues with a single unauthenticated-by-anything POST - no money required.
router.post("/commission/pay", asyncHandler(async (req, res) => {
  const driver = await Driver.findOne({ where: { user_id: req.userId } });
  if (!driver) throw new ApiError(404, "Driver not found");

  const due = parseFloat(driver.commission_due || 0);
  if (due <= 0) throw new ApiError(400, "You have no commission due");

  const existing = await CommissionPayment.findOne({
    where: { driver_id: driver.id, status: "pending" },
  });
  if (existing) {
    throw new ApiError(409, "You already have a payment awaiting confirmation");
  }

  const amount = parseFloat(req.body.amount != null ? req.body.amount : due);
  if (!Number.isFinite(amount) || amount <= 0) throw new ApiError(400, "Invalid amount");
  if (amount > due + 0.01) throw new ApiError(400, "Amount exceeds what you owe");

  const method = ["upi", "bank_transfer", "cash"].includes(req.body.method)
    ? req.body.method
    : "upi";

  const payment = await CommissionPayment.create({
    driver_id: driver.id,
    amount: parseFloat(amount.toFixed(2)),
    method,
    reference: (req.body.reference || "").toString().trim() || null,
    note: (req.body.note || "").toString().trim() || null,
    status: "pending",
    submitted_at: new Date(),
  });

  return success(res, {
    payment,
    commission_due: due,
    message: "Submitted. Your dues clear once we confirm the payment.",
  }, "Payment submitted for confirmation");
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

// Go online / offline.
//
// This endpoint used to ONLY flip a boolean and ignore any latitude/longitude
// in the body. Location arrived exclusively over the socket
// ('driver:location_update'), so if the socket was not connected at the moment
// the driver went online, they ended up online with current_latitude = NULL.
// RideMatchingService.findNearbyDrivers requires current_latitude != null, so
// that driver was silently excluded from EVERY search and received zero ride
// offers - the same failure mode as the stuck-ride bug.
//
// Now the coordinates are persisted here too, and going online without a
// usable position is rejected outright instead of failing silently later.
router.post("/toggle-online", asyncHandler(async (req, res) => {
  const driver = await Driver.findOne({ where: { user_id: req.userId } });
  if (!driver) throw new ApiError(404, "Driver not found");
  if (driver.registration_status !== "approved") throw new ApiError(403, "Your account is pending approval. Please wait for admin verification.");

  // Allow an explicit target so a retry is idempotent; otherwise toggle.
  const goingOnline = (req.body && typeof req.body.is_online === "boolean")
    ? req.body.is_online
    : !driver.is_online;

  // Commission gate. Enforced HERE, on the server, not just in the app - the
  // old check lived only in the Flutter client, so a modified build could
  // simply skip it and go online owing money.
  if (goingOnline) {
    const settings = await getCommissionSettings();
    const threshold = parseFloat(settings.block_threshold || 0);
    const due = parseFloat(driver.commission_due || 0);
    if (threshold > 0 && due >= threshold) {
      // errorHandler strips `details` in production, so the amount owed goes
      // in the message and a distinct code lets the app react specifically.
      throw new ApiError(
        402,
        "Pay your pending commission of Rs " + due.toFixed(0) + " to go online.",
        "COMMISSION_DUE",
        { commission_due: due, block_threshold: threshold }
      );
    }
  }

  if (goingOnline) {
    const lat = parseFloat(req.body?.latitude);
    const lng = parseFloat(req.body?.longitude);
    const hasFix = Number.isFinite(lat) && Number.isFinite(lng)
      && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180
      && !(lat === 0 && lng === 0);

    if (hasFix) {
      driver.current_latitude = lat;
      driver.current_longitude = lng;
      driver.last_location_update = new Date();
    } else if (driver.current_latitude == null || driver.current_longitude == null) {
      // No coordinates in the request and none stored - going online would
      // make this driver invisible to matching. Fail loudly instead.
      throw new ApiError(400, "We could not read your location. Turn on GPS and try again.");
    }
  }

  driver.is_online = goingOnline;
  driver.is_available = goingOnline;
  await driver.save();

  return success(res, {
    is_online: driver.is_online,
    is_available: driver.is_available,
    current_latitude: driver.current_latitude,
    current_longitude: driver.current_longitude,
  });
}));

// Standalone location ping. Gives the app an HTTP fallback for keeping the
// driver's position fresh when the socket has dropped.
router.post("/location", asyncHandler(async (req, res) => {
  const driver = await Driver.findOne({ where: { user_id: req.userId } });
  if (!driver) throw new ApiError(404, "Driver not found");

  const lat = parseFloat(req.body?.latitude);
  const lng = parseFloat(req.body?.longitude);
  const ok = Number.isFinite(lat) && Number.isFinite(lng)
    && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180
    && !(lat === 0 && lng === 0);
  if (!ok) throw new ApiError(400, "Valid latitude and longitude are required");

  driver.current_latitude = lat;
  driver.current_longitude = lng;
  driver.last_location_update = new Date();
  await driver.save();

  return success(res, { latitude: driver.current_latitude, longitude: driver.current_longitude });
}));

// Registration fee payment
router.post("/registration/pay", asyncHandler(async (req, res) => {
  const driver = await Driver.findOne({ where: { user_id: req.userId } });
  if (!driver) throw new ApiError(404, "Driver not found");
  if (driver.registration_fee_paid) return success(res, { message: "Already paid" }, "Already paid");
  
  driver.registration_fee_paid = true;
  driver.registration_fee_amount = req.body.amount || 499;
  await driver.save();
  
  const { DriverRegistrationPayment } = require("../models");
  await DriverRegistrationPayment.create({
    driver_id: driver.id,
    amount: req.body.amount || 499,
    payment_status: "completed",
    payment_date: new Date(),
  });
  
  return success(res, { message: "Payment successful", registration_fee_paid: true }, "Payment recorded");
}));

// Set destination filter
router.post('/destination', asyncHandler(async (req, res) => {
  const driver = await Driver.findOne({ where: { user_id: req.userId } });
  if (!driver) throw new ApiError(404, 'Driver not found');
  driver.destination_latitude = req.body.latitude || null;
  driver.destination_longitude = req.body.longitude || null;
  driver.destination_address = req.body.address || null;
  driver.destination_radius_km = req.body.radius_km || 2.0;
  await driver.save();
  return success(res, { destination: { latitude: driver.destination_latitude, longitude: driver.destination_longitude, address: driver.destination_address, radius_km: driver.destination_radius_km } }, 'Destination filter set');
}));

// Clear destination filter
router.delete('/destination', asyncHandler(async (req, res) => {
  const driver = await Driver.findOne({ where: { user_id: req.userId } });
  if (!driver) throw new ApiError(404, 'Driver not found');
  driver.destination_latitude = null;
  driver.destination_longitude = null;
  driver.destination_address = null;
  await driver.save();
  return success(res, null, 'Destination filter cleared');
}));

// Verify ride OTP
router.post('/verify-otp', asyncHandler(async (req, res) => {
  const driver = await Driver.findOne({ where: { user_id: req.userId } });
  if (!driver) throw new ApiError(404, 'Driver not found');
  const ride = await Ride.findByPk(req.body.ride_id);
  if (!ride) throw new ApiError(404, 'Ride not found');
  if (ride.driver_id !== driver.id) throw new ApiError(403, 'Not your ride');
  if (ride.ride_otp !== req.body.otp) throw new ApiError(400, 'Invalid OTP');
  ride.status = 'started';
  ride.ride_started_at = new Date();
  await ride.save();
  return success(res, { ride }, 'Ride verified and started');
}));

module.exports = router;