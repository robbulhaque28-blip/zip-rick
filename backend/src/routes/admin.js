const router = require('express').Router();
const { authenticate, authorize } = require('../middleware/auth');
const { asyncHandler, ApiError } = require('../middleware/errorHandler');
const { success, paginated } = require('../utils/response');
const { Op, literal } = require('sequelize');
const { User, Driver, Customer, Ride, Payment, AdminUser, SystemSetting, PromoCode, SupportTicket, AuditLog, DriverRegistrationPayment,
        DriverDocument, Vehicle, RideStatusLog, RatingReview, ChatMessage, PromoRedemption, Referral, SavedPlace,
        SupportTicketMessage, Transaction, Wallet, Notification } = require('../models');
const { sequelize } = require('../config/db');

// ---------------------------------------------------------------------------
// system_settings.value is a TEXT column, but several handlers passed a raw
// object to upsert(). Sequelize rejected that with "value cannot be an array
// or an object", so EVERY object-shaped setting silently failed to save -
// fare rates, registration fee and commission all included. The GET side had
// the mirror problem: it returned the raw string instead of parsed JSON.
// ---------------------------------------------------------------------------
function parseSetting(row, fallback) {
  if (!row || row.value == null) return fallback;
  let v = row.value;
  if (typeof v === 'string') {
    try { v = JSON.parse(v); } catch (e) { return fallback; }
  }
  return (v && typeof v === 'object') ? v : fallback;
}

async function saveSetting(key, obj) {
  const payload = typeof obj === 'string' ? obj : JSON.stringify(obj);
  const existing = await SystemSetting.findOne({ where: { key } });
  if (existing) {
    existing.value = payload;
    await existing.save();
    return existing;
  }
  return SystemSetting.create({ key, value: payload });
}

router.use(authenticate);
router.use(authorize('admin'));

router.get('/dashboard', asyncHandler(async (req, res) => {
  try {
    const today = new Date(); today.setHours(0,0,0,0);
    const [tc, td, pd, tr, ar, od, of, os] = await Promise.all([
      Customer.count(),
      Driver.count(),
      Driver.count({ where: { registration_status: 'pending' } }),
      Ride.count(),
      Ride.count({ where: { status: { [Op.in]: ['searching','driver_assigned','driver_arrived','started'] } } }),
      Driver.count({ where: { is_online: true, is_available: true, registration_status: 'approved' } }),
      Driver.count({ where: { is_online: false, registration_status: 'approved' } }),
      Driver.count({ where: { is_online: true, is_available: false } }),
    ]);
    
    let trev = 0;
    let trevToday = 0;
    try {
      // Payment model columns are `status` and `created_at`. The old code
      // queried `payment_status` / `paid_at`, which do not exist - the query
      // threw and the catch below silently reported Rs 0 revenue.
      trev = await Payment.sum('amount', { where: { status: 'completed' } }) || 0;
      trevToday = await Payment.sum('amount', { where: { status: 'completed', created_at: { [Op.gte]: today } } }) || 0;
    } catch (e) {
      trev = await Payment.sum('amount') || 0;
      trevToday = 0;
    }
    
    const todayRides = await Ride.count({ where: { created_at: { [Op.gte]: today } } });
    const revenueData = await Payment.findAll({
      where: { created_at: { [Op.gte]: new Date(Date.now() - 30*24*60*60*1000) } },
      attributes: [[literal('DATE(created_at)'),'date'],[literal('SUM(amount)'),'total_revenue']],
      group: [literal('DATE(created_at)')], order: [[literal('DATE(created_at)'),'ASC']], raw: true
    });
    
    return success(res, {
      overview: {
        total_customers: tc || 0, total_drivers: td || 0, pending_drivers: pd || 0,
        total_rides: tr || 0, active_rides: ar || 0, today_rides: todayRides || 0,
        online_drivers: od || 0, offline_drivers: of || 0, on_ride_drivers: os || 0,
        revenue: { total: trev, today: trevToday },
        revenue_chart: revenueData,
      },
    });
  } catch (e) {
    console.log('Dashboard error:', e.message);
    return success(res, { overview: {
      total_customers: await Customer.count() || 0, total_drivers: await Driver.count() || 0,
      pending_drivers: 0, total_rides: 0, active_rides: 0, today_rides: 0,
      online_drivers: 0, offline_drivers: 0, on_ride_drivers: 0,
      revenue: { total: 0, today: 0 }, revenue_chart: [],
    }});
  }
}));

router.get('/drivers', asyncHandler(async (req, res) => {
  const page = parseInt(req.query.page)||1, limit = parseInt(req.query.limit)||50;
  const where = {};
  if (req.query.status) where.registration_status = req.query.status;
  if (req.query.search) {
    where[Op.or] = [
      { '$user.full_name$': { [Op.like]: '%' + req.query.search + '%' } },
      { '$user.phone$': { [Op.like]: '%' + req.query.search + '%' } }
    ];
  }
  const { rows, count } = await Driver.findAndCountAll({
    where,
    include: [{ association: 'user', attributes: ['id','full_name','phone','email','is_active','created_at'] }, 'vehicle', 'documents'],
    order: [['created_at','DESC']],
    offset: (page-1)*limit, limit
  });
  return paginated(res, rows, count, page, limit);
}));

router.get('/drivers/:id', asyncHandler(async (req, res) => {
  const d = await Driver.findByPk(req.params.id, {
    include: [{ association: 'user', attributes: ['id','full_name','phone','email','is_active','is_blocked'] }, 'vehicle', 'documents', 'registrationPayments']
  });
  if (!d) throw new ApiError(404, 'Not found');
  return success(res, { driver: d });
}));

