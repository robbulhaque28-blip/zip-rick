const { Op } = require('sequelize');
const { Driver, Ride, RideStatusLog } = require('../models');
const { getIO } = require('../sockets');
const logger = require('../utils/logger');

class RideMatchingService {
  constructor() {
    this.activeSearches = new Map();
    this.searchTimeouts = new Map();
  }

  async findNearbyDrivers(lat, lng, radiusKm = 2, limit = 10) {
    const drivers = await Driver.findAll({
      where: {
        is_online: true,
        is_available: true,
        registration_status: 'approved',
        current_ride_id: null,
        current_latitude: { [Op.ne]: null }
      },
      include: [
        { association: 'user', attributes: ['id', 'full_name', 'phone', 'avatar_url'] },
        { association: 'vehicle' }
      ],
      limit,
    });
    const R = 6371;
    return drivers.map(d => {
      const dLat = (parseFloat(d.current_latitude) - lat) * Math.PI / 180;
      const dLng = (parseFloat(d.current_longitude) - lng) * Math.PI / 180;
      const a = Math.sin(dLat/2)**2 + Math.cos(lat*Math.PI/180) * Math.cos(parseFloat(d.current_latitude)*Math.PI/180) * Math.sin(dLng/2)**2;
      const dist = R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
      return { driver: d, distance_km: dist };
    }).filter(d => d.distance_km <= radiusKm).sort((a, b) => a.distance_km - b.distance_km);
  }

  async startSearch(ride, onDriverFound, onNoDrivers) {
    const nearby = await this.findNearbyDrivers(
      parseFloat(ride.pickup_latitude),
      parseFloat(ride.pickup_longitude)
    );
    
    if (nearby.length === 0) {
      ride.status = 'no_driver_found';
      await ride.save();
      logger.info(`No nearby drivers for ride ${ride.ride_number}`);
      if (onNoDrivers) onNoDrivers(ride);
      return;
    }

    this.activeSearches.set(ride.id, {
      rideId: ride.id,
      nearby,
      index: 0,
      rideData: {
        id: ride.id,
        ride_number: ride.ride_number,
        pickup_latitude: ride.pickup_latitude,
        pickup_longitude: ride.pickup_longitude,
        pickup_address: ride.pickup_address,
        drop_latitude: ride.drop_latitude,
        drop_longitude: ride.drop_longitude,
        drop_address: ride.drop_address,
        total_fare: ride.total_fare,
        route_distance: ride.route_distance,
        route_duration: ride.route_duration,
        payment_method: ride.payment_method,
      }
    });

    // Emit socket event to each nearby driver
    const io = getIO();
    if (io) {
      for (const entry of nearby) {
        const driverUserId = entry.driver.user_id;
        const room = `user:${driverUserId}`;
        io.to(room).emit('ride:new_request', {
          ride_id: ride.id,
          ride_number: ride.ride_number,
          pickup_address: ride.pickup_address,
          pickup_latitude: ride.pickup_latitude,
          pickup_longitude: ride.pickup_longitude,
          drop_address: ride.drop_address,
          drop_latitude: ride.drop_latitude,
          drop_longitude: ride.drop_longitude,
          total_fare: ride.total_fare,
          distance_km: parseFloat(entry.distance_km.toFixed(1)),
          route_distance: ride.route_distance,
          route_duration: ride.route_duration,
          payment_method: ride.payment_method,
          driver_name: entry.driver.user?.full_name,
          customer_pickup: ride.pickup_address,
          customer_drop: ride.drop_address,
        });
        logger.info(`Ride request ${ride.ride_number} sent to driver ${driverUserId} (${entry.distance_km.toFixed(1)}km away)`);
      }
    }

    // Set 60-second timeout: if no driver accepts, mark as no_driver_found
    const tid = setTimeout(async () => {
      // Re-check ride status — maybe a driver already accepted
      const currentRide = await Ride.findByPk(ride.id);
      if (currentRide && currentRide.status === 'searching') {
        currentRide.status = 'no_driver_found';
        await currentRide.save();
        logger.info(`Ride ${ride.ride_number}: No driver accepted within timeout`);
        if (onNoDrivers) onNoDrivers(currentRide);
      }
      this._cleanup(ride.id);
    }, 60000);
    this.searchTimeouts.set(ride.id, tid);

    logger.info(`Search started for ride ${ride.ride_number}: ${nearby.length} nearby drivers notified via socket`);
  }

  async handleDriverAccept(rideId, driverId) {
    const ride = await Ride.findByPk(rideId);
    if (!ride || ride.status !== 'searching') return null;
    
    ride.driver_id = driverId;
    ride.status = 'driver_assigned';
    ride.driver_assigned_at = new Date();
    await ride.save();
    
    await RideStatusLog.create({
      ride_id: rideId,
      previous_status: 'searching',
      new_status: 'driver_assigned',
      changed_by: 'driver',
      changed_by_id: driverId
    });
    
    await Driver.update(
      { is_available: false, current_ride_id: rideId },
      { where: { id: driverId } }
    );
    
    // Notify all other nearby drivers that this ride is taken
    const io = getIO();
    if (io) {
      const search = this.activeSearches.get(rideId);
      if (search) {
        for (const entry of search.nearby) {
          if (entry.driver.id !== driverId && entry.driver.user_id) {
            io.to(`user:${entry.driver.user_id}`).emit('ride:taken', { ride_id: rideId });
          }
        }
      }
      // Notify customer via their user_id
      const customer = await ride.getCustomer({ include: [{ association: 'user', attributes: ['id'] }] });
      const customerUserId = customer?.user?.id;
      const driver = await Driver.findByPk(driverId, {
        include: [{ association: 'user', attributes: ['id', 'full_name', 'phone', 'avatar_url'] }, { association: 'vehicle' }]
      });
      if (driver && customerUserId) {
        io.to(`user:${customerUserId}`).emit('ride:accepted', {
          ride_id: ride.id,
          driver: {
            id: driver.id,
            name: driver.user?.full_name || 'Driver',
            phone: driver.user?.phone,
            avatar_url: driver.user?.avatar_url,
            vehicle_number: driver.vehicle?.vehicle_number || '',
            vehicle_model: driver.vehicle?.vehicle_model || '',
            rating: driver.rating_avg,
          }
        });
      }
    }
    
    this._cleanup(rideId);
    logger.info(`Driver ${driverId} accepted ride ${ride.ride_number}`);
    return ride;
  }

  cancelSearch(rideId) {
    this._cleanup(rideId);
  }

  _cleanup(rideId) {
    this.activeSearches.delete(rideId);
    const t = this.searchTimeouts.get(rideId);
    if (t) {
      clearTimeout(t);
      this.searchTimeouts.delete(rideId);
    }
  }
}

module.exports = new RideMatchingService();
