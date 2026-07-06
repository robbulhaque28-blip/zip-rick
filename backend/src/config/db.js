/**
 * Database Connection - Sequelize instance with pooling.
 */
const { Sequelize } = require('sequelize');
const config = require('./index');
const logger = require('../utils/logger');

const sequelize = new Sequelize(config.db.name, config.db.user, config.db.password, {
  host: config.db.host,
  port: config.db.port,
  dialect: config.db.dialect,
  pool: config.db.pool,
  logging: config.db.logging,
  define: { underscored: true, timestamps: true, paranoid: true, deletedAt: 'deleted_at' },
  dialectOptions: config.env === 'production' ? { ssl: { require: true, rejectUnauthorized: false } } : {},
});

async function testConnection() {
  try { await sequelize.authenticate(); logger.info('Database connected.'); return true; }
  catch (e) { logger.error('DB connection failed:', e); return false; }
}

module.exports = { sequelize, testConnection };