router.post('/drivers/:id/approve', asyncHandler(async (req, res) => {
  const admin = await AdminUser.findOne({ where: { user_id: req.userId } });
  const d = await Driver.findByPk(req.params.id);
  if (!d) throw new ApiError(404, 'Not found');
  d.registration_status = 'approved';
  d.approved_by = admin.id;
  d.approved_at = new Date();
  await d.save();
  return success(res, { driver: d }, 'Driver approved');
}));

router.post('/drivers/:id/reject', asyncHandler(async (req, res) => {
  const admin = await AdminUser.findOne({ where: { user_id: req.userId } });
  const d = await Driver.findByPk(req.params.id);
  if (!d) throw new ApiError(404, 'Not found');
  d.registration_status = 'rejected';
  d.rejection_reason = req.body.reason || 'Documents rejected';
  d.approved_by = admin.id;
  await d.save();
  return success(res, { driver: d }, 'Driver rejected');
}));

router.post('/drivers/:id/suspend', asyncHandler(async (req, res) => {
  const d = await Driver.findByPk(req.params.id);
  if (!d) throw new ApiError(404, 'Not found');
  d.registration_status = 'suspended';
  d.is_online = false;
  d.is_available = false;
  await d.save();
  return success(res, { driver: d }, 'Driver suspended');
}));

router.get('/customers', asyncHandler(async (req, res) => {
  const page = parseInt(req.query.page)||1, limit = parseInt(req.query.limit)||50;
  const where = {};
  if (req.query.search) {
    where[Op.or] = [
      { '$user.full_name$': { [Op.like]: '%' + req.query.search + '%' } },
      { '$user.phone$': { [Op.like]: '%' + req.query.search + '%' } }
    ];
  }
  const { rows, count } = await Customer.findAndCountAll({
    where,
    include: [{ association: 'user', attributes: ['id','full_name','phone','email','is_active','created_at'] }],
    order: [['created_at','DESC']],
    offset: (page-1)*limit, limit
  });
  return paginated(res, rows, count, page, limit);
}));

router.get('/customers/:id', asyncHandler(async (req, res) => {
  const c = await Customer.findByPk(req.params.id, {
    include: [{ association: 'user', attributes: ['id','full_name','phone','email','is_active','created_at'] }],
  });
  if (!c) throw new ApiError(404, 'Not found');
  const rides = await Ride.findAll({ where: { customer_id: c.id }, limit: 50, order: [['created_at','DESC']],
    include: [{ association: 'driver', include: [{ association: 'user', attributes: ['full_name'] }] }] });
  return success(res, { customer: c, rides });
}));

router.get('/drivers/:id/rides', asyncHandler(async (req, res) => {
  const d = await Driver.findByPk(req.params.id);
  if (!d) throw new ApiError(404);
  const rides = await Ride.findAll({ where: { driver_id: d.id }, limit: 50, order: [['created_at','DESC']],
    include: [{ association: 'customer', include: [{ association: 'user', attributes: ['full_name'] }] }] });
  return success(res, { rides });
}));

router.get('/rides', asyncHandler(async (req, res) => {
  const page = parseInt(req.query.page)||1, limit = parseInt(req.query.limit)||50;
  const where = {};
  if (req.query.status) where.status = req.query.status;
  const { rows, count } = await Ride.findAndCountAll({
    where,
    include: [
      { association: 'customer', include: [{ association: 'user', attributes: ['full_name','phone'] }] },
      { association: 'driver', include: [{ association: 'user', attributes: ['full_name','phone'] }] }
    ],
    order: [['created_at','DESC']],
    offset: (page-1)*limit, limit
  });
  return paginated(res, rows, count, page, limit);
}));

router.get('/rides/active', asyncHandler(async (req, res) => {
  const rides = await Ride.findAll({
    where: { status: { [Op.in]: ['driver_assigned','driver_arrived','started'] } },
    include: [
      { association: 'customer', include: [{ association: 'user', attributes: ['full_name'] }] },
      { association: 'driver', include: [{ association: 'user', attributes: ['full_name'] }, 'vehicle'] }
    ],
    order: [['created_at','DESC']]
  });
  return success(res, { rides });
}));

