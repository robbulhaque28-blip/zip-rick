const { Sequelize } = require('sequelize');
const config = require('./index');
const logger = require('../utils/logger');

const sequelize = new Sequelize({
  dialect: config.db.dialect || 'sqlite',
  storage: config.db.dialect === 'sqlite' ? config.db.storage || './database.sqlite' : undefined,
  host: config.db.host,
  port: config.db.port,
  username: config.db.user,
  password: config.db.password,
  database: config.db.name,
  logging: false,
  define: {
    underscored: true,
    timestamps: true,
    paranoid: true,
    deletedAt: 'deleted_at',
  },
  dialectOptions: config.env === 'production' ? {
    ssl: {
      require: true,
      rejectUnauthorized: false,
    },
  } : {},
});

async function testConnection() {
  try {
    await sequelize.authenticate();
    logger.info('Database connected.');
    return true;
  } catch (e) {
    logger.error('DB connection failed:', e.message);
    return false;
  }
}

module.exports = { sequelize, testConnection };