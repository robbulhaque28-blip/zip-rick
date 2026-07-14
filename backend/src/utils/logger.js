const winston = require('winston');
const path = require('path');
const fs = require('fs');
const config = require('../config');
if (!fs.existsSync(config.logging.dir)) fs.mkdirSync(config.logging.dir, { recursive: true });
const logger = winston.createLogger({
  level: config.logging.level,
  format: winston.format.combine(winston.format.timestamp(), winston.format.json()),
  transports: [
    new winston.transports.File({ filename: path.join(config.logging.dir, 'error.log'), level: 'error', maxsize: 5242880, maxFiles: 5 }),
    new winston.transports.File({ filename: path.join(config.logging.dir, 'combined.log'), maxsize: 5242880, maxFiles: 10 }),
  ],
});
// Always add console transport so Render can see errors
logger.add(new winston.transports.Console({
  format: winston.format.combine(winston.format.colorize(), winston.format.simple()),
}));
module.exports = logger;