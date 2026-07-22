/**
 * Customer Model
 * Customer-specific profile, analytics, and referral data.
 */

const { Model, DataTypes } = require('sequelize');
const { sequelize } = require('../config/db');
const { nanoid } = require('nanoid');

class Customer extends Model {
  /**
   * Generate unique referral code
   * @returns {string}
   */
  static generateReferralCode() {
    return 'ZR' + nanoid(8).toUpperCase();
  }
}

Customer.init(
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
    total_rides: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
    },
    total_spent: {
      type: DataTypes.DECIMAL(10, 2),
      defaultValue: 0.0,
    },
    rating: {
      type: DataTypes.DECIMAL(2, 1),
      defaultValue: 0.0,
    },
    rating_count: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
    },
    referral_code: {
      type: DataTypes.STRING(20),
      unique: true,
    },
    referred_by: {
      type: DataTypes.UUID,
      allowNull: true,
      references: { model: 'customers', key: 'id' },
    },
    loyalty_points: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
    },
    referral_discount_earned: {
      type: DataTypes.DECIMAL(10, 2),
      defaultValue: 0,
    },
  },
  {
    sequelize,
    modelName: 'Customer',
    tableName: 'customers',
    hooks: {
      beforeCreate: async (customer) => {
        if (!customer.referral_code) {
          let code;
          let exists = true;
          while (exists) {
            code = Customer.generateReferralCode();
            exists = await Customer.findOne({ where: { referral_code: code } });
          }
          customer.referral_code = code;
        }
      },
    },
  }
);

module.exports = Customer;
