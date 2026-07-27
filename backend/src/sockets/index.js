/**
 * Socket.IO Setup
 * Real-time communication for ride matching, live tracking, chat.
 */

const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');
const config = require('../config');
const { User, Driver, Customer, Ride, ChatMessage } = require('../models');
const { sendPushNotification } = require('../services/FirebaseService');
const logger = require('../utils/logger');

let io = null;
const userSockets = new Map();
const socketUsers = new Map();

function setupSocketIO(server) {
  io = new Server(server, {
    cors: {
      origin: config.corsOrigins,
      methods: ['GET', 'POST'],
      credentials: true,
    },
    pingTimeout: 60000,
    pingInterval: 25000,
    transports: ['websocket', 'polling'],
  });

  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth?.token || socket.handshake.query?.token;
      if (!token) {
        return next(new Error('Authentication required'));
      }

      const decoded = jwt.verify(token, config.jwt.secret);
      const user = await User.findByPk(decoded.userId);

      if (!user || !user.is_active || user.is_blocked) {
        return next(new Error('User not found or blocked'));
      }

      socket.userId = user.id;
      socket.userRole = user.role;
      socket.user = user;
      next();
    } catch (error) {
      logger.error('Socket auth error:', error.message);
      next(new Error('Authentication failed'));
    }
  });

