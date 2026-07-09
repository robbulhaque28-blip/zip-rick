const { Model, DataTypes } = require('sequelize');
const { sequelize } = require('../config/db');

class SupportTicket extends Model {}

SupportTicket.init(
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
    subject: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    description: {
      type: DataTypes.TEXT,
      allowNull: false,
    },
    status: {
      type: DataTypes.STRING,
      defaultValue: 'open',
    },
    priority: {
      type: DataTypes.STRING,
      defaultValue: 'medium',
    },
  },
  {
    sequelize,
    modelName: 'SupportTicket',
    tableName: 'support_tickets',
  }
);

module.exports = SupportTicket;
