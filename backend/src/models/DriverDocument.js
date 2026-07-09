const { Model, DataTypes } = require('sequelize');
const { sequelize } = require('../config/db');

class DriverDocument extends Model {}

DriverDocument.init(
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
    document_type: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    document_url: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    status: {
      type: DataTypes.STRING,
      defaultValue: 'pending',
    },
  },
  {
    sequelize,
    modelName: 'DriverDocument',
    tableName: 'driver_documents',
  }
);

module.exports = DriverDocument;
