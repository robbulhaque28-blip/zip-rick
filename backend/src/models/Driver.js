/**
 * Driver Model
 * Driver profile, verification status, location, earnings, and operations.
 */

const { Model, DataTypes } = require('sequelize');
const { sequelize } = require('../config/db');

class Driver extends Model {
  /**
   * Update driver's live location
   */
  async updateLocation(lat, lng) {
    this.current_latitude = lat;
    this.current_longitude = lng;
    this.last_location_update = new Date();
    return this.save();
  }

  /**
   * Check if driver can accept rides
   */
  canAcceptRides() {
    return (
      this.registration_status === 'approved' &&
      this.is_online &&
      this.is_available &&
      !this.current_ride_id
    );
  }

  /**
   * Calculate average rating
   */
  getAverageRating() {
    if (this.total_ratings === 0) return 0;
    return (this.rating_sum / this.total_ratings).toFixed(1);
  }

  /**
   * Add earnings to driver
   */
  async addEarnings(amount) {
    this.total_earnings = parseFloat(this.total_earnings) + parseFloat(amount);
    this.total_rides += 1;
    return this.save();
  }
}

Driver.init(
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    user_id: {
      type: DataTypes.UUID,
      allowNull: false,
      unique: true,
      references: { model: 'users', key: 'id' },
      onDelete: 'CASCADE',
    },
    // Personal Info
    date_of_birth: { type: DataTypes.DATEONLY, allowNull: true },
    gender: { type: DataTypes.STRING(10), allowNull: true },
    address: { type: DataTypes.TEXT, allowNull: true },
    city: { type: DataTypes.STRING(100), allowNull: true },
    state: { type: DataTypes.STRING(100), allowNull: true },
    pincode: { type: DataTypes.STRING(10), allowNull: true },

    // Document Status
    aadhaar_verified: { type: DataTypes.BOOLEAN, defaultValue: false },
    rc_verified: { type: DataTypes.BOOLEAN, defaultValue: false },
    selfie_verified: { type: DataTypes.BOOLEAN, defaultValue: false },
    is_documents_uploaded: { type: DataTypes.BOOLEAN, defaultValue: false },

    // Registration
    registration_fee_paid: { type: DataTypes.BOOLEAN, defaultValue: false },
    registration_fee_amount: { type: DataTypes.DECIMAL(10, 2), defaultValue: 0.0 },
    registration_status: {
      type: DataTypes.ENUM('pending', 'approved', 'rejected', 'suspended'),
      defaultValue: 'pending',
    },
    registration_completed_at: { type: DataTypes.DATE, allowNull: true },
    rejection_reason: { type: DataTypes.TEXT, allowNull: true },
    approved_by: {
      type: DataTypes.UUID,
      allowNull: true,
      references: { model: 'admin_users', key: 'id' },
    },
    approved_at: { type: DataTypes.DATE, allowNull: true },

    // Operations
    is_online: { type: DataTypes.BOOLEAN, defaultValue: false },
    is_available: { type: DataTypes.BOOLEAN, defaultValue: false },
    current_latitude: { type: DataTypes.DECIMAL(10, 8), allowNull: true },
    current_longitude: { type: DataTypes.DECIMAL(11, 8), allowNull: true },
    last_location_update: { type: DataTypes.DATE, allowNull: true },
    current_ride_id: { type: DataTypes.UUID, allowNull: true },

    // Earnings
    total_earnings: { type: DataTypes.DECIMAL(12, 2), defaultValue: 0.0 },
    total_rides: { type: DataTypes.INTEGER, defaultValue: 0 },
    total_ratings: { type: DataTypes.INTEGER, defaultValue: 0 },
    rating_sum: { type: DataTypes.INTEGER, defaultValue: 0 },
    rating_avg: { type: DataTypes.DECIMAL(2, 1), defaultValue: 0.0 },

    // Commission
    commission_rate: { type: DataTypes.DECIMAL(5, 2), defaultValue: 10.0 },
  commission_due: { type: DataTypes.DECIMAL(10, 2), defaultValue: 0 },
  total_commission_paid: { type: DataTypes.DECIMAL(12, 2), defaultValue: 0 },
  },
  {
    sequelize,
    modelName: 'Driver',
    tableName: 'drivers',
    indexes: [
      { fields: ['current_latitude', 'current_longitude'] },
      { fields: ['is_online', 'is_available'] },
      { fields: ['registration_status'] },
    ],
  }
);

module.exports = Driver;
