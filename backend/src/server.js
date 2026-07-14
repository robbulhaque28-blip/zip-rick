const http = require('http');
const app = require('./app');
const config = require('./config');
const logger = require('./utils/logger');
const { sequelize, testConnection } = require('./config/db');
const { setupSocketIO } = require('./sockets');
const server = http.createServer(app);
const io = setupSocketIO(server);
app.set('io', io);
async function start() {
  console.log('Starting server...');
  console.log('Connecting to database...');
  const connected = await testConnection();
  if (!connected) {
    console.error('FATAL: Database connection failed!');
    logger.error('DB connection failed');
    process.exit(1);
  }
  console.log('Database connected successfully!');
  if (config.env === 'development') await sequelize.sync({ alter: false });
  server.listen(config.port, () => {
    console.log(`Zip-Rick API running on port ${config.port} [${config.env}]`);
    logger.info(`Zip-Rick API running on port ${config.port} [${config.env}]`);
  });
}
start();
function gracefulShutdown(signal) {
  logger.info(`${signal} received. Shutting down...`);
  server.close(() => { sequelize.close().then(() => process.exit(0)); });
  setTimeout(() => process.exit(1), 10000);
}
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));
process.on('uncaughtException', (e) => { console.error('Uncaught Exception:', e); logger.error('Uncaught Exception:', e); gracefulShutdown('UNCAUGHT'); });
module.exports = server;