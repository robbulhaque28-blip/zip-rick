/**
 * User Model
 * Core authentication and base profile for all user roles.
 */

const { Model, DataTypes } = require('sequelize');
const { sequelize } = require('../config/db');

class User extends Model {
  /**
   * Check if user has a specific role
   * @param {string} role - Role to check
   * @returns {boolean}
   */
  hasRole(role) {
    return this.role === role;
  }

  /**
   * Check if user is active and not blocked
   * @returns {boolean}
   */
  isActive() {
    return this.is_active && !this.is_blocked;
  }

  /**
   * Get safe profile (exclude sensitive fields)
   * @returns {Object}
   */
  getSafeProfile() {
    return {
      id: this.id,
      phone: this.phone,
      email: this.email,
      full_name: this.full_name,
      role: this.role,
      avatar_url: this.avatar_url,
      is_phone_verified: this.is_phone_verified,
    };
  }
}

User.init(
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    phone: {
      type: DataTypes.STRING(15),
      allowNull: false,
      unique: true,
      validate: {
        is: /^\+?[1-9]\d{9,14}$/,
      },
    },
    email: {
      type: DataTypes.STRING(255),
      allowNull: true,
      unique: true,
      validate: {
        isEmail: true,
      },
    },
    full_name: {
      type: DataTypes.STRING(255),
      allowNull: false,
      validate: {
        notEmpty: true,
        len: [2, 255],
      },
    },
    role: {
      type: DataTypes.ENUM('customer', 'driver', 'admin'),
      allowNull: false,
      defaultValue: 'customer',
    },
    avatar_url: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    is_phone_verified: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },
    is_active: {
      type: DataTypes.BOOLEAN,
      defaultValue: true,
    },
    is_blocked: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },
    fcm_token: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    last_login_at: {
      type: DataTypes.DATE,
      allowNull: true,
    },
  },
  {
    sequelize,
    modelName: 'User',
    tableName: 'users',
    paranoid: true, // soft deletes
    hooks: {
      beforeUpdate: (user) => {
        user.updated_at = new Date();
      },
    },
    indexes: [
      { fields: ['phone'] },
      { fields: ['role'] },
      { fields: ['email'] },
    ],
  }
);

module.exports = User;