// Rooms are joined as `user:<users.id>`, but ride.customer_id points at the
// customers table. Emitting to `user:${ride.customer_id}` therefore goes to a
// room nobody is in, so the customer silently misses live-tracking, arrival,
// start and completion events. Resolve the real user id first.
async function customerRoom(ride) {
  try {
    if (!ride) return null;
    const c = await Customer.findByPk(ride.customer_id, { attributes: ['user_id'] });
    return c ? `user:${c.user_id}` : null;
  } catch (e) {
    return null;
  }
}

  io.on('connection', (socket) => {
    const { userId, userRole } = socket;

    if (!userSockets.has(userId)) {
      userSockets.set(userId, new Set());
    }
    userSockets.get(userId).add(socket.id);
    socketUsers.set(socket.id, { userId, role: userRole });

    logger.info(`Socket connected: user=${userId} role=${userRole} socket=${socket.id}`);

    socket.join(`user:${userId}`);
    socket.join(`role:${userRole}`);

    // Driver: Location Updates
    socket.on('driver:location_update', async (data) => {
      if (userRole !== 'driver') return;

      const { latitude, longitude } = data;
      try {
        await Driver.update(
          { current_latitude: latitude, current_longitude: longitude, last_location_update: new Date() },
          { where: { user_id: userId } }
        );

        const driver = await Driver.findOne({
          where: { user_id: userId },
          attributes: ['id', 'current_latitude', 'current_longitude', 'current_ride_id'],
        });

        if (driver && driver.current_ride_id) {
          const ride = await Ride.findByPk(driver.current_ride_id, {
            attributes: ['id', 'customer_id'],
          });
          if (ride) {
            const room = await customerRoom(ride);
            if (room) io.to(room).emit('ride:driver_location', {
              ride_id: ride.id,
              driver_id: driver.id,
              latitude,
              longitude,
              timestamp: new Date(),
            });
          }
        }

        socket.broadcast.emit('driver:available', {
          driver_id: driver?.id,
          latitude,
          longitude,
        });
      } catch (error) {
        logger.error('Location update error:', error);
      }
    });

    // Driver: Go Online/Offline
    socket.on('driver:go_online', async () => {
      if (userRole !== 'driver') return;
      await Driver.update({ is_online: true, is_available: true }, { where: { user_id: userId } });
      socket.emit('driver:status_changed', { is_online: true, is_available: true });
      logger.info(`Driver ${userId} went online`);
    });

    socket.on('driver:go_offline', async () => {
      if (userRole !== 'driver') return;
      await Driver.update({ is_online: false, is_available: false }, { where: { user_id: userId } });
      socket.emit('driver:status_changed', { is_online: false, is_available: false });
      logger.info(`Driver ${userId} went offline`);
    });

    // Driver accepts ride
    socket.on('ride:accept', async (data) => {
      if (userRole !== 'driver') return;

      const { ride_id } = data;
      const driver = await Driver.findOne({ where: { user_id: userId } });

      if (!driver || !driver.canAcceptRides()) {
        socket.emit('ride:accept_error', { message: 'You cannot accept rides at this time' });
        return;
      }

      try {
        const RideMatchingService = require('../services/RideMatchingService');
        const ride = await RideMatchingService.handleDriverAccept(ride_id, driver.id);
        if (!ride) {
          socket.emit('ride:accept_error', { message: 'This ride is no longer available' });
          return;
        }
        if (ride) {
          const room = await customerRoom(ride);
          if (room) io.to(room).emit('ride:accepted', {
            ride_id: ride.id,
            driver: {
              id: driver.id,
              name: socket.user?.full_name,
              phone: socket.user?.phone,
              latitude: driver.current_latitude,
              longitude: driver.current_longitude,
              vehicle: await driver.getVehicle(),
            },
          });

          socket.emit('ride:accepted_confirmation', { ride_id: ride.id });
          logger.info(`Driver ${driver.id} accepted ride ${ride_id}`);
        }
      } catch (error) {
        logger.error('Ride accept error:', error);
        socket.emit('ride:accept_error', { message: 'Failed to accept ride: ' + (error.message || 'unknown error') });
      }
    });

    // Driver rejects ride
    socket.on('ride:reject', async (data) => {
      if (userRole !== 'driver') return;
      const { ride_id } = data;
      logger.info(`Driver ${userId} declined ride ${ride_id}`);
      socket.emit('ride:reject_ack', { ride_id });
    });

    // Ride Status Updates (Driver)
    socket.on('ride:arrived', async (data) => {
      if (userRole !== 'driver') return;
      const { ride_id } = data;
      const ride = await Ride.findByPk(ride_id);
      if (ride && ride.status === 'driver_assigned') {
        ride.status = 'driver_arrived';
        ride.driver_arrived_at = new Date();
        await ride.save();

        const { RideStatusLog } = require('../models');
        await RideStatusLog.create({
          ride_id, previous_status: 'driver_assigned', new_status: 'driver_arrived',
          changed_by: 'driver', changed_by_id: userId,
        });

        const room = await customerRoom(ride);
        if (room) io.to(room).emit('ride:driver_arrived', { ride_id });
        socket.emit('ride:status_updated', { ride_id, status: 'driver_arrived' });
        
        // Push
        try { const c = await ride.getCustomer({ include: [{ association: 'user', attributes: ['id'] }] }); if (c?.user?.id) await sendPushNotification(c.user.id, '🚖 Driver Arrived', 'Your driver has arrived at the pickup location!', { ride_id: ride.id.toString(), type: 'driver_arrived' }); } catch(e) {}
      }
    });

    socket.on('ride:start', async (data) => {
      if (userRole !== 'driver') return;
      const { ride_id } = data;
      const ride = await Ride.findByPk(ride_id);
      if (ride && ride.status === 'driver_arrived') {
        ride.status = 'started';
        ride.ride_started_at = new Date();
        await ride.save();

        const { RideStatusLog } = require('../models');
        await RideStatusLog.create({
          ride_id, previous_status: 'driver_arrived', new_status: 'started',
          changed_by: 'driver', changed_by_id: userId,
        });

        const room = await customerRoom(ride);
        if (room) io.to(room).emit('ride:started', { ride_id });
        socket.emit('ride:status_updated', { ride_id, status: 'started' });
        
        // Push
        try { const c = await ride.getCustomer({ include: [{ association: 'user', attributes: ['id'] }] }); if (c?.user?.id) await sendPushNotification(c.user.id, '🚖 Ride Started', 'Your ride has started! Enjoy the trip.', { ride_id: ride.id.toString(), type: 'ride_started' }); } catch(e) {}
      }
    });

    socket.on('ride:complete', async (data) => {
      if (userRole !== 'driver') return;
      const { ride_id } = data;
      const ride = await Ride.findByPk(ride_id);
      if (ride && ride.status === 'started') {
        ride.status = 'completed';
        ride.ride_completed_at = new Date();
        await ride.save();

        const { RideStatusLog } = require('../models');
        await RideStatusLog.create({
          ride_id, previous_status: 'started', new_status: 'completed',
          changed_by: 'driver', changed_by_id: userId,
        });

        // Accrue earnings and commission.
        //
        // Nothing used to do this: total_earnings, total_rides and
        // commission_due all stayed at 0 forever no matter how many rides
        // were completed, so the commission system could never trigger.
        // PaymentService._processEarnings() was written for this but is dead
        // code - nothing in the codebase ever calls it - and it ASSIGNS
        // total_earnings instead of adding to it, which would wipe the
        // running total on every ride.
        //
        // Literal increments keep this atomic, so two concurrent completions
        // cannot clobber each other.
        try {
          const seq = require('sequelize');
          const earned = parseFloat(ride.driver_earnings || 0);
          const commission = parseFloat(ride.commission_amount || 0);
          await Driver.update(
            {
              is_available: true,
              current_ride_id: null,
              total_rides: seq.literal('total_rides + 1'),
              total_earnings: seq.literal('total_earnings + ' + earned),
              commission_due: seq.literal('commission_due + ' + commission),
            },
            { where: { id: ride.driver_id } }
          );
          logger.info('Ride ' + ride.ride_number + ': driver credited ' + earned + ', commission due +' + commission);
        } catch (e) {
          logger.error('Earnings accrual failed for ride ' + ride.ride_number + ': ' + e.message);
          // Never leave the driver stuck on a finished ride.
          await Driver.update(
            { is_available: true, current_ride_id: null },
            { where: { id: ride.driver_id } }
          );
        }

        const room = await customerRoom(ride);
        if (room) io.to(room).emit('ride:completed', {
          ride_id,
          total_fare: ride.total_fare,
          payment_method: ride.payment_method,
        });
        socket.emit('ride:status_updated', { ride_id, status: 'completed' });
        
        // Push
        try { const c = await ride.getCustomer({ include: [{ association: 'user', attributes: ['id'] }] }); if (c?.user?.id) await sendPushNotification(c.user.id, '✅ Ride Complete', 'Your ride is complete! Fare: ₹' + ride.total_fare, { ride_id: ride.id.toString(), type: 'ride_completed' }); } catch(e) {}
        try { const d = await ride.getDriver({ include: [{ association: 'user', attributes: ['id'] }] }); if (d?.user?.id) await sendPushNotification(d.user.id, '✅ Ride Complete', 'Ride completed! You earned ₹' + ride.driver_earnings, { ride_id: ride.id.toString(), type: 'ride_completed' }); } catch(e) {}
      }
    });

    // Chat: Driver-Customer
    socket.on('chat:send', async (data) => {
      const { ride_id, message, message_type = 'text' } = data;
      try {
        const ride = await Ride.findByPk(ride_id);
        if (!ride) return;

        const customer = await Customer.findOne({ where: { user_id: userId } });
        const driver = await Driver.findOne({ where: { user_id: userId } });
        const isParticipant =
          (customer && ride.customer_id === customer.id) ||
          (driver && ride.driver_id === driver.id);

        if (!isParticipant) return;

        const chatMessage = await ChatMessage.create({
          ride_id,
          sender_id: userId,
          sender_role: userRole,
          message,
          message_type,
        });

        const otherUserId =
          userRole === 'customer'
            ? await _getDriverUserId(ride.driver_id)
            : await _getCustomerUserId(ride.customer_id);

        if (otherUserId) {
          io.to(`user:${otherUserId}`).emit('chat:received', {
            id: chatMessage.id,
            ride_id,
            sender_id: userId,
            sender_role: userRole,
            message,
            message_type,
            created_at: chatMessage.created_at,
          });
        }

        socket.emit('chat:sent', {
          id: chatMessage.id,
          ride_id,
          message,
          created_at: chatMessage.created_at,
        });
      } catch (error) {
        logger.error('Chat error:', error);
        socket.emit('chat:error', { message: 'Failed to send message' });
      }
    });

    socket.on('chat:mark_read', async (data) => {
      const { ride_id } = data;
      await ChatMessage.update(
        { is_read: true, read_at: new Date() },
        { where: { ride_id, sender_id: { [require('sequelize').Op.ne]: userId }, is_read: false } }
      );
    });

    // Disconnect
    socket.on('disconnect', () => {
      logger.info(`Socket disconnected: user=${userId} socket=${socket.id}`);

      const userSocketSet = userSockets.get(userId);
      if (userSocketSet) {
        userSocketSet.delete(socket.id);
        if (userSocketSet.size === 0) {
          userSockets.delete(userId);
          if (userRole === 'driver') {
            Driver.update({ is_online: false }, { where: { user_id: userId } }).catch(() => {});
          }
        }
      }
      socketUsers.delete(socket.id);
    });
  });

  io._instance = io;
  logger.info('Socket.IO initialized');
  return io;
}

async function _getDriverUserId(driverId) {
  if (!driverId) return null;
  const driver = await Driver.findByPk(driverId, { attributes: ['user_id'] });
  return driver?.user_id;
}

async function _getCustomerUserId(customerId) {
  if (!customerId) return null;
  const customer = await Customer.findByPk(customerId, { attributes: ['user_id'] });
  return customer?.user_id;
}

function getIO() {
  return io;
}

function emitToUser(userId, event, data) {
  if (io) {
    io.to(`user:${userId}`).emit(event, data);
  }
}

function emitToRole(role, event, data) {
  if (io) {
    io.to(`role:${role}`).emit(event, data);
  }
}

module.exports = {
  setupSocketIO,
  getIO,
  emitToUser,
  emitToRole,
};