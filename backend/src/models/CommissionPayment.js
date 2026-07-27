const { Model, DataTypes } = require('sequelize');
const { sequelize } = require('../config/db');

/**
 * A commission settlement submitted by a driver.
 *
 * Fares are collected in cash, so the driver physically holds the platform's
 * 10%. They pay it to the company bank account / UPI outside the app, then
 * submit a record here. An admin confirms it was actually received before the
 * driver's balance is cleared - the driver cannot clear their own dues.
 *
 * status: pending -> confirmed | rejected
 */
class CommissionPayment extends Model {}

CommissionPayment.init(
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    driver_id: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    amount: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: false,
    },
    // 'cash', 'upi', 'bank_transfer', later 'razorpay'
    method: {
      type: DataTypes.STRING,
      allowNull: false,
      defaultValue: 'upi',
    },
    // UPI reference / bank UTR number the driver types in.
    reference: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    note: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    status: {
      type: DataTypes.STRING,
      allowNull: false,
      defaultValue: 'pending',
    },
    submitted_at: {
      type: DataTypes.DATE,
      allowNull: true,
      defaultValue: DataTypes.NOW,
    },
    reviewed_at: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    reviewed_by: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    rejection_reason: {
      type: DataTypes.STRING,
      allowNull: true,
    },
  },
  {
    sequelize,
    modelName: 'CommissionPayment',
    tableName: 'commission_payments',
    indexes: [{ fields: ['driver_id'] }, { fields: ['status'] }],
  }
);

module.exports = CommissionPayment;
