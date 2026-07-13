const { Model, DataTypes } = require('sequelize');
const { sequelize } = require('../config/db');

class RideStatusLog extends Model {}

RideStatusLog.init({
  id: { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  ride_id: { type: DataTypes.UUID, allowNull: false },
  previous_status: { type: DataTypes.STRING(30), allowNull: true },
  new_status: { type: DataTypes.STRING(30), allowNull: false },
  changed_by: { type: DataTypes.STRING(20), allowNull: false },
  changed_by_id: { type: DataTypes.UUID, allowNull: true },
  metadata: { type: DataTypes.JSONB, allowNull: true },
  created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
}, {
  sequelize,
  modelName: 'RideStatusLog',
  tableName: 'ride_status_logs',
  timestamps: true,
  updatedAt: false,
});

module.exports = RideStatusLog;