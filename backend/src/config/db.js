const { Sequelize } = require('sequelize');
const config = require('./index');
const logger = require('../utils/logger');

let sequelize;

if (process.env.DATABASE_URL) {
  sequelize = new Sequelize(process.env.DATABASE_URL, {
    dialect: 'postgres',
    protocol: 'postgres',
    dialectOptions: config.env === 'production'
      ? { ssl: { require: true, rejectUnauthorized: false } }
      : {},
    pool: config.db.pool,
    logging: config.db.logging,
    define: {
      underscored: true,
      timestamps: true,
      paranoid: true,
      deletedAt: 'deleted_at',
    },
  });
} else {
  sequelize = new Sequelize(config.db.name, config.db.user, config.db.password, {
    host: config.db.host,
    port: config.db.port,
    dialect: config.db.dialect,
    pool: config.db.pool,
    logging: config.db.logging,
    define: {
      underscored: true,
      timestamps: true,
      paranoid: true,
      deletedAt: 'deleted_at',
    },
    dialectOptions:
      config.env === 'production'
        ? { ssl: { require: true, rejectUnauthorized: false } }
        : {},
  });
}

async function testConnection() {
  try {
    await sequelize.authenticate();
    logger.info('DB connected');
    return true;
  } catch (e) {
    logger.error('DB connection failed:', e.message);
    return false;
  }
}

module.exports = { sequelize, testConnection };