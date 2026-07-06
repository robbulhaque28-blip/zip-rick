/**
 * Zip-Rick API Server Entry Point
 * Initializes HTTP server, database, Socket.IO, and starts listening.
 */

const http = require('http');
const app = require('./app');
const config = require('./config');
const logger = require('./utils/logger');
const { sequelize, testConnection } = require('./config/db');
const { setupSocketIO } = require('./sockets');
const { initializeFirebase } = require('./services/AuthService');

// =====================================
// Create HTTP Server
// =====================================
const server = http.createServer(app);

// =====================================
// Initialize Socket.IO
// =====================================
const io = setupSocketIO(server);
app.set('io', io);

// =====================================
// Server Start
// =====================================
async function start() {
  try {
    // Test database connection
    const dbConnected = await testConnection();
    if (!dbConnected) {
      logger.error('Database connection failed. Exiting.');
      process.exit(1);
    }

    // Initialize Firebase
    initializeFirebase();

    // Sync database in development only
    if (config.env === 'development') {
      const { syncDatabase } = require('./config/db');
      await syncDatabase(false);
    }

    // Start listening
    server.listen(config.port, () => {
      logger.info(`
        ╔══════════════════════════════════════════════╗
        ║           Zip-Rick API Server                ║
        ║──────────────────────────────────────────────║
        ║  Environment: ${config.env.padEnd(30)}║
        ║  Port:        ${String(config.port).padEnd(30)}║
        ║  API:         ${config.apiPrefix.padEnd(30)}║
        ║  Docs:        ${`http://localhost:${config.port}/api/docs`.padEnd(23)}║
        ╚══════════════════════════════════════════════╝
      `);
    });
  } catch (error) {
    logger.error('Server start failed:', error);
    process.exit(1);
  }
}

// =====================================
// Graceful Shutdown
// =====================================
function gracefulShutdown(signal) {
  logger.info(`${signal} received. Shutting down gracefully...`);
  server.close(() => {
    logger.info('HTTP server closed.');
    sequelize.close().then(() => {
      logger.info('Database connection closed.');
      process.exit(0);
    });
  });

  // Force close after 10 seconds
  setTimeout(() => {
    logger.error('Forced shutdown after timeout.');
    process.exit(1);
  }, 10000);
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception:', error);
  gracefulShutdown('UNCAUGHT_EXCEPTION');
});

process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

// =====================================
// Start Server
// =====================================
start();

module.exports = server;
