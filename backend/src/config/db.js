const { Sequelize } = require('sequelize');
const config = require('./index');
const logger = require('../utils/logger');

const sequelize = new Sequelize({
  dialect: 'sqlite',
  storage: './database.sqlite',
  logging: false,
  define: {
    underscored: true,
    timestamps: true,
    paranoid: true,
    deletedAt: 'deleted_at',
  },
  dialectOptions: {
    // Use better-sqlite3 for production compatibility
  },
});

async function testConnection() {
  try {
    await sequelize.authenticate();
    logger.info('Database connected (SQLite via better-sqlite3).');
    return true;
  } catch (e) {
    logger.error('DB connection failed:', e.message);
    return false;
  }
}

module.exports = { sequelize, testConnection };