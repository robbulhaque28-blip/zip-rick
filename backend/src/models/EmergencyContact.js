/**
 * Models Index
 * Initializes all models and their associations.
 */
const { sequelize } = require('../config/db');
const logger = require('../utils/logger');

// Import all models
const User = require('./User');
const Customer = require('./Customer');
const Driver = require('./Driver');
const DriverDocument = require('./DriverDocument');
const DriverRegistrationPayment = require('./DriverRegistrationPayment');
const Vehicle = require('./Vehicle');
const Ride = require('./Ride');
const RideStatusLog = require('./RideStatusLog');
const Payment = require('./Payment');
const Transaction = require('./Transaction');
const Wallet = require('./Wallet');
const RatingReview = require('./RatingReview');
const Notification = require('./Notification');
const PromoCode = require('./PromoCode');
const PromoRedemption = require('./PromoRedemption');
const Referral = require('./Referral');
const SavedPlace = require('./SavedPlace');
const SupportTicket = require('./SupportTicket');
const SupportTicketMessage = require('./SupportTicketMessage');
const AdminUser = require('./AdminUser');
const SystemSetting = require('./SystemSetting');
const AuditLog = require('./AuditLog');
const ChatMessage = require('./ChatMessage');
const EmergencyContact = require('./EmergencyContact');

// ============================
// Association Definitions
// ============================

// User -> Customer (1:1)
User.hasOne(Customer, { foreignKey: 'user_id', as: 'customerProfile' });
Customer.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

// User -> Driver (1:1)
User.hasOne(Driver, { foreignKey: 'user_id', as: 'driverProfile' });
Driver.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

// Driver -> DriverDocuments (1:N)
Driver.hasMany(DriverDocument, { foreignKey: 'driver_id', as: 'documents' });
DriverDocument.belongsTo(Driver, { foreignKey: 'driver_id', as: 'driver' });

// Driver -> RegistrationPayments (1:N)
Driver.hasMany(DriverRegistrationPayment, { foreignKey: 'driver_id', as: 'registrationPayments' });
DriverRegistrationPayment.belongsTo(Driver, { foreignKey: 'driver_id', as: 'driver' });

// Driver -> Vehicle (1:1)
Driver.hasOne(Vehicle, { foreignKey: 'driver_id', as: 'vehicle' });
Vehicle.belongsTo(Driver, { foreignKey: 'driver_id', as: 'driver' });

// Driver -> AdminUser (approval)
Driver.belongsTo(AdminUser, { foreignKey: 'approved_by', as: 'approvedBy' });

// Customer -> Rides (1:N)
Customer.hasMany(Ride, { foreignKey: 'customer_id', as: 'rides' });
Ride.belongsTo(Customer, { foreignKey: 'customer_id', as: 'customer' });

// Driver -> Rides (1:N)
Driver.hasMany(Ride, { foreignKey: 'driver_id', as: 'assignedRides' });
Ride.belongsTo(Driver, { foreignKey: 'driver_id', as: 'driver' });

// Ride -> StatusLogs (1:N)
Ride.hasMany(RideStatusLog, { foreignKey: 'ride_id', as: 'statusLogs' });
RideStatusLog.belongsTo(Ride, { foreignKey: 'ride_id', as: 'ride' });

// Ride -> Payments (1:1)
Ride.hasOne(Payment, { foreignKey: 'ride_id', as: 'payment' });
Payment.belongsTo(Ride, { foreignKey: 'ride_id', as: 'ride' });

// Customer -> Payments (1:N)
Customer.hasMany(Payment, { foreignKey: 'customer_id', as: 'payments' });
Payment.belongsTo(Customer, { foreignKey: 'customer_id', as: 'customer' });

// Driver -> Payments (1:N)
Driver.hasMany(Payment, { foreignKey: 'driver_id', as: 'driverPayments' });
Payment.belongsTo(Driver, { foreignKey: 'driver_id', as: 'paymentDriver' });

// Ride -> RatingReview (1:1)
Ride.hasOne(RatingReview, { foreignKey: 'ride_id', as: 'rating' });
RatingReview.belongsTo(Ride, { foreignKey: 'ride_id', as: 'ride' });

// User -> Wallet (1:1)
User.hasOne(Wallet, { foreignKey: 'user_id', as: 'wallet' });
Wallet.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

// User -> Transactions (1:N)
User.hasMany(Transaction, { foreignKey: 'user_id', as: 'transactions' });
Transaction.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

// User -> Notifications (1:N)
User.hasMany(Notification, { foreignKey: 'user_id', as: 'notifications' });
Notification.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

// Customer -> SavedPlaces (1:N)
Customer.hasMany(SavedPlace, { foreignKey: 'customer_id', as: 'savedPlaces' });
SavedPlace.belongsTo(Customer, { foreignKey: 'customer_id', as: 'customer' });

// Customer -> Referrals (as referrer)
Customer.hasMany(Referral, { foreignKey: 'referrer_customer_id', as: 'referralsGiven' });
Referral.belongsTo(Customer, { foreignKey: 'referrer_customer_id', as: 'referrer' });

// Customer -> Referrals (as referred)
Customer.hasMany(Referral, { foreignKey: 'referred_customer_id', as: 'referralsReceived' });
Referral.belongsTo(Customer, { foreignKey: 'referred_customer_id', as: 'referred' });

// User -> SupportTickets (1:N)
User.hasMany(SupportTicket, { foreignKey: 'user_id', as: 'supportTickets' });
SupportTicket.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

// SupportTicket -> Messages (1:N)
SupportTicket.hasMany(SupportTicketMessage, { foreignKey: 'ticket_id', as: 'messages' });
SupportTicketMessage.belongsTo(SupportTicket, { foreignKey: 'ticket_id', as: 'ticket' });

// AdminUser -> Approved Drivers
AdminUser.hasMany(Driver, { foreignKey: 'approved_by', as: 'approvedDrivers' });

// Ride -> ChatMessages (1:N)
Ride.hasMany(ChatMessage, { foreignKey: 'ride_id', as: 'chatMessages' });
ChatMessage.belongsTo(Ride, { foreignKey: 'ride_id', as: 'ride' });

// PromoCode -> Redemptions (1:N)
PromoCode.hasMany(PromoRedemption, { foreignKey: 'promo_code_id', as: 'redemptions' });
PromoRedemption.belongsTo(PromoCode, { foreignKey: 'promo_code_id', as: 'promoCode' });

// User -> Redemptions
User.hasMany(PromoRedemption, { foreignKey: 'user_id', as: 'promoRedemptions' });
PromoRedemption.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

// Ride -> Redemptions
Ride.hasMany(PromoRedemption, { foreignKey: 'ride_id', as: 'promoRedemptions' });
PromoRedemption.belongsTo(Ride, { foreignKey: 'ride_id', as: 'redemptionRide' });

// User -> AdminUser (1:1)
User.hasOne(AdminUser, { foreignKey: 'user_id', as: 'adminProfile' });
AdminUser.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

const db = {
  sequelize,
  Sequelize: require('sequelize'),
  User,
  Customer,
  Driver,
  DriverDocument,
  DriverRegistrationPayment,
  Vehicle,
  Ride,
  RideStatusLog,
  Payment,
  Transaction,
  Wallet,
  RatingReview,
  Notification,
  PromoCode,
  PromoRedemption,
  Referral,
  SavedPlace,
  SupportTicket,
  SupportTicketMessage,
  AdminUser,
  SystemSetting,
  AuditLog,
  ChatMessage,
  EmergencyContact,
};

logger.info(`Loaded ${Object.keys(db).length - 2} database models`);
module.exports = db;