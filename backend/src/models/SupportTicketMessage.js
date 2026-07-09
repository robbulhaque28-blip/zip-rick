const { Model, DataTypes } = require('sequelize');
const { sequelize } = require('../config/db');

class SupportTicketMessage extends Model {}

SupportTicketMessage.init(
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    ticket_id: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    sender_id: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    message: {
      type: DataTypes.TEXT,
      allowNull: false,
    },
    attachment_url: {
      type: DataTypes.STRING,
      allowNull: true,
    },
  },
  {
    sequelize,
    modelName: 'SupportTicketMessage',
    tableName: 'support_ticket_messages',
  }
);

module.exports = SupportTicketMessage;
