const { Model, DataTypes } = require('sequelize');
const { sequelize } = require('../config/db');

/**
 * Emergency contact for the SOS feature.
 *
 * NOTE: this file previously contained an accidental duplicate of
 * models/index.js - it re-declared every model association, and never defined
 * an EmergencyContact model at all. Requiring it therefore crashed with
 * "You have used the alias customerProfile in two separate associations",
 * and because it was never exported from models/index.js the SOS endpoints
 * failed with "Cannot read properties of undefined (reading 'findAll')".
 */
class EmergencyContact extends Model {}

EmergencyContact.init(
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
    name: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    phone: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    relation: {
      type: DataTypes.STRING,
      allowNull: true,
      defaultValue: '',
    },
  },
  {
    sequelize,
    modelName: 'EmergencyContact',
    tableName: 'emergency_contacts',
    indexes: [{ fields: ['user_id'] }],
  }
);

module.exports = EmergencyContact;
