const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const config = require('./config');
const logger = require('./utils/logger');
const { notFound, errorHandler } = require('./middleware/errorHandler');
const routes = require('./routes');

const app = express();

// CORS - Allow ALL origins in development
app.use(cors());
app.options('*', cors());

app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' }, contentSecurityPolicy: false }));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(compression());

if (config.env !== 'test') app.use(morgan('combined', { stream: { write: m => logger.http(m.trim()) } }));
app.use('/api/', rateLimit({ windowMs: config.rateLimit.windowMs, max: config.rateLimit.maxRequests }));
app.use(config.apiPrefix, routes);
app.use(notFound);
app.use(errorHandler);

module.exports = app;
