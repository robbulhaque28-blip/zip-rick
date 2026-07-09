const { Model, DataTypes } = require('sequelize');
const { sequelize } = require('../config/db');

class RideStatusLog extends Model {}

RideStatusLog.init(
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    ride_id: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    status: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    timestamp: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW,
    },
    notes: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
  },
  {
    sequelize,
    modelName: 'RideStatusLog',
    tableName: 'ride_status_logs',
  }
);

module.exports = RideStatusLog;
