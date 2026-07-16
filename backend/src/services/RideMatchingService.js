/**
 * RideMatchingService
 * Finds nearest available drivers, sends requests sequentially,
 * and assigns the first driver to accept.
 */
const { Op } = require('sequelize');
const { Driver, Ride, RideStatusLog } = require('../models');
const config = require('../config');
const logger = require('../utils/logger');

class RideMatchingService {
  constructor() {
    this.activeSearches = new Map(); // rideId -> { timeout, driversTried, maxDrivers }
    this.searchTimeouts = new Map(); // rideId -> timeoutId
  }

  /**
   * Find nearest available drivers
   * @param {number} lat - Pickup latitude
   * @param {number} lng - Pickup longitude
   * @param {number} radiusKm - Search radius in KM
   * @param {number} limit - Max drivers to return
   * @returns {Array} Sorted drivers by distance
   */
  async findNearbyDrivers(lat, lng, radiusKm = 5, limit = 10) {
    try {
      const drivers = await Driver.findAll({
        where: {
          is_online: true,
          is_available: true,
          registration_status: 'approved',
          current_ride_id: null,
          current_latitude: { [Op.ne]: null },
          current_longitude: { [Op.ne]: null },
        },
        include: [
          {
            association: 'user',
            attributes: ['id', 'full_name', 'phone', 'avatar_url'],
          },
          {
            association: 'vehicle',
            attributes: ['vehicle_number', 'model', 'color'],
          },
        ],
        limit,
        order: [['total_rides', 'DESC']],
      });

      const driversWithDistance = drivers
        .map((driver) => {
          const distance = this._calculateDistance(
            lat,
            lng,
            parseFloat(driver.current_latitude),
            parseFloat(driver.current_longitude)
          );
          return { driver, distance_km: distance };
        })
        .filter((d) => d.distance_km <= radiusKm)
        .sort((a, b) => a.distance_km - b.distance_km);

      return driversWithDistance;
    } catch (error) {
      logger.error('Error finding nearby drivers:', error);
      throw error;
    }
  }

  /**
   * Start searching for a driver for a ride
   */
  async startSearch(ride, onDriverFound, onNoDrivers) {
    const rideId = ride.id;
    const searchConfig = {
      rideId,
      driversTried: new Set(),
      maxDrivers: 10,
      currentIndex: 0,
      nearbyDrivers: [],
    };
    this.activeSearches.set(rideId, searchConfig);

    const nearbyDrivers = await this.findNearbyDrivers(
      parseFloat(ride.pickup_latitude),
      parseFloat(ride.pickup_longitude),
      5,
      searchConfig.maxDrivers
    );

    if (nearbyDrivers.length === 0) {
      logger.info(`No nearby drivers found for ride ${ride.ride_number}`);
      await this._handleNoDrivers(ride, onNoDrivers);
      return;
    }

    searchConfig.nearbyDrivers = nearbyDrivers;
    searchConfig.currentIndex = 0;
    logger.info(`Found ${nearbyDrivers.length} nearby drivers for ride ${ride.ride_number}`);

    await this._sendRequestToNextDriver(rideId, onDriverFound, onNoDrivers);

    const timeoutId = setTimeout(async () => {
      await this._handleSearchTimeout(rideId, onNoDrivers);
    }, 60000);
    this.searchTimeouts.set(rideId, timeoutId);
  }

  async _sendRequestToNextDriver(rideId, onDriverFound, onNoDrivers) {
    const search = this.activeSearches.get(rideId);
    if (!search || search.currentIndex >= search.nearbyDrivers.length) {
      await this._handleNoDrivers(rideId, onNoDrivers);
      return;
    }
    const { driver, distance_km } = search.nearbyDrivers[search.currentIndex];
    search.currentIndex++;
    search.driversTried.add(driver.id);
    logger.info(`Sending ride request to driver ${driver.id} (attempt ${search.currentIndex}/${search.nearbyDrivers.length})`);
    return { driver, distance_km, search };
  }

  async handleDriverAccept(rideId, driverId) {
    const search = this.activeSearches.get(rideId);
    if (!search) {
      logger.warn(`No active search for ride ${rideId}`);
      return null;
    }

    const timeoutId = this.searchTimeouts.get(rideId);
    if (timeoutId) {
      clearTimeout(timeoutId);
      this.searchTimeouts.delete(rideId);
    }

    const ride = await Ride.findByPk(rideId);
    if (!ride || ride.status !== 'searching') {
      logger.warn(`Ride ${rideId} is no longer in searching state`);
      return null;
    }

    ride.driver_id = driverId;
    ride.status = 'driver_assigned';
    ride.driver_assigned_at = new Date();
    await ride.save();

    await RideStatusLog.create({
      ride_id: rideId,
      previous_status: 'searching',
      new_status: 'driver_assigned',
      changed_by: 'driver',
      changed_by_id: driverId,
    });

    await Driver.update(
      { is_available: false, current_ride_id: rideId },
      { where: { id: driverId } }
    );

    this.activeSearches.delete(rideId);
    logger.info(`Driver ${driverId} accepted ride ${ride.ride_number}`);
    return ride;
  }

  async handleDriverReject(rideId, driverId) {
    const search = this.activeSearches.get(rideId);
    if (!search) return;
    const result = await this._sendRequestToNextDriver(rideId, null, null);
    return result;
  }

  async _handleNoDrivers(rideOrId, onNoDrivers) {
    const rideId = typeof rideOrId === 'object' ? rideOrId.id : rideOrId;
    const ride = await Ride.findByPk(rideId);
    if (ride && ride.status === 'searching') {
      ride.status = 'no_driver_found';
      await ride.save();
      await RideStatusLog.create({
        ride_id: rideId,
        previous_status: 'searching',
        new_status: 'no_driver_found',
        changed_by: 'system',
      });
    }
    this._cleanup(rideId);
    if (onNoDrivers) onNoDrivers(ride);
  }

  async _handleSearchTimeout(rideId, onNoDrivers) {
    const search = this.activeSearches.get(rideId);
    if (!search) return;
    const ride = await Ride.findByPk(rideId);
    if (ride && ride.status === 'searching') {
      ride.status = 'no_driver_found';
      await ride.save();
      await RideStatusLog.create({
        ride_id: rideId,
        previous_status: 'searching',
        new_status: 'no_driver_found',
        changed_by: 'system',
        metadata: { reason: 'search_timeout' },
      });
    }
    this._cleanup(rideId);
    if (onNoDrivers) onNoDrivers(ride);
  }

  cancelSearch(rideId) { this._cleanup(rideId); }

  _cleanup(rideId) {
    this.activeSearches.delete(rideId);
    const timeoutId = this.searchTimeouts.get(rideId);
    if (timeoutId) { clearTimeout(timeoutId); this.searchTimeouts.delete(rideId); }
  }

  _calculateDistance(lat1, lng1, lat2, lng2) {
    const R = 6371;
    const dLat = this._toRad(lat2 - lat1);
    const dLng = this._toRad(lng2 - lng1);
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(this._toRad(lat1)) *
        Math.cos(this._toRad(lat2)) *
        Math.sin(dLng / 2) *
        Math.sin(dLng / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  _toRad(deg) { return deg * (Math.PI / 180); }
}

module.exports = new RideMatchingService();