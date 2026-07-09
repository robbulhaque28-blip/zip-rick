const { Model, DataTypes } = require('sequelize');
const { sequelize } = require('../config/db');

class Wallet extends Model {}

Wallet.init(
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    user_id: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    balance: {
      type: DataTypes.DECIMAL(10, 2),
      defaultValue: 0,
    },
    currency: {
      type: DataTypes.STRING,
      defaultValue: 'INR',
    },
  },
  {
    sequelize,
    modelName: 'Wallet',
    tableName: 'wallets',
  }
);

module.exports = Wallet;
