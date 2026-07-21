const { Op } = require('sequelize');
const { Ride, RideStatusLog } = require('../models');
const RideMatchingService = require('./RideMatchingService');
const logger = require('../utils/logger');

let intervalId = null;

function startScheduler() {
  logger.info('Ride scheduler started (checking every 30s)');
  
  intervalId = setInterval(async () => {
    try {
      const now = new Date();
      
      // Find all scheduled rides whose time has come (within last 5 seconds tolerance)
      const scheduledRides = await Ride.findAll({
        where: {
          status: 'scheduled',
          scheduled_at: {
            [Op.lte]: now,
          },
        },
      });

      if (scheduledRides.length > 0) {
        logger.info(`Scheduler: Processing ${scheduledRides.length} scheduled ride(s)`);
      }

      for (const ride of scheduledRides) {
        try {
          ride.status = 'searching';
          await ride.save();
          
          await RideStatusLog.create({
            ride_id: ride.id,
            previous_status: 'scheduled',
            new_status: 'searching',
            changed_by: 'system',
            metadata: { scheduled_at: ride.scheduled_at },
          });
          
          logger.info(`Scheduler: Ride ${ride.ride_number} moved from scheduled to searching`);
          
          // Start finding drivers
          RideMatchingService.startSearch(ride, null, null);
        } catch (err) {
          logger.error(`Scheduler: Error processing ride ${ride.ride_number}: ${err.message}`);
        }
      }
    } catch (err) {
      logger.error('Scheduler error:', err.message);
    }
  }, 30000); // Check every 30 seconds
}

function stopScheduler() {
  if (intervalId) {
    clearInterval(intervalId);
    intervalId = null;
    logger.info('Ride scheduler stopped');
  }
}

module.exports = { startScheduler, stopScheduler };
