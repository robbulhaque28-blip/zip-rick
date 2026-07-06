/**
 * PaymentService
 * Handles Razorpay integration, UPI payments, cash payments,
 * commission deductions, wallet operations, and refunds.
 */

const Razorpay = require('razorpay');
const crypto = require('crypto');
const config = require('../config');
const { Payment, Ride, Wallet, Transaction, Driver } = require('../models');
const { ApiError } = require('../middleware/errorHandler');
const logger = require('../utils/logger');

let razorpayInstance = null;

function getRazorpay() {
  if (!razorpayInstance) {
    if (config.razorpay.keyId && config.razorpay.keySecret) {
      razorpayInstance = new Razorpay({
        key_id: config.razorpay.keyId,
        key_secret: config.razorpay.keySecret,
      });
    } else {
      logger.warn('Razorpay not configured. Payment features limited.');
    }
  }
  return razorpayInstance;
}

class PaymentService {
  /**
   * Create Razorpay order for UPI payment
   */
  async createRazorpayOrder(amount, receipt, notes = {}) {
    const razorpay = getRazorpay();
    if (!razorpay) {
      throw new ApiError(500, 'Payment gateway not configured', 'PAYMENT_CONFIG_ERROR');
    }

    try {
      const order = await razorpay.orders.create({
        amount: Math.round(amount * 100), // Razorpay expects paise
        currency: 'INR',
        receipt,
        notes,
        payment_capture: 1,
      });

      logger.info(`Razorpay order created: ${order.id}`);
      return order;
    } catch (error) {
      logger.error('Razorpay order creation failed:', error);
      throw new ApiError(500, 'Failed to create payment order', 'RAZORPAY_ORDER_FAILED');
    }
  }

  /**
   * Verify Razorpay payment signature
   */
  verifyPaymentSignature(orderId, paymentId, signature) {
    const body = `${orderId}|${paymentId}`;
    const expectedSignature = crypto
      .createHmac('sha256', config.razorpay.keySecret)
      .update(body)
      .digest('hex');

    return expectedSignature === signature;
  }

  /**
   * Process ride payment
   */
  async processRidePayment(ride, paymentMethod = 'cash', razorpayParams = null) {
    const db = require('../models');

    const paymentData = {
      ride_id: ride.id,
      customer_id: ride.customer_id,
      driver_id: ride.driver_id,
      amount: ride.total_fare,
      commission: ride.commission_amount,
      driver_amount: ride.driver_earnings,
      payment_method: paymentMethod,
      payment_status: paymentMethod === 'cash' ? 'pending' : 'processing',
    };

    if (paymentMethod === 'upi' && razorpayParams) {
      const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = razorpayParams;
      
      // Verify signature
      if (!this.verifyPaymentSignature(razorpay_order_id, razorpay_payment_id, razorpay_signature)) {
        throw new ApiError(400, 'Payment signature verification failed', 'PAYMENT_VERIFICATION_FAILED');
      }

      paymentData.razorpay_order_id = razorpay_order_id;
      paymentData.razorpay_payment_id = razorpay_payment_id;
      paymentData.razorpay_signature = razorpay_signature;
      paymentData.payment_status = 'completed';
      paymentData.paid_at = new Date();
    }

    const payment = await Payment.create(paymentData);

    // Update ride payment status
    await Ride.update(
      {
        payment_method: paymentMethod,
        payment_status: paymentData.payment_status,
      },
      { where: { id: ride.id } }
    );

    // If payment completed, process wallet transactions
    if (paymentData.payment_status === 'completed') {
      await this._processEarnings(ride);
    }

    logger.info(`Payment processed for ride ${ride.ride_number}: ${paymentMethod} ${paymentData.payment_status}`);

    return payment;
  }

