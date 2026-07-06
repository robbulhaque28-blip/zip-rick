/**
 * Admin Routes - Full management dashboard backend
 */
const router = require('express').Router();
const { authenticate, authorize } = require('../middleware/auth');
const { asyncHandler, ApiError } = require('../middleware/errorHandler');
const { success, paginated } = require('../utils/response');
const { Op, literal } = require('sequelize');
const { User, Driver, Customer, Ride, Payment, DriverDocument, Vehicle, AdminUser, SystemSetting, PromoCode, SupportTicket, Transaction, AuditLog, DriverRegistrationPayment } = require('../models');
const bcrypt = require('bcryptjs');
const logger = require('../utils/logger');
router.use(authenticate); router.use(authorize('admin'));

// Dashboard
router.get('/dashboard', asyncHandler(async (req, res) => {
  const today = new Date(); today.setHours(0,0,0,0);
  const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);
  const [totalC, totalD, pendingD, totalR, activeR, todayR, totalRev, todayRev, monthRev] = await Promise.all([
    Customer.count(), Driver.count(), Driver.count({ where: { registration_status: 'pending' } }),
    Ride.count(), Ride.count({ where: { status: { [Op.in]: ['searching','driver_assigned','driver_arrived','started'] } } }),
    Ride.count({ where: { created_at: { [Op.gte]: today } } }),
    Payment.sum('amount', { where: { payment_status: 'completed' } }),
    Payment.sum('amount', { where: { payment_status: 'completed', paid_at: { [Op.gte]: today } } }),
    Payment.sum('amount', { where: { payment_status: 'completed', paid_at: { [Op.gte]: monthStart } } }),
  ]);
  return success(res, { overview: { total_customers: totalC||0, total_drivers: totalD||0, pending_drivers: pendingD||0, total_rides: totalR||0, active_rides: activeR||0, revenue: { total: totalRev||0, today: todayRev||0, this_month: monthRev||0 } } });
}));

// Drivers management
router.get('/drivers', asyncHandler(async (req, res) => {
  const page = parseInt(req.query.page)||1, limit = parseInt(req.query.limit)||20;
  const where = {}; if (req.query.status) where.registration_status = req.query.status;
  if (req.query.search) where[Op.or] = [{ '$user.full_name$': { [Op.iLike]: `%${req.query.search}%` } }, { '$user.phone$': { [Op.iLike]: `%${req.query.search}%` } }];
  const { rows, count } = await Driver.findAndCountAll({ where, include: [{ association: 'user', attributes: ['id','full_name','phone','email','avatar_url','is_active','created_at'] }, 'vehicle', 'documents'], order: [['created_at','DESC']], offset: (page-1)*limit, limit });
  return paginated(res, rows, count, page, limit);
}));
router.get('/drivers/:id', asyncHandler(async (req, res) => {
  const d = await Driver.findByPk(req.params.id, { include: [{ association: 'user', attributes: ['id','full_name','phone','email','is_active','is_blocked'] }, 'vehicle', 'documents', 'registrationPayments'] });
  if (!d) throw new ApiError(404, 'Not found'); return success(res, { driver: d });
}));
router.post('/drivers/:id/approve', asyncHandler(async (req, res) => {
  const admin = await AdminUser.findOne({ where: { user_id: req.userId } });
  const d = await Driver.findByPk(req.params.id); if (!d) throw new ApiError(404, 'Not found');
  d.registration_status = 'approved'; d.approved_by = admin.id; d.approved_at = new Date(); await d.save();
  await AuditLog.create({ user_id: req.userId, action: 'APPROVE_DRIVER', resource_type: 'driver', resource_id: d.id, new_values: { status: 'approved' } });
  return success(res, { driver: d }, 'Driver approved');
}));
router.post('/drivers/:id/reject', asyncHandler(async (req, res) => {
  const admin = await AdminUser.findOne({ where: { user_id: req.userId } });
  const d = await Driver.findByPk(req.params.id); if (!d) throw new ApiError(404, 'Not found');
  d.registration_status = 'rejected'; d.rejection_reason = req.body.reason || 'Documents rejected'; d.approved_by = admin.id; await d.save();
  await AuditLog.create({ user_id: req.userId, action: 'REJECT_DRIVER', resource_type: 'driver', resource_id: d.id, new_values: { status: 'rejected', reason: req.body.reason } });
  return success(res, { driver: d }, 'Driver rejected');
}));
router.post('/drivers/:id/suspend', asyncHandler(async (req, res) => {
  const d = await Driver.findByPk(req.params.id); if (!d) throw new ApiError(404, 'Not found');
  d.registration_status = 'suspended'; d.is_online = false; d.is_available = false; await d.save();
  return success(res, { driver: d }, 'Driver suspended');
}));

