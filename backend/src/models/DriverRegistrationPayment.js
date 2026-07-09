const { Model, DataTypes } = require('sequelize');
const { sequelize } = require('../config/db');

class DriverRegistrationPayment extends Model {}

DriverRegistrationPayment.init(
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
    payment_status: {
      type: DataTypes.STRING,
      defaultValue: 'pending',
    },
    payment_date: {
      type: DataTypes.DATE,
      allowNull: true,
    },
  },
  {
    sequelize,
    modelName: 'DriverRegistrationPayment',
    tableName: 'driver_registration_payments',
  }
);

module.exports = DriverRegistrationPayment;
