const { Model, DataTypes } = require('sequelize');
const { sequelize } = require('../config/db');
class AdminUser extends Model {}
AdminUser.init({
  id: { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  user_id: { type: DataTypes.UUID, allowNull: false, unique: true, references: { model: 'users', key: 'id' }, onDelete: 'CASCADE' },
  email: { type: DataTypes.STRING(255), allowNull: false, unique: true, validate: { isEmail: true } },
  password_hash: { type: DataTypes.STRING(255), allowNull: false },
  role: { type: DataTypes.ENUM('super_admin', 'admin', 'support', 'finance', 'operations'), allowNull: false },
  permissions: { type: DataTypes.JSONB, allowNull: true },
  is_active: { type: DataTypes.BOOLEAN, defaultValue: true },
  last_login_at: { type: DataTypes.DATE, allowNull: true },
}, { sequelize, modelName: 'AdminUser', tableName: 'admin_users' });
module.exports = AdminUser;