router.get('/settings/fare', asyncHandler(async (req, res) => {
  const s = await SystemSetting.findOne({ where: { key: 'fare_rates' } });
  const defaults = {
    single_base_fare: 30, single_per_km: 12, single_per_minute: 1,
    sharing_base_fare: 20, sharing_per_km: 8, sharing_per_minute: 0.5,
    minimum_fare: 30, night_charge_multiplier: 1.5, peak_multiplier: 1.2,
    night_start_hour: 22, night_end_hour: 6,
    peak_hours: [{ start: 8, end: 10 }, { start: 17, end: 20 }],
    cancellation_fee_customer: 10
  };
  return success(res, { fare_rates: { ...defaults, ...parseSetting(s, {}) } });
}));
router.put('/settings/fare', asyncHandler(async (req, res) => {
  const existing = parseSetting(await SystemSetting.findOne({ where: { key: 'fare_rates' } }), {});
  await saveSetting('fare_rates', { ...existing, ...req.body });
  return success(res, null, 'Fare updated');
}));
router.get('/settings/registration-fee', asyncHandler(async (req, res) => {
  const s = await SystemSetting.findOne({ where: { key: 'registration_fee' } });
  return success(res, { registration_fee: parseSetting(s, {}) });
}));
router.put('/settings/registration-fee', asyncHandler(async (req, res) => {
  const v = { standard: req.body.standard||999, promotional: req.body.promotional||499, promotion_active: req.body.promotion_active!==undefined ? req.body.promotion_active : true };
  await saveSetting('registration_fee', v);
  return success(res, { registration_fee: v }, 'Updated');
}));
// ---------------------------------------------------------------------------
// Backfill earnings for rides completed BEFORE the accrual code existed.
//
// Until the commission system shipped, completing a ride only changed its
// status - it never touched total_earnings, total_rides or commission_due,
// and never created a Payment row. Historic rides therefore show correct
// per-ride figures while every driver total reads 0.
//
// This recomputes those totals from the rides table itself, so it is safe to
// run more than once: it always rebuilds from source data rather than adding
// to whatever is already there.
// ---------------------------------------------------------------------------
router.post('/backfill-earnings', asyncHandler(async (req, res) => {
  const { Payment } = require('../models');

  const completed = await Ride.findAll({
    where: { status: 'completed' },
    attributes: ['id', 'ride_number', 'customer_id', 'driver_id', 'total_fare',
                 'driver_earnings', 'commission_amount', 'payment_method', 'ride_completed_at'],
  });

  // Rebuild each driver's totals from their completed rides.
  const byDriver = {};
  for (const r of completed) {
    if (!r.driver_id) continue;
    if (!byDriver[r.driver_id]) byDriver[r.driver_id] = { rides: 0, earnings: 0, commission: 0 };
    byDriver[r.driver_id].rides += 1;
    byDriver[r.driver_id].earnings += parseFloat(r.driver_earnings || 0);
    byDriver[r.driver_id].commission += parseFloat(r.commission_amount || 0);
  }

  const drivers = [];
  for (const driverId of Object.keys(byDriver)) {
    const d = await Driver.findByPk(driverId, { include: [{ association: 'user', attributes: ['full_name'] }] });
    if (!d) continue;
    const t = byDriver[driverId];

    // Commission already settled stays settled - only the unpaid remainder
    // becomes due, so a backfill never re-bills a driver.
    const alreadyPaid = parseFloat(d.total_commission_paid || 0);
    const stillDue = Math.max(0, parseFloat((t.commission - alreadyPaid).toFixed(2)));

    d.total_rides = t.rides;
    d.total_earnings = parseFloat(t.earnings.toFixed(2));
    d.commission_due = stillDue;
    await d.save();

    drivers.push({
      driver_id: d.id,
      name: d.user?.full_name || null,
      total_rides: d.total_rides,
      total_earnings: parseFloat(d.total_earnings),
      commission_earned: parseFloat(t.commission.toFixed(2)),
      already_paid: alreadyPaid,
      commission_due: stillDue,
    });
  }

  // Create any missing Payment rows so revenue reporting has data.
  let paymentsCreated = 0;
  for (const r of completed) {
    const existing = await Payment.findOne({ where: { ride_id: r.id } });
    if (existing) continue;
    try {
      await Payment.create({
        ride_id: r.id,
        customer_id: r.customer_id,
        driver_id: r.driver_id,
        amount: parseFloat(r.total_fare || 0),
        payment_method: r.payment_method || 'cash',
        status: 'completed',
        created_at: r.ride_completed_at || new Date(),
      });
      paymentsCreated++;
    } catch (e) { /* skip rows that cannot be created */ }
  }

  return success(res, {
    completed_rides: completed.length,
    drivers_updated: drivers.length,
    payments_created: paymentsCreated,
    drivers,
  }, 'Backfill complete');
}));

// ---------------------------------------------------------------------------
// Commission settlements
// ---------------------------------------------------------------------------

// All settlements, newest first. ?status=pending to see what needs reviewing.
router.get('/commission/payments', asyncHandler(async (req, res) => {
  const { CommissionPayment } = require('../models');
  const where = {};
  if (req.query.status) where.status = req.query.status;
  const rows = await CommissionPayment.findAll({
    where,
    include: [{
      association: 'driver',
      include: [{ association: 'user', attributes: ['full_name', 'phone'] }],
    }],
    order: [['created_at', 'DESC']],
    limit: parseInt(req.query.limit) || 100,
  });
  return success(res, { payments: rows }, 'Commission payments');
}));

// Who currently owes money.
router.get('/commission/outstanding', asyncHandler(async (req, res) => {
  const drivers = await Driver.findAll({
    where: { commission_due: { [Op.gt]: 0 } },
    include: [{ association: 'user', attributes: ['full_name', 'phone'] }],
    order: [['commission_due', 'DESC']],
    limit: 200,
  });
  const total = drivers.reduce((sum, d) => sum + parseFloat(d.commission_due || 0), 0);
  return success(res, {
    total_outstanding: parseFloat(total.toFixed(2)),
    drivers: drivers.map(d => ({
      driver_id: d.id,
      name: d.user?.full_name || null,
      phone: d.user?.phone || null,
      commission_due: parseFloat(d.commission_due || 0),
      total_earnings: parseFloat(d.total_earnings || 0),
      total_commission_paid: parseFloat(d.total_commission_paid || 0),
      is_online: d.is_online,
    })),
  }, 'Outstanding commission');
}));

// Confirm the money actually arrived. THIS is what clears the driver's dues.
router.post('/commission/payments/:id/confirm', asyncHandler(async (req, res) => {
  const { CommissionPayment } = require('../models');
  const payment = await CommissionPayment.findByPk(req.params.id);
  if (!payment) throw new ApiError(404, 'Payment not found');
  if (payment.status !== 'pending') throw new ApiError(400, 'This payment was already ' + payment.status);

  const driver = await Driver.findByPk(payment.driver_id);
  if (!driver) throw new ApiError(404, 'Driver not found');

  const amount = parseFloat(payment.amount);
  const due = parseFloat(driver.commission_due || 0);
  // Never let the balance go negative if dues changed after submission.
  const applied = Math.min(amount, due);

  driver.commission_due = parseFloat((due - applied).toFixed(2));
  driver.total_commission_paid = parseFloat(
    (parseFloat(driver.total_commission_paid || 0) + applied).toFixed(2)
  );
  await driver.save();

  payment.status = 'confirmed';
  payment.reviewed_at = new Date();
  payment.reviewed_by = req.userId;
  await payment.save();

  return success(res, {
    payment,
    commission_due: driver.commission_due,
    total_commission_paid: driver.total_commission_paid,
  }, 'Payment confirmed');
}));