// Customers
router.get('/customers', asyncHandler(async (req, res) => {
  const page = parseInt(req.query.page)||1, limit = parseInt(req.query.limit)||20;
  const where = {}; if (req.query.search) where[Op.or] = [{ '$user.full_name$': { [Op.iLike]: `%${req.query.search}%` } }, { '$user.phone$': { [Op.iLike]: `%${req.query.search}%` } }];
  const { rows, count } = await Customer.findAndCountAll({ where, include: [{ association: 'user', attributes: ['id','full_name','phone','email','is_active','is_blocked','created_at'] }], order: [['created_at','DESC']], offset: (page-1)*limit, limit });
  return paginated(res, rows, count, page, limit);
}));

// Rides
router.get('/rides', asyncHandler(async (req, res) => {
  const page = parseInt(req.query.page)||1, limit = parseInt(req.query.limit)||20;
  const where = {}; if (req.query.status) where.status = req.query.status;
  const { rows, count } = await Ride.findAndCountAll({ where, include: [{ association: 'customer', include: [{ association: 'user', attributes: ['full_name','phone'] }] }, { association: 'driver', include: [{ association: 'user', attributes: ['full_name','phone'] }] }], order: [['created_at','DESC']], offset: (page-1)*limit, limit });
  return paginated(res, rows, count, page, limit);
}));
router.get('/rides/active', asyncHandler(async (req, res) => {
  const rides = await Ride.findAll({ where: { status: { [Op.in]: ['driver_assigned','driver_arrived','started'] } }, include: [{ association: 'customer', include: [{ association: 'user', attributes: ['full_name'] }] }, { association: 'driver', include: [{ association: 'user', attributes: ['full_name'] }, 'vehicle'] }], order: [['created_at','DESC']] });
  return success(res, { rides });
}));

// Settings
router.get('/settings/fare', asyncHandler(async (req, res) => {
  const s = await SystemSetting.findOne({ where: { key: 'fare_rates' } }); return success(res, { fare_rates: s?.value || {} });
}));
router.put('/settings/fare', asyncHandler(async (req, res) => {
  const admin = await AdminUser.findOne({ where: { user_id: req.userId } });
  const existing = await SystemSetting.findOne({ where: { key: 'fare_rates' } });
  const value = { ...existing?.value, ...req.body };
  await SystemSetting.upsert({ key: 'fare_rates', value, category: 'pricing', updated_by: admin?.id });
  return success(res, { fare_rates: value }, 'Fare updated');
}));
router.get('/settings/registration-fee', asyncHandler(async (req, res) => {
  const s = await SystemSetting.findOne({ where: { key: 'registration_fee' } }); return success(res, { registration_fee: s?.value || {} });
}));
router.put('/settings/registration-fee', asyncHandler(async (req, res) => {
  const value = { standard: req.body.standard||999, promotional: req.body.promotional||499, promotion_active: req.body.promotion_active !== undefined ? req.body.promotion_active : true };
  await SystemSetting.upsert({ key: 'registration_fee', value, category: 'drivers' });
  return success(res, { registration_fee: value }, 'Fee updated');
}));
router.get('/settings/commission', asyncHandler(async (req, res) => {
  const s = await SystemSetting.findOne({ where: { key: 'commission' } }); return success(res, { commission: s?.value || { rate: 10, type: 'percentage' } });
}));
router.put('/settings/commission', asyncHandler(async (req, res) => {
  await SystemSetting.upsert({ key: 'commission', value: req.body, category: 'pricing' }); return success(res, null, 'Commission updated');
}));

// Registration payments
router.get('/registration-payments', asyncHandler(async (req, res) => {
  const page = parseInt(req.query.page)||1, limit = parseInt(req.query.limit)||20;
  const { rows, count } = await DriverRegistrationPayment.findAndCountAll({ include: [{ association: 'driver', include: [{ association: 'user', attributes: ['full_name','phone'] }] }], order: [['created_at','DESC']], offset: (page-1)*limit, limit });
  return paginated(res, rows, count, page, limit);
}));

// Revenue
router.get('/revenue', asyncHandler(async (req, res) => {
  const days = parseInt(req.query.days)||30; const since = new Date(); since.setDate(since.getDate()-days);
  const payments = await Payment.findAll({ where: { payment_status: 'completed', paid_at: { [Op.gte]: since } }, attributes: [[literal('DATE(paid_at)'),'date'],[literal('SUM(amount)'),'total_revenue'],[literal('SUM(commission)'),'total_commission'],[literal('COUNT(*)'),'ride_count']], group: [literal('DATE(paid_at)')], order: [[literal('DATE(paid_at)'),'ASC']], raw: true });
  const totalRev = payments.reduce((s,p) => s + parseFloat(p.total_revenue||0), 0);
  const totalComm = payments.reduce((s,p) => s + parseFloat(p.total_commission||0), 0);
  return success(res, { daily: payments, totals: { total_revenue: totalRev, total_commission: totalComm } });
}));

// Promo codes
router.get('/promo-codes', asyncHandler(async (req, res) => {
  const codes = await PromoCode.findAll({ include: ['redemptions'], order: [['created_at','DESC']] }); return success(res, { promo_codes: codes });
}));
router.post('/promo-codes', asyncHandler(async (req, res) => {
  const admin = await AdminUser.findOne({ where: { user_id: req.userId } });
  const p = await PromoCode.create({ ...req.body, created_by: admin.id }); return success(res, { promo_code: p }, 'Created');
}));
router.put('/promo-codes/:id', asyncHandler(async (req, res) => {
  await PromoCode.update(req.body, { where: { id: req.params.id } }); const p = await PromoCode.findByPk(req.params.id); return success(res, { promo_code: p }, 'Updated');
}));
router.delete('/promo-codes/:id', asyncHandler(async (req, res) => {
  await PromoCode.destroy({ where: { id: req.params.id } }); return success(res, null, 'Deleted');
}));

// Support
router.get('/support-tickets', asyncHandler(async (req, res) => {
  const where = {}; if (req.query.status) where.status = req.query.status;
  const tickets = await SupportTicket.findAll({ where, include: [{ association: 'user', attributes: ['id','full_name','phone','role'] }, { association: 'messages', limit: 1, order: [['created_at','DESC']] }], order: [['created_at','DESC']] });
  return success(res, { tickets });
}));
router.put('/support-tickets/:id', asyncHandler(async (req, res) => {
  const t = await SupportTicket.findByPk(req.params.id); if (!t) throw new ApiError(404);
  if (req.body.status) t.status = req.body.status;
  if (req.body.priority) t.priority = req.body.priority;
  if (req.body.assigned_to) t.assigned_to = req.body.assigned_to;
  if (req.body.status === 'resolved') t.resolved_at = new Date(); await t.save(); return success(res, { ticket: t }, 'Updated');
}));

// Broadcast notification
router.post('/notifications/broadcast', asyncHandler(async (req, res) => {
  const { NotificationService } = require('../services/NotificationService');
  let userIds = [];
  if (req.body.target_role === 'all') { const users = await User.findAll({ where: { is_active: true }, attributes: ['id'] }); userIds = users.map(u => u.id); }
  else if (req.body.target_role === 'drivers') { const d = await Driver.findAll({ include: [{ association: 'user', where: { is_active: true }, attributes: ['id'] }] }); userIds = d.map(x => x.user_id); }
  else if (req.body.target_role === 'customers') { const c = await Customer.findAll({ include: [{ association: 'user', where: { is_active: true }, attributes: ['id'] }] }); userIds = c.map(x => x.user_id); }
  await NotificationService.sendBulkPush(userIds, req.body.title, req.body.body, {}, 'admin_broadcast');
  return success(res, { sent_to: userIds.length }, 'Broadcast sent');
}));

// Settings
router.get('/settings', asyncHandler(async (req, res) => {
  const all = await SystemSetting.findAll(); const formatted = {}; all.forEach(s => { formatted[s.key] = s.value; }); return success(res, { settings: formatted });
}));
router.put('/settings/:key', asyncHandler(async (req, res) => {
  const admin = await AdminUser.findOne({ where: { user_id: req.userId } });
  await SystemSetting.upsert({ key: req.params.key, value: req.body.value, description: req.body.description, category: req.body.category, updated_by: admin?.id });
  return success(res, null, 'Setting updated');
}));

// Audit logs
router.get('/audit-logs', asyncHandler(async (req, res) => {
  const page = parseInt(req.query.page)||1, limit = parseInt(req.query.limit)||50;
  const { rows, count } = await AuditLog.findAndCountAll({ order: [['created_at','DESC']], offset: (page-1)*limit, limit });
  return paginated(res, rows, count, page, limit);
}));

// Export
router.get('/export/:type', asyncHandler(async (req, res) => {
  const { type } = req.params; const { from, to } = req.query;
  const dateFilter = {}; if (from) dateFilter.created_at = { [Op.gte]: new Date(from) }; if (to) dateFilter.created_at = { ...dateFilter.created_at, [Op.lte]: new Date(to) };
  let data = [];
  switch(type) {
    case 'rides': data = await Ride.findAll({ where: dateFilter, include: ['customer','driver'] }); break;
    case 'drivers': data = await Driver.findAll({ include: ['user','vehicle'] }); break;
    case 'payments': data = await Payment.findAll({ where: { ...dateFilter, payment_status: 'completed' } }); break;
    default: throw new ApiError(400, 'Invalid type');
  }
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Content-Disposition', `attachment; filename=zip-rick-${type}.json`);
  res.json(data);
}));

module.exports = router;
