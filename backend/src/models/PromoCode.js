const { Model, DataTypes } = require('sequelize');
const { sequelize } = require('../config/db');

class PromoCode extends Model {}

PromoCode.init(
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    code: {
      type: DataTypes.STRING,
      allowNull: false,
      unique: true,
    },
    discount: {
      type: DataTypes.DECIMAL(5, 2),
      allowNull: false,
    },
    discount_type: {
      type: DataTypes.STRING,
      defaultValue: 'percentage',
    },
    status: {
      type: DataTypes.STRING,
      defaultValue: 'active',
    },
    expiry_date: {
      type: DataTypes.DATE,
      allowNull: true,
    },
  },
  {
    sequelize,
    modelName: 'PromoCode',
    tableName: 'promo_codes',
  }
);

module.exports = PromoCode;
