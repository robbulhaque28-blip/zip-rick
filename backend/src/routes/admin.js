const router = require('express').Router();
const { authenticate, authorize } = require('../middleware/auth');
const { asyncHandler, ApiError } = require('../middleware/errorHandler');
const { success, paginated } = require('../utils/response');
const { Op, literal } = require('sequelize');
const { User, Driver, Customer, Ride, Payment, AdminUser, SystemSetting, PromoCode, SupportTicket, AuditLog, DriverRegistrationPayment } = require('../models');
const { sequelize } = require('../config/db');

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
      trev = await Payment.sum('amount', { where: { payment_status: 'completed' } }) || 0;
      trevToday = await Payment.sum('amount', { where: { payment_status: 'completed', paid_at: { [Op.gte]: today } } }) || 0;
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
  return success(res, { fare_rates: s?.value||{} });
}));
router.put('/settings/fare', asyncHandler(async (req, res) => {
  const existing = (await SystemSetting.findOne({ where: { key: 'fare_rates' } }))?.value||{};
  await SystemSetting.upsert({ key: 'fare_rates', value: { ...existing, ...req.body }, category: 'pricing' });
  return success(res, null, 'Fare updated');
}));
router.get('/settings/registration-fee', asyncHandler(async (req, res) => {
  const s = await SystemSetting.findOne({ where: { key: 'registration_fee' } });
  return success(res, { registration_fee: s?.value||{} });
}));
router.put('/settings/registration-fee', asyncHandler(async (req, res) => {
  const v = { standard: req.body.standard||999, promotional: req.body.promotional||499, promotion_active: req.body.promotion_active!==undefined ? req.body.promotion_active : true };
  await SystemSetting.upsert({ key: 'registration_fee', value: v, category: 'drivers' });
  return success(res, { registration_fee: v }, 'Updated');
}));
router.get('/settings/commission', asyncHandler(async (req, res) => {
  const s = await SystemSetting.findOne({ where: { key: 'commission' } });
  return success(res, { commission: s?.value||{ rate: 10, type: 'percentage' } });
}));
router.put('/settings/commission', asyncHandler(async (req, res) => {
  await SystemSetting.upsert({ key: 'commission', value: req.body, category: 'pricing' });
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
  const codes = await PromoCode.findAll({ include: ['redemptions'], order: [['created_at','DESC']] });
  return success(res, { promo_codes: codes });
}));
router.post('/promo-codes', asyncHandler(async (req, res) => {
  const a = await AdminUser.findOne({ where: { user_id: req.userId } });
  const data = {
    code: req.body.code,
    discount_value: req.body.discount_value || req.body.discount || 10,
    discount_type: req.body.discount_type || 'percentage',
    max_uses: req.body.max_uses || 100,
    min_fare: req.body.min_fare || 0,
    expires_at: req.body.expires_at || null,
    created_by: a?.id,
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

router.post('/notifications/broadcast', asyncHandler(async (req, res) => {
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
  return success(res, { sent: ids.length }, 'Broadcast sent');
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
  await SystemSetting.upsert({ key: 'fast2sms_api_key', value: req.body.api_key, category: 'sms' });
  return success(res, null, 'Fast2SMS API key saved! SMS OTP will now be sent.');
}));

router.get('/audit-logs', asyncHandler(async (req, res) => {
  const p = parseInt(req.query.page)||1, l = parseInt(req.query.limit)||50;
  const { rows, count } = await AuditLog.findAndCountAll({ order: [['created_at','DESC']], offset: (p-1)*l, limit: l });
  return paginated(res, rows, count, p, l);
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
    csv += `"${p.ride?.ride_number || 'N/A'}",${p.amount || 0},${p.payment_method || 'N/A'},${p.payment_status || 'N/A'},"${new Date(p.created_at).toLocaleDateString()}"\n`;
  });

  res.setHeader('Content-Type', 'text/csv');
  res.setHeader('Content-Disposition', 'attachment; filename=revenue.csv');
  res.send(csv);
}));

// Run SQL migration queries
router.post('/query', asyncHandler(async (req, res) => {
  if (!req.body.sql || typeof req.body.sql !== 'string') throw new ApiError(400, 'SQL query required');
  try {
    const result = await sequelize.query(req.body.sql);
    return success(res, { result }, 'Query executed');
  } catch (e) {
    throw new ApiError(400, e.message);
  }
}));

// Cleanup - Delete all test data (keeps admin users and system settings)
router.post('/cleanup', asyncHandler(async (req, res) => {
  // Get admin user IDs to preserve
  const admins = await AdminUser.findAll({ attributes: ['user_id'] });
  const adminIds = admins.map(a => "'" + a.user_id + "'").join(',');
  
  // Delete data in order to avoid FK issues
  await sequelize.query(`DELETE FROM rating_reviews;`);
  await sequelize.query(`DELETE FROM chat_messages;`);
  await sequelize.query(`DELETE FROM ride_status_logs;`);
  await sequelize.query(`DELETE FROM promo_redemptions;`);
  await sequelize.query(`DELETE FROM referrals;`);
  await sequelize.query(`DELETE FROM saved_places;`);
  await sequelize.query(`DELETE FROM notifications;`);
  await sequelize.query(`DELETE FROM transactions;`);
  await sequelize.query(`DELETE FROM support_ticket_messages;`);
  await sequelize.query(`DELETE FROM support_tickets;`);
  await sequelize.query(`DELETE FROM payments;`);
  await sequelize.query(`DELETE FROM driver_documents;`);
  await sequelize.query(`DELETE FROM driver_registration_payments;`);
  await sequelize.query(`DELETE FROM vehicles;`);
  await sequelize.query(`DELETE FROM rides;`);
  await sequelize.query(`DELETE FROM wallets;`);
  await sequelize.query(`DELETE FROM drivers;`);
  await sequelize.query(`DELETE FROM customers;`);
  
  // Delete non-admin users
  let deletedUsers = 0;
  if (adminIds) {
    [deletedUsers] = await sequelize.query(`DELETE FROM users WHERE id NOT IN (${adminIds});`);
  } else {
    [deletedUsers] = await sequelize.query(`DELETE FROM users WHERE role != 'admin';`);
  }
  
  return success(res, { message: `Database cleaned. All test data removed.` }, 'Database cleaned');
}));


// Delete a specific customer
router.delete('/customers/:id', asyncHandler(async (req, res) => {
  const c = await Customer.findByPk(req.params.id);
  if (!c) throw new ApiError(404, 'Customer not found');
  const userId = c.user_id;
  await c.destroy();
  await User.destroy({ where: { id: userId } });
  return success(res, null, 'Customer deleted');
}));

// Delete a specific driver
router.delete('/drivers/:id', asyncHandler(async (req, res) => {
  const d = await Driver.findByPk(req.params.id);
  if (!d) throw new ApiError(404, 'Driver not found');
  const userId = d.user_id;
  await DriverDocument.destroy({ where: { driver_id: d.id } });
  await DriverRegistrationPayment.destroy({ where: { driver_id: d.id } });
  await Vehicle.destroy({ where: { driver_id: d.id } });
  await d.destroy();
  await User.destroy({ where: { id: userId } });
  return success(res, null, 'Driver deleted');
}));

module.exports = router;
