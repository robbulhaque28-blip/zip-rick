const { Model, DataTypes } = require('sequelize');
const { sequelize } = require('../config/db');

class Ride extends Model {
  static generateRideNumber() {
    const d = new Date();
    const dateStr = d.toISOString().slice(0, 10).replace(/-/g, '');
    const random = Math.random().toString(36).substring(2, 7).toUpperCase();
    return 'ZR-' + dateStr + '-' + random;
  }
}

Ride.init({
  id: { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  ride_number: { type: DataTypes.STRING(20), allowNull: false, unique: true },
  customer_id: { type: DataTypes.UUID, allowNull: false, references: { model: 'customers', key: 'id' } },
  driver_id: { type: DataTypes.UUID, allowNull: true, references: { model: 'drivers', key: 'id' } },
  pickup_latitude: { type: DataTypes.DECIMAL(10, 8), allowNull: false },
  pickup_longitude: { type: DataTypes.DECIMAL(11, 8), allowNull: false },
  pickup_address: { type: DataTypes.TEXT, allowNull: false },
  pickup_place_id: { type: DataTypes.STRING(255), allowNull: true },
  drop_latitude: { type: DataTypes.DECIMAL(10, 8), allowNull: false },
  drop_longitude: { type: DataTypes.DECIMAL(11, 8), allowNull: false },
  drop_address: { type: DataTypes.TEXT, allowNull: false },
  drop_place_id: { type: DataTypes.STRING(255), allowNull: true },
  route_distance: { type: DataTypes.DECIMAL(10, 2), allowNull: true },
  route_duration: { type: DataTypes.INTEGER, allowNull: true },
  route_polyline: { type: DataTypes.TEXT, allowNull: true },
  base_fare: { type: DataTypes.DECIMAL(10, 2), allowNull: false },
  distance_fare: { type: DataTypes.DECIMAL(10, 2), defaultValue: 0 },
  time_fare: { type: DataTypes.DECIMAL(10, 2), defaultValue: 0 },
  waiting_charges: { type: DataTypes.DECIMAL(10, 2), defaultValue: 0 },
  night_charges: { type: DataTypes.DECIMAL(10, 2), defaultValue: 0 },
  peak_charges: { type: DataTypes.DECIMAL(10, 2), defaultValue: 0 },
  promo_discount: { type: DataTypes.DECIMAL(10, 2), defaultValue: 0 },
  cancellation_charges: { type: DataTypes.DECIMAL(10, 2), defaultValue: 0 },
  total_fare: { type: DataTypes.DECIMAL(10, 2), allowNull: false },
  commission_amount: { type: DataTypes.DECIMAL(10, 2), defaultValue: 0 },
  driver_earnings: { type: DataTypes.DECIMAL(10, 2), defaultValue: 0 },
  status: {
    type: DataTypes.ENUM('pending', 'searching', 'driver_assigned', 'driver_arrived', 'started', 'completed', 'cancelled', 'no_driver_found'),
    defaultValue: 'pending',
  },
  cancellation_reason: { type: DataTypes.TEXT, allowNull: true },
  cancelled_by: { type: DataTypes.ENUM('customer', 'driver', 'system', 'admin'), allowNull: true },
  cancelled_at: { type: DataTypes.DATE, allowNull: true },
  driver_assigned_at: { type: DataTypes.DATE, allowNull: true },
  driver_arrived_at: { type: DataTypes.DATE, allowNull: true },
  ride_started_at: { type: DataTypes.DATE, allowNull: true },
  ride_completed_at: { type: DataTypes.DATE, allowNull: true },
  payment_method: { type: DataTypes.ENUM('cash', 'upi'), allowNull: true },
  payment_status: { type: DataTypes.ENUM('pending', 'completed', 'failed', 'refunded'), defaultValue: 'pending' },
  tracking_enabled: { type: DataTypes.BOOLEAN, defaultValue: true },
}, {
  sequelize,
  modelName: 'Ride',
  tableName: 'rides',
  hooks: {
    beforeCreate: (ride) => {
      if (!ride.ride_number) {
        ride.ride_number = Ride.generateRideNumber();
        console.log('Generated ride number:', ride.ride_number);
      }
    },
  },
  indexes: [
    { fields: ['customer_id'] },
    { fields: ['driver_id'] },
    { fields: ['status'] },
    { fields: ['created_at'] },
  ],
});

module.exports = Ride;
