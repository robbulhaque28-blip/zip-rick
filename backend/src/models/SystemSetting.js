const { Model, DataTypes } = require('sequelize');
const { sequelize } = require('../config/db');

class SystemSetting extends Model {}

SystemSetting.init(
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    key: {
      type: DataTypes.STRING,
      allowNull: false,
      unique: true,
    },
    value: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    description: {
      type: DataTypes.STRING,
      allowNull: true,
    },
  },
  {
    sequelize,
    modelName: 'SystemSetting',
    tableName: 'system_settings',
  }
);

module.exports = SystemSetting;