// Reject a claimed payment that never arrived. Dues stay untouched.
router.post('/commission/payments/:id/reject', asyncHandler(async (req, res) => {
  const { CommissionPayment } = require('../models');
  const payment = await CommissionPayment.findByPk(req.params.id);
  if (!payment) throw new ApiError(404, 'Payment not found');
  if (payment.status !== 'pending') throw new ApiError(400, 'This payment was already ' + payment.status);

  payment.status = 'rejected';
  payment.rejection_reason = (req.body.reason || 'Payment not received').toString();
  payment.reviewed_at = new Date();
  payment.reviewed_by = req.userId;
  await payment.save();

  return success(res, { payment }, 'Payment rejected');
}));

// Manually adjust a driver's dues (corrections, waivers, offline settlement).
router.post('/commission/adjust/:driverId', asyncHandler(async (req, res) => {
  const driver = await Driver.findByPk(req.params.driverId);
  if (!driver) throw new ApiError(404, 'Driver not found');
  const amount = parseFloat(req.body.amount);
  if (!Number.isFinite(amount)) throw new ApiError(400, 'A numeric amount is required');
  const next = parseFloat(driver.commission_due || 0) + amount;
  driver.commission_due = parseFloat(Math.max(0, next).toFixed(2));
  await driver.save();
  return success(res, { commission_due: driver.commission_due }, 'Commission adjusted');
}));

router.get('/settings/commission', asyncHandler(async (req, res) => {
  const s = await SystemSetting.findOne({ where: { key: 'commission' } });
  return success(res, { commission: parseSetting(s, { rate: 10, block_threshold: 20 }) });
}));
router.put('/settings/commission', asyncHandler(async (req, res) => {
  const cur = parseSetting(await SystemSetting.findOne({ where: { key: 'commission' } }), {});
  await saveSetting('commission', { ...cur, ...req.body });
  return success(res, null, 'Updated');
}));

router.get('/registration-payments', asyncHandler(async (req, res) => {
  const p = parseInt(req.query.page)||1, l = parseInt(req.query.limit)||20;
  const { rows, count } = await DriverRegistrationPayment.findAndCountAll({
    include: [{ association: 'driver', include: [{ association: 'user', attributes: ['full_name','phone'] }] }],
    order: [['created_at','DESC']], offset: (p-1)*l, limit: l
  });
  return paginated(res, rows, count, p, l);
}));

router.get('/revenue', asyncHandler(async (req, res) => {
  const days = parseInt(req.query.days)||30;
  const since = new Date(); since.setDate(since.getDate()-days);
  const payments = await Payment.findAll({
    where: { created_at: { [Op.gte]: since } },
    attributes: [[literal('DATE(created_at)'),'date'],[literal('SUM(amount)'),'total_revenue'],[literal('COUNT(*)'),'count']],
    group: [literal('DATE(created_at)')], order: [[literal('DATE(created_at)'),'ASC']], raw: true
  });
  return success(res, { daily: payments, totals: { total: payments.reduce((s,x)=>s+parseFloat(x.total_revenue||0),0) } });
}));

router.get('/promo-codes', asyncHandler(async (req, res) => {
  const codes = await PromoCode.findAll({ order: [['created_at','DESC']] });
  return success(res, { promo_codes: codes });
}));
router.post('/promo-codes', asyncHandler(async (req, res) => {
  const a = await AdminUser.findOne({ where: { user_id: req.userId } });
  const data = {
    code: req.body.code,
    discount: req.body.discount_value || req.body.discount || 10,
    discount_type: req.body.discount_type || 'percentage',
    status: 'active',
    expiry_date: req.body.expires_at || req.body.expiry_date || null,
  };
  const p = await PromoCode.create(data);
  return success(res, { promo_code: p }, 'Created');
}));
router.put('/promo-codes/:id', asyncHandler(async (req, res) => {
  await PromoCode.update(req.body, { where: { id: req.params.id } });
  const p = await PromoCode.findByPk(req.params.id);
  return success(res, { promo_code: p }, 'Updated');
}));
router.delete('/promo-codes/:id', asyncHandler(async (req, res) => {
  await PromoCode.destroy({ where: { id: req.params.id } });
  return success(res, null, 'Deleted');
}));

router.get('/support-tickets', asyncHandler(async (req, res) => {
  const w = {}; if (req.query.status) w.status = req.query.status;
  const t = await SupportTicket.findAll({
    where: w,
    include: [{ association: 'user', attributes: ['id','full_name','phone'] }, { association: 'messages', limit: 1, order: [['created_at','DESC']] }],
    order: [['created_at','DESC']]
  });
  return success(res, { tickets: t });
}));
router.put('/support-tickets/:id', asyncHandler(async (req, res) => {
  const t = await SupportTicket.findByPk(req.params.id);
  if (!t) throw new ApiError(404);
  if (req.body.status) t.status = req.body.status;
  if (req.body.priority) t.priority = req.body.priority;
  if (req.body.status === 'resolved') t.resolved_at = new Date();
  await t.save();
  return success(res, { ticket: t }, 'Updated');
}));

// ---------------------------------------------------------------------------
// Push diagnostics.
//
// Answers, without ever exposing the private key:
//   - are the Firebase credentials set on this server at all?
//   - WHICH Firebase project do they belong to?
//   - how many users actually have an FCM token stored?
// ---------------------------------------------------------------------------
router.get('/push/status', asyncHandler(async (req, res) => {
  const { getStatus } = require('../services/FirebaseService');
  const status = getStatus();

  const totalUsers = await User.count({ where: { is_active: true } });
  const withToken = await User.count({ where: { is_active: true, fcm_token: { [Op.ne]: null } } });

  const drivers = await Driver.findAll({
    include: [{ association: 'user', attributes: ['id', 'full_name', 'fcm_token'] }],
    limit: 50,
  });
  const customers = await Customer.findAll({
    include: [{ association: 'user', attributes: ['id', 'full_name', 'fcm_token'] }],
    limit: 50,
  });

  const shape = (rows) => rows.map(r => ({
    name: r.user?.full_name || null,
    has_token: !!r.user?.fcm_token,
    token_preview: r.user?.fcm_token ? String(r.user.fcm_token).slice(0, 14) + '...' : null,
  }));

  return success(res, {
    firebase: status,
    tokens: { active_users: totalUsers, with_fcm_token: withToken },
    drivers: shape(drivers),
    customers: shape(customers),
  }, 'Push status');
}));

// Send a real test push to one user, and report exactly what happened.
router.post('/push/test/:userId', asyncHandler(async (req, res) => {
  const { sendPushDetailed } = require('../services/FirebaseService');
  const result = await sendPushDetailed(
    req.params.userId,
    req.body.title || 'Vybe test',
    req.body.message || 'Push notifications are working.',
    { type: 'admin_test' }
  );
  return success(res, result, result.ok ? 'Test push sent' : 'Test push failed: ' + result.reason);
}));

// Broadcast a notification.
//
// This used to only COUNT matching users and return that number as "sent" -
// it never contacted Firebase, so the admin saw "Broadcast sent" while every
// phone stayed silent. It now actually delivers and reports real figures.
router.post('/notifications/broadcast', asyncHandler(async (req, res) => {
  const title = (req.body.title || '').toString().trim();
  const message = (req.body.message || req.body.body || '').toString().trim();
  if (!title || !message) throw new ApiError(400, 'Title and message are required');

  const ids = [];
  if (req.body.target_role === 'all') {
    const u = await User.findAll({ where: { is_active: true }, attributes: ['id'] });
    ids.push(...u.map(x => x.id));
  } else if (req.body.target_role === 'drivers') {
    const d = await Driver.findAll({ include: [{ association: 'user', where: { is_active: true }, attributes: ['id'] }] });
    ids.push(...d.map(x => x.user_id));
  } else if (req.body.target_role === 'customers') {
    const c = await Customer.findAll({ include: [{ association: 'user', where: { is_active: true }, attributes: ['id'] }] });
    ids.push(...c.map(x => x.user_id));
  }

  const { sendPushNotification } = require('../services/FirebaseService');
  const { Notification } = require('../models');

  let delivered = 0;
  let failed = 0;
  for (const userId of ids) {
    // Always store it so the user can see it in-app even if push is off.
    try {
      await Notification.create({
        user_id: userId,
        title,
        message,
        type: 'admin_broadcast',
      });
    } catch (e) { /* notification row is best-effort */ }

    try {
      const ok = await sendPushNotification(userId, title, message, { type: 'admin_broadcast' });
      if (ok) delivered++; else failed++;
    } catch (e) {
      failed++;
    }
  }

  return success(
    res,
    { targeted: ids.length, delivered, failed },
    `Broadcast: ${delivered} delivered, ${failed} could not be reached`
  );
}));

router.get('/settings', asyncHandler(async (req, res) => {
  const all = await SystemSetting.findAll();
  const f = {}; all.forEach(s => { f[s.key] = s.value; });
  return success(res, { settings: f });
}));

// Fast2SMS Settings
router.get('/settings/fast2sms', asyncHandler(async (req, res) => {
  const s = await SystemSetting.findOne({ where: { key: 'fast2sms_api_key' } });
  return success(res, { api_key: s?.value ? s.value.substring(0, 10) + '...' : '', configured: !!s?.value });
}));
router.put('/settings/fast2sms', asyncHandler(async (req, res) => {
  if (!req.body.api_key || req.body.api_key.length < 10) throw new ApiError(400, 'Invalid API key');
  await saveSetting('fast2sms_api_key', String(req.body.api_key || ''));
  return success(res, null, 'Fast2SMS API key saved! SMS OTP will now be sent.');
}));

router.get('/audit-logs', asyncHandler(async (req, res) => {
  const p = parseInt(req.query.page)||1, l = parseInt(req.query.limit)||50;
  const { rows, count } = await AuditLog.findAndCountAll({ order: [['created_at','DESC']], offset: (p-1)*l, limit: l });
  return paginated(res, rows, count, p, l);
}));

// Admin Reports - JSON data (for PDF generation)
router.get('/reports-data/:type', asyncHandler(async (req, res) => {
  const { type } = req.params;
  const days = parseInt(req.query.days) || 30;
  const startDate = req.query.start ? new Date(req.query.start) : new Date(Date.now() - days * 24 * 60 * 60 * 1000);
  const endDate = req.query.end ? new Date(req.query.end) : new Date();
  
  let data = [];
  if (type === 'customers') {
    const customers = await Customer.findAll({
      include: [{ association: 'user', attributes: ['full_name', 'phone', 'email', 'created_at'] }],
      order: [['created_at', 'DESC']],
    });
    data = customers.map(c => ({
      name: c.user?.full_name || '',
      phone: c.user?.phone || '',
      email: c.user?.email || '',
      rides: c.total_rides || 0,
      spent: c.total_spent || 0,
      rating: c.rating || 0,
      joined: c.created_at ? new Date(c.created_at).toLocaleDateString() : '',
    }));
  } else if (type === 'drivers') {
    const drivers = await Driver.findAll({
      include: [{ association: 'user', attributes: ['full_name', 'phone', 'email'] }, 'vehicle'],
      order: [['created_at', 'DESC']],
    });
    data = drivers.map(d => ({
      name: d.user?.full_name || '',
      phone: d.user?.phone || '',
      email: d.user?.email || '',
      status: d.registration_status,
      rides: d.total_rides || 0,
      earnings: d.total_earnings || 0,
      vehicle: d.vehicle?.vehicle_number || 'N/A',
      joined: d.created_at ? new Date(d.created_at).toLocaleDateString() : '',
    }));
  } else if (type === 'rides') {
    const where = { created_at: { [Op.gte]: startDate, [Op.lte]: endDate } };
    const rides = await Ride.findAll({
      where,
      include: [{ association: 'customer', include: [{ association: 'user', attributes: ['full_name'] }] },
                { association: 'driver', include: [{ association: 'user', attributes: ['full_name'] }] }],
      order: [['created_at', 'DESC']], limit: 1000,
    });
    data = rides.map(r => ({
      ride_number: r.ride_number,
      customer: r.customer?.user?.full_name || 'N/A',
      driver: r.driver?.user?.full_name || 'N/A',
      pickup: r.pickup_address || '',
      drop: r.drop_address || '',
      status: r.status,
      fare: r.total_fare || 0,
      date: r.created_at ? new Date(r.created_at).toLocaleDateString() : '',
    }));
  } else if (type === 'revenue') {
    const where = { created_at: { [Op.gte]: startDate, [Op.lte]: endDate } };
    const payments = await Payment.findAll({
      where,
      include: [{ association: 'ride', attributes: ['ride_number'] }],
      order: [['created_at', 'DESC']],
    });
    const total = payments.reduce((s, p) => s + parseFloat(p.amount || 0), 0);
    data = {
      total_revenue: total,
      count: payments.length,
      payments: payments.map(p => ({
        ride_number: p.ride?.ride_number || 'N/A',
        amount: p.amount || 0,
        method: p.payment_method || 'N/A',
        status: p.status || 'N/A',
        date: p.created_at ? new Date(p.created_at).toLocaleDateString() : '',
      })),
    };
  }
  
  return success(res, { data, type, period: { from: startDate, to: endDate } });
}));

// Admin Reports - HTML/PDF printable view
router.get('/reports-pdf/:type', asyncHandler(async (req, res) => {
  const { type } = req.params;
  const days = parseInt(req.query.days) || 30;
  const startDate = req.query.start ? new Date(req.query.start) : new Date(Date.now() - days * 24 * 60 * 60 * 1000);
  const endDate = req.query.end ? new Date(req.query.end) : new Date();
  
  let rows = '';
  let title = type.charAt(0).toUpperCase() + type.slice(1);
  
  if (type === 'customers') {
    const customers = await Customer.findAll({
      include: [{ association: 'user', attributes: ['full_name', 'phone', 'email', 'created_at'] }],
      order: [['created_at', 'DESC']],
    });
    rows = '<table><tr><th>Name</th><th>Phone</th><th>Email</th><th>Rides</th><th>Spent</th><th>Rating</th><th>Joined</th></tr>';
    customers.forEach(c => {
      rows += `<tr><td>${c.user?.full_name || ''}</td><td>${c.user?.phone || ''}</td><td>${c.user?.email || ''}</td><td>${c.total_rides || 0}</td><td>₹${c.total_spent || 0}</td><td>${c.rating || 0}</td><td>${new Date(c.created_at).toLocaleDateString()}</td></tr>`;
    });
    rows += '</table>';
  } else if (type === 'drivers') {
    const drivers = await Driver.findAll({
      include: [{ association: 'user', attributes: ['full_name', 'phone', 'email'] }, 'vehicle'],
      order: [['created_at', 'DESC']],
    });
    rows = '<table><tr><th>Name</th><th>Phone</th><th>Email</th><th>Status</th><th>Rides</th><th>Earnings</th><th>Vehicle</th><th>Joined</th></tr>';
    drivers.forEach(d => {
      rows += `<tr><td>${d.user?.full_name || ''}</td><td>${d.user?.phone || ''}</td><td>${d.user?.email || ''}</td><td>${d.registration_status}</td><td>${d.total_rides || 0}</td><td>₹${d.total_earnings || 0}</td><td>${d.vehicle?.vehicle_number || 'N/A'}</td><td>${new Date(d.created_at).toLocaleDateString()}</td></tr>`;
    });
    rows += '</table>';
  } else if (type === 'rides') {
    const where = { created_at: { [Op.gte]: startDate, [Op.lte]: endDate } };
    const rides = await Ride.findAll({
      where,
      include: [{ association: 'customer', include: [{ association: 'user', attributes: ['full_name'] }] },
                { association: 'driver', include: [{ association: 'user', attributes: ['full_name'] }] }],
      order: [['created_at', 'DESC']], limit: 1000,
    });
    rows = '<table><tr><th>Ride #</th><th>Customer</th><th>Driver</th><th>Pickup</th><th>Drop</th><th>Status</th><th>Fare</th><th>Date</th></tr>';
    rides.forEach(r => {
      rows += `<tr><td>${r.ride_number}</td><td>${r.customer?.user?.full_name || 'N/A'}</td><td>${r.driver?.user?.full_name || 'N/A'}</td><td>${(r.pickup_address || '').replace(/"/g,'""')}</td><td>${(r.drop_address || '').replace(/"/g,'""')}</td><td>${r.status}</td><td>₹${r.total_fare || 0}</td><td>${new Date(r.created_at).toLocaleDateString()}</td></tr>`;
    });
    rows += '</table>';
  } else if (type === 'revenue') {
    const where = { created_at: { [Op.gte]: startDate, [Op.lte]: endDate } };
    const payments = await Payment.findAll({
      where,
      include: [{ association: 'ride', attributes: ['ride_number'] }],
      order: [['created_at', 'DESC']],
    });
    const total = payments.reduce((s, p) => s + parseFloat(p.amount || 0), 0);
    rows = `<h2>Total Revenue: ₹${total.toFixed(2)}</h2><h3>Transactions: ${payments.length}</h3>`;
    rows += '<table><tr><th>Ride #</th><th>Amount</th><th>Method</th><th>Status</th><th>Date</th></tr>';
    payments.forEach(p => {
      rows += `<tr><td>${p.ride?.ride_number || 'N/A'}</td><td>₹${p.amount || 0}</td><td>${p.payment_method || 'N/A'}</td><td>${p.status || 'N/A'}</td><td>${new Date(p.created_at).toLocaleDateString()}</td></tr>`;
    });
    rows += '</table>';
  }

  const html = `<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>${title} Report - Vybe Admin</title>
<style>
  body { font-family: Arial; padding: 20px; color: #333; }
  h1 { color: #6C63FF; }
  .meta { color: #666; margin-bottom: 20px; }
  table { width: 100%; border-collapse: collapse; font-size: 13px; }
  th { background: #6C63FF; color: white; padding: 8px; text-align: left; }
  td { padding: 6px 8px; border-bottom: 1px solid #ddd; }
  tr:nth-child(even) { background: #f9f9f9; }
  @media print { body { padding: 0; } }
</style></head><body>
<h1>Vybe - ${title} Report</h1>
<p class="meta">Period: ${startDate.toLocaleDateString()} - ${endDate.toLocaleDateString()} | Generated: ${new Date().toLocaleString()}</p>
${rows}
<p style="margin-top:20px;color:#999;font-size:11px;">Vybe Admin Platform - Confidential</p>
</body></html>`;

  const format = req.query.format || 'html';
  if (format === 'html') {
    res.setHeader('Content-Type', 'text/html');
    res.send(html);
  } else {
    // Return JSON with HTML content for frontend to use window.print()
    return success(res, { html, title });
  }
}));

