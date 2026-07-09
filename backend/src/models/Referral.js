const { Model, DataTypes } = require('sequelize');
const { sequelize } = require('../config/db');

class Referral extends Model {}

Referral.init(
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    referrer_id: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    referred_id: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    reward_amount: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: true,
    },
    status: {
      type: DataTypes.STRING,
      defaultValue: 'pending',
    },
  },
  {
    sequelize,
    modelName: 'Referral',
    tableName: 'referrals',
  }
);

module.exports = Referral;
