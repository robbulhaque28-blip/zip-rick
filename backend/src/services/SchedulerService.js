const { Op } = require('sequelize');
const { Ride, RideStatusLog, Driver } = require('../models');
const RideMatchingService = require('./RideMatchingService');
const logger = require('../utils/logger');

let intervalId = null;

const IN_PROGRESS = ['driver_assigned', 'driver_arrived', 'started'];

function startScheduler() {
  logger.info('Ride scheduler started (checking every 30s)');

  intervalId = setInterval(async () => {
    try {
      const now = new Date();

      // ------------------------------------------------------------------
      // 1. Rescue rides stuck in 'searching'. The 60s timeout in
      //    RideMatchingService lives in memory, so a server restart loses it
      //    and the ride would otherwise stay 'searching' forever - and keep
      //    being re-offered to drivers with its original fare.
      // ------------------------------------------------------------------
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

      // ------------------------------------------------------------------
      // 2. Auto-close rides that got stuck mid-trip.
      //
      //    THIS IS THE IMPORTANT ONE. A ride left sitting in
      //    driver_assigned / driver_arrived / started keeps the driver's
      //    current_ride_id pointed at it. RideMatchingService.findNearbyDrivers
      //    filters on `current_ride_id: null`, so ONE forgotten ride silently
      //    removes that driver from matching FOREVER - every later booking
      //    then falls through to 'no_driver_found' and the driver app never
      //    receives a single request.
      // ------------------------------------------------------------------
      try {
        const groups = [
          { statuses: ['driver_assigned', 'driver_arrived'], minutes: 45 },
          { statuses: ['started'], minutes: 180 },
        ];
        for (const grp of groups) {
          const cutoff = new Date(Date.now() - grp.minutes * 60 * 1000);
          const stuck = await Ride.findAll({
            where: { status: { [Op.in]: grp.statuses }, created_at: { [Op.lt]: cutoff } },
            limit: 50,
          });
          for (const s of stuck) {
            const prev = s.status;
            s.status = 'cancelled';
            s.cancellation_reason = 'Auto-closed: ride was left incomplete';
            s.cancelled_by = 'system';
            s.cancelled_at = new Date();
            await s.save();
            try {
              await RideStatusLog.create({
                ride_id: s.id,
                previous_status: prev,
                new_status: 'cancelled',
                changed_by: 'system',
              });
            } catch (logErr) {
              // status log is optional
            }
            if (s.driver_id) {
              try {
                await Driver.update(
                  { is_available: true, current_ride_id: null },
                  { where: { id: s.driver_id } }
                );
              } catch (dErr) {
                logger.error('Could not free driver for ' + s.ride_number + ': ' + dErr.message);
              }
            }
            logger.info('Auto-closed stuck ride ' + s.ride_number + ' (was ' + prev + ')');
          }
        }
      } catch (e) {
        logger.error('Stuck ride cleanup failed: ' + e.message);
      }

      // ------------------------------------------------------------------
      // 3. Belt and braces: free any driver whose current_ride_id points at a
      //    ride that is no longer in progress. This self-heals drivers that
      //    were locked out by an older bug or a crash mid-ride.
      // ------------------------------------------------------------------
      try {
        const busy = await Driver.findAll({
          where: { current_ride_id: { [Op.ne]: null } },
          attributes: ['id', 'current_ride_id'],
          limit: 100,
        });
        for (const d of busy) {
          const r = await Ride.findByPk(d.current_ride_id, {
            attributes: ['id', 'status', 'ride_number'],
          });
          if (!r || !IN_PROGRESS.includes(r.status)) {
            await Driver.update(
              { is_available: true, current_ride_id: null },
              { where: { id: d.id } }
            );
            logger.info('Freed driver ' + d.id + ' - current_ride_id pointed at a finished ride');
          }
        }
      } catch (e) {
        logger.error('Driver unlock sweep failed: ' + e.message);
      }

      // ------------------------------------------------------------------
      // 4. Promote scheduled rides whose time has come.
      // ------------------------------------------------------------------
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