// Admin Reports - Export CSV
router.get('/reports/customers', asyncHandler(async (req, res) => {
  const { Op } = require('sequelize');
  const customers = await Customer.findAll({
    include: [{ association: 'user', attributes: ['full_name', 'phone', 'email', 'created_at'] }],
    order: [['created_at', 'DESC']],
  });

  let csv = 'Name,Phone,Email,Rides,Spent,Rating,Joined\n';
  customers.forEach(c => {
    csv += `"${c.user?.full_name || ''}","${c.user?.phone || ''}","${c.user?.email || ''}",${c.total_rides || 0},${c.total_spent || 0},${c.rating || 0},"${new Date(c.created_at).toLocaleDateString()}"\n`;
  });

  res.setHeader('Content-Type', 'text/csv');
  res.setHeader('Content-Disposition', 'attachment; filename=customers.csv');
  res.send(csv);
}));

router.get('/reports/drivers', asyncHandler(async (req, res) => {
  const drivers = await Driver.findAll({
    include: [
      { association: 'user', attributes: ['full_name', 'phone', 'email'] },
      'vehicle',
    ],
    order: [['created_at', 'DESC']],
  });

  let csv = 'Name,Phone,Email,Status,Rides,Earnings,Vehicle,Joined\n';
  drivers.forEach(d => {
    csv += `"${d.user?.full_name || ''}","${d.user?.phone || ''}","${d.user?.email || ''}","${d.registration_status}",${d.total_rides || 0},${d.total_earnings || 0},"${d.vehicle?.vehicle_number || 'N/A'}","${new Date(d.created_at).toLocaleDateString()}"\n`;
  });

  res.setHeader('Content-Type', 'text/csv');
  res.setHeader('Content-Disposition', 'attachment; filename=drivers.csv');
  res.send(csv);
}));

router.get('/reports/rides', asyncHandler(async (req, res) => {
  const rides = await Ride.findAll({
    include: [
      { association: 'customer', include: [{ association: 'user', attributes: ['full_name'] }] },
      { association: 'driver', include: [{ association: 'user', attributes: ['full_name'] }] },
    ],
    order: [['created_at', 'DESC']],
    limit: 1000,
  });

  let csv = 'Ride #,Customer,Driver,Pickup,Drop,Status,Fare,Date\n';
  rides.forEach(r => {
    csv += `"${r.ride_number}","${r.customer?.user?.full_name || 'N/A'}","${r.driver?.user?.full_name || 'N/A'}","${(r.pickup_address || '').replace(/"/g,'""')}","${(r.drop_address || '').replace(/"/g,'""')}","${r.status}",${r.total_fare || 0},"${new Date(r.created_at).toLocaleDateString()}"\n`;
  });

  res.setHeader('Content-Type', 'text/csv');
  res.setHeader('Content-Disposition', 'attachment; filename=rides.csv');
  res.send(csv);
}));

