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
      
      // Rescue rides stuck in 'searching'. The 60s timeout in
      // RideMatchingService lives in memory, so a server restart loses it and
      // the ride would otherwise stay 'searching' forever - and keep being
      // re-offered to drivers with its original fare.
      try {
        const staleCutoff = new Date(Date.now() - 3 * 60 * 1000);
        const stale = await Ride.findAll({
          where: { status: 'searching', created_at: { [Op.lt]: staleCutoff } },
          limit: 50,
        });
        for (const s of stale) {
          s.status = 'no_driver_found';
          await s.save();
          logger.info('Stale search expired: ' + s.ride_number);
        }
      } catch (e) {
        logger.error('Stale ride cleanup failed: ' + e.message);
      }

      const scheduledRides = await Ride.findAll({
        where: {
          status: 'scheduled',
          scheduled_at: { [Op.lte]: now },
        },
      });

      for (const ride of scheduledRides) {
        try {
          ride.status = 'searching';
          await ride.save();
          
          try {
            await RideStatusLog.create({
              ride_id: ride.id,
              previous_status: 'scheduled',
              new_status: 'searching',
              changed_by: 'system',
            });
          } catch (logErr) {
            // Status log is optional
          }
          
          logger.info(`Scheduler: Ride ${ride.ride_number} moved from scheduled to searching`);
          RideMatchingService.startSearch(ride, null, null);
        } catch (err) {
          logger.error(`Scheduler: Error processing ride ${ride.ride_number}: ${err.message || err}`);
        }
      }
    } catch (err) {
      logger.error(`Scheduler error: ${err.message || err}`);
    }
  }, 30000);
}

function stopScheduler() {
  if (intervalId) {
    clearInterval(intervalId);
    intervalId = null;
    logger.info('Ride scheduler stopped');
  }
}

module.exports = { startScheduler, stopScheduler };
