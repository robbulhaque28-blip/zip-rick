const { Model, DataTypes } = require('sequelize');
const { sequelize } = require('../config/db');

class PromoRedemption extends Model {}

PromoRedemption.init(
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    promo_code_id: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    customer_id: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    ride_id: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    discount_amount: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: false,
    },
  },
  {
    sequelize,
    modelName: 'PromoRedemption',
    tableName: 'promo_redemptions',
  }
);

module.exports = PromoRedemption;