router.get('/reports/revenue', asyncHandler(async (req, res) => {
  const days = parseInt(req.query.days) || 30;
  const since = new Date();
  since.setDate(since.getDate() - days);

  const payments = await Payment.findAll({
    where: { created_at: { [Op.gte]: since } },
    include: [
      { association: 'ride', attributes: ['ride_number'] },
    ],
    order: [['created_at', 'DESC']],
  });

  let csv = 'Ride #,Amount,Method,Status,Date\n';
  payments.forEach(p => {
    csv += `"${p.ride?.ride_number || 'N/A'}",${p.amount || 0},${p.payment_method || 'N/A'},${p.status || 'N/A'},"${new Date(p.created_at).toLocaleDateString()}"\n`;
  });

  res.setHeader('Content-Type', 'text/csv');
  res.setHeader('Content-Disposition', 'attachment; filename=revenue.csv');
  res.send(csv);
}));

// ---------------------------------------------------------------------------
// Delete a specific customer (restored - was removed in commit 541046c)
//
// There are NO onDelete:CASCADE rules on any association in this project, so
// Postgres will refuse to delete a row that still has children pointing at it.
// The original version of this route only did c.destroy() + User.destroy(),
// which is why it started failing the moment a customer had any rides,
// payments or wallet rows. Everything below runs inside one transaction and
// removes children first, deepest level outwards.
// ---------------------------------------------------------------------------
router.delete('/customers/:id', asyncHandler(async (req, res) => {
  const c = await Customer.findByPk(req.params.id);
  if (!c) throw new ApiError(404, 'Customer not found');
  const userId = c.user_id;

  await sequelize.transaction(async (t) => {
    const rides = await Ride.findAll({
      where: { customer_id: c.id }, attributes: ['id'], transaction: t,
    });
    const rideIds = rides.map(r => r.id);

    if (rideIds.length) {
      await RideStatusLog.destroy({ where: { ride_id: rideIds }, transaction: t });
      await ChatMessage.destroy({ where: { ride_id: rideIds }, transaction: t });
      await RatingReview.destroy({ where: { ride_id: rideIds }, transaction: t });
      await PromoRedemption.destroy({ where: { ride_id: rideIds }, transaction: t });
      await Payment.destroy({ where: { ride_id: rideIds }, transaction: t });
    }

    // Free any driver still pointing at one of these rides, otherwise that
    // driver is silently excluded from ride matching forever.
    if (rideIds.length) {
      await Driver.update(
        { is_available: true, current_ride_id: null },
        { where: { current_ride_id: rideIds }, transaction: t }
      );
    }

    await Payment.destroy({ where: { customer_id: c.id }, transaction: t });
    await Ride.destroy({ where: { customer_id: c.id }, transaction: t });
    await SavedPlace.destroy({ where: { customer_id: c.id }, transaction: t });
    await Referral.destroy({ where: { referrer_customer_id: c.id }, transaction: t });
    await Referral.destroy({ where: { referred_customer_id: c.id }, transaction: t });

    await c.destroy({ transaction: t });

    // User-level children. Only remove the user if they have no driver profile.
    const stillDriver = await Driver.findOne({ where: { user_id: userId }, transaction: t });
    if (!stillDriver) {
      await PromoRedemption.destroy({ where: { user_id: userId }, transaction: t });
      await Transaction.destroy({ where: { user_id: userId }, transaction: t });
      await Wallet.destroy({ where: { user_id: userId }, transaction: t });
      await Notification.destroy({ where: { user_id: userId }, transaction: t });

      const tickets = await SupportTicket.findAll({
        where: { user_id: userId }, attributes: ['id'], transaction: t,
      });
      const ticketIds = tickets.map(x => x.id);
      if (ticketIds.length) {
        await SupportTicketMessage.destroy({ where: { ticket_id: ticketIds }, transaction: t });
      }
      await SupportTicket.destroy({ where: { user_id: userId }, transaction: t });

      await User.destroy({ where: { id: userId }, transaction: t });
    }
  });

  return success(res, null, 'Customer deleted');
}));

// ---------------------------------------------------------------------------
// Delete a specific driver (restored - was removed in commit 541046c)
// ---------------------------------------------------------------------------
router.delete('/drivers/:id', asyncHandler(async (req, res) => {
  const d = await Driver.findByPk(req.params.id);
  if (!d) throw new ApiError(404, 'Driver not found');
  const userId = d.user_id;

  await sequelize.transaction(async (t) => {
    // Detach the driver from their rides rather than deleting the rides -
    // those rides belong to a customer and are part of that customer's history.
    await Ride.update(
      { driver_id: null },
      { where: { driver_id: d.id }, transaction: t }
    );
    await Payment.update(
      { driver_id: null },
      { where: { driver_id: d.id }, transaction: t }
    );

    await DriverDocument.destroy({ where: { driver_id: d.id }, transaction: t });
    await DriverRegistrationPayment.destroy({ where: { driver_id: d.id }, transaction: t });
    await Vehicle.destroy({ where: { driver_id: d.id }, transaction: t });

    await d.destroy({ transaction: t });

    const stillCustomer = await Customer.findOne({ where: { user_id: userId }, transaction: t });
    if (!stillCustomer) {
      await PromoRedemption.destroy({ where: { user_id: userId }, transaction: t });
      await Transaction.destroy({ where: { user_id: userId }, transaction: t });
      await Wallet.destroy({ where: { user_id: userId }, transaction: t });
      await Notification.destroy({ where: { user_id: userId }, transaction: t });

      const tickets = await SupportTicket.findAll({
        where: { user_id: userId }, attributes: ['id'], transaction: t,
      });
      const ticketIds = tickets.map(x => x.id);
      if (ticketIds.length) {
        await SupportTicketMessage.destroy({ where: { ticket_id: ticketIds }, transaction: t });
      }
      await SupportTicket.destroy({ where: { user_id: userId }, transaction: t });

      await User.destroy({ where: { id: userId }, transaction: t });
    }
  });

  return success(res, null, 'Driver deleted');
}));

module.exports = router;