  /**
   * Process driver earnings and commission
   */
  async _processEarnings(ride) {
    // Credit driver wallet with earnings
    const driverWallet = await Wallet.findOne({
      where: { user_id: ride.driver_id },
      include: [{ association: 'user', where: { role: 'driver' } }],
    });

    if (driverWallet) {
      // Instead of driver wallet, use the Driver model's total_earnings
      // In production, this would credit the driver's actual wallet
      await Driver.update(
        {
          total_earnings: parseFloat(ride.driver_earnings),
          total_rides: require('sequelize').literal('total_rides + 1'),
        },
        { where: { id: ride.driver_id } }
      );

      // Record transaction
      await Transaction.create({
        user_id: driverWallet.user_id,
        type: 'ride_earning',
        amount: ride.driver_earnings,
        reference_type: 'ride',
        reference_id: ride.id,
        description: `Earnings for ride ${ride.ride_number}`,
        status: 'completed',
      });

      // Record commission transaction
      await Transaction.create({
        user_id: driverWallet.user_id,
        type: 'commission_deduction',
        amount: ride.commission_amount,
        reference_type: 'ride',
        reference_id: ride.id,
        description: `Commission for ride ${ride.ride_number}`,
        status: 'completed',
      });
    }

    // Update customer total spent
    const { Customer } = require('../models');
    await Customer.update(
      {
        total_spent: require('sequelize').literal(`total_spent + ${ride.total_fare}`),
        total_rides: require('sequelize').literal('total_rides + 1'),
      },
      { where: { id: ride.customer_id } }
    );
  }

  /**
   * Process driver registration fee payment
   */
  async processRegistrationFee(driverId, amount, razorpayParams) {
    const { DriverRegistrationPayment } = require('../models');
    const { User } = require('../models');

    const driver = await Driver.findByPk(driverId, { include: [{ association: 'user' }] });
    if (!driver) {
      throw new ApiError(404, 'Driver not found', 'DRIVER_NOT_FOUND');
    }

    if (driver.registration_fee_paid) {
      throw new ApiError(400, 'Registration fee already paid', 'FEE_ALREADY_PAID');
    }

    let paymentRecord;

    if (razorpayParams) {
      const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = razorpayParams;

      if (!this.verifyPaymentSignature(razorpay_order_id, razorpay_payment_id, razorpay_signature)) {
        throw new ApiError(400, 'Payment verification failed', 'PAYMENT_VERIFICATION_FAILED');
      }

      paymentRecord = await DriverRegistrationPayment.create({
        driver_id: driverId,
        amount,
        payment_method: 'upi',
        payment_status: 'completed',
        razorpay_order_id,
        razorpay_payment_id,
        razorpay_signature,
      });

      // Update driver
      driver.registration_fee_paid = true;
      driver.registration_fee_amount = amount;
      await driver.save();

      // Record transaction
      await Transaction.create({
        user_id: driver.user_id,
        type: 'registration_fee',
        amount,
        reference_type: 'registration',
        reference_id: paymentRecord.id,
        description: 'Driver registration fee payment',
        status: 'completed',
      });
    }

    logger.info(`Registration fee processed for driver ${driverId}: ₹${amount}`);

    return paymentRecord;
  }

  /**
   * Process refund for a payment
   */
  async processRefund(paymentId, reason = '') {
    const payment = await Payment.findByPk(paymentId);
    if (!payment) {
      throw new ApiError(404, 'Payment not found', 'PAYMENT_NOT_FOUND');
    }

    if (payment.payment_status === 'refunded') {
      throw new ApiError(400, 'Payment already refunded', 'ALREADY_REFUNDED');
    }

    const razorpay = getRazorpay();
    let refundId = null;

    if (payment.razorpay_payment_id && razorpay) {
      try {
        const refund = await razorpay.payments.refund(payment.razorpay_payment_id, {
          amount: Math.round(parseFloat(payment.amount) * 100),
          notes: { reason },
        });
        refundId = refund.id;
      } catch (error) {
        logger.error('Razorpay refund failed:', error);
        throw new ApiError(500, 'Refund processing failed', 'REFUND_FAILED');
      }
    }

    payment.payment_status = 'refunded';
    payment.refund_id = refundId;
    payment.refund_amount = payment.amount;
    payment.refund_reason = reason;
    await payment.save();

    // Record refund transaction
    const ride = await Ride.findByPk(payment.ride_id);
    if (ride) {
      await Transaction.create({
        user_id: payment.customer_id,
        type: 'refund',
        amount: payment.amount,
        reference_type: 'ride',
        reference_id: ride.id,
        description: `Refund for ride ${ride.ride_number}`,
        status: 'completed',
      });
    }

    logger.info(`Refund processed for payment ${paymentId}: ₹${payment.amount}`);

    return payment;
  }
}

module.exports = new PaymentService();
