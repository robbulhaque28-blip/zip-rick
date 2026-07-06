/**
 * FareService
 * Calculates ride fares based on configurable pricing rules.
 * Handles base fare, per-km, per-minute, night charges, peak pricing.
 */

const config = require('../config');
const { SystemSetting } = require('../models');
const logger = require('../utils/logger');

class FareService {
  constructor() {
    this.defaultRates = {
      base_fare: 30,
      per_km: 12,
      per_minute: 1,
      minimum_fare: 30,
      waiting_charge_per_min: 2,
      night_charge_multiplier: 1.5,
      night_start_hour: 22,
      night_end_hour: 6,
      peak_multiplier: 1.2,
      peak_hours: [
        { start: 8, end: 10 },
        { start: 17, end: 20 },
      ],
      cancellation_fee_customer: 10,
      cancellation_fee_driver: 5,
    };
  }

  /**
   * Load fare rates from system settings (cached)
   */
  async getRates() {
    try {
      const setting = await SystemSetting.findOne({ where: { key: 'fare_rates' } });
      if (setting && setting.value) {
        return { ...this.defaultRates, ...setting.value };
      }
    } catch (error) {
      logger.warn('Failed to load fare rates from DB, using defaults:', error.message);
    }
    return this.defaultRates;
  }

  /**
   * Check if current time is in night charge period
   */
  _isNightTime(hour, rates) {
    const start = rates.night_start_hour;
    const end = rates.night_end_hour;
    if (start > end) {
      return hour >= start || hour < end;
    }
    return hour >= start && hour < end;
  }

  /**
   * Check if current time is in peak hours
   */
  _isPeakTime(hour, rates) {
    return rates.peak_hours.some(({ start, end }) => hour >= start && hour < end);
  }

  /**
   * Calculate fare estimate
   * @param {Object} params
   * @param {number} params.distanceMeters - Distance in meters
   * @param {number} params.durationSeconds - Duration in seconds
   * @param {Object} [params.customRates] - Override rates
   * @param {boolean} [params.includeBreakdown] - Return full breakdown
   * @returns {Object} Fare estimate
   */
  async calculateFare({ distanceMeters, durationSeconds, customRates = null, includeBreakdown = true }) {
    const rates = customRates || await this.getRates();
    const now = new Date();
    const hour = now.getHours();

    // Convert units
    const distanceKm = distanceMeters / 1000;
    const durationMin = durationSeconds / 60;

    // Base fare
    const baseFare = parseFloat(rates.base_fare);

    // Distance fare
    const distanceFare = parseFloat((distanceKm * rates.per_km).toFixed(2));

    // Time fare
    const timeFare = parseFloat((durationMin * rates.per_minute).toFixed(2));

    // Night charges
    let nightCharges = 0;
    if (this._isNightTime(hour, rates)) {
      nightCharges = parseFloat(((baseFare + distanceFare) * (rates.night_charge_multiplier - 1)).toFixed(2));
    }

    // Peak pricing
    let peakCharges = 0;
    if (this._isPeakTime(hour, rates)) {
      peakCharges = parseFloat(((baseFare + distanceFare) * (rates.peak_multiplier - 1)).toFixed(2));
    }

    // Calculate total
    let total = baseFare + distanceFare + timeFare + nightCharges + peakCharges;

    // Apply minimum fare
    if (total < rates.minimum_fare) {
      total = parseFloat(rates.minimum_fare);
    }

    total = parseFloat(total.toFixed(2));

    const breakdown = {
      base_fare: baseFare,
      distance_fare: distanceFare,
      time_fare: timeFare,
      night_charges: nightCharges,
      peak_charges: peakCharges,
      waiting_charges: 0,
      promo_discount: 0,
      total_fare: total,
    };

    if (includeBreakdown) {
      return {
        ...breakdown,
        distance_km: parseFloat(distanceKm.toFixed(2)),
        duration_min: parseFloat(durationMin.toFixed(1)),
        rates_applied: {
          base_fare: rates.base_fare,
          per_km: rates.per_km,
          per_minute: rates.per_minute,
          minimum_fare: rates.minimum_fare,
          is_night_charge_applied: nightCharges > 0,
          is_peak_pricing_applied: peakCharges > 0,
        },
      };
    }

    return {
      total_fare: total,
      breakdown,
    };
  }

  /**
   * Apply promo code discount to fare
   */
  async applyPromo(totalFare, promoCode) {
    const { PromoCode, PromoRedemption } = require('../models');
    
    const promo = await PromoCode.findOne({
      where: {
        code: promoCode,
        is_active: true,
        starts_at: { [require('sequelize').Op.lte]: new Date() },
        expires_at: { [require('sequelize').Op.gte]: new Date() },
      },
    });

    if (!promo) {
      return { discount: 0, promo_applied: false, message: 'Invalid or expired promo code' };
    }

    if (promo.max_uses && promo.usage_count >= promo.max_uses) {
      return { discount: 0, promo_applied: false, message: 'Promo code usage limit reached' };
    }

    let discount = 0;
    if (promo.discount_type === 'percentage') {
      discount = (totalFare * promo.discount_value) / 100;
      if (promo.max_discount && discount > promo.max_discount) {
        discount = parseFloat(promo.max_discount);
      }
    } else {
      discount = parseFloat(promo.discount_value);
    }

    if (discount > totalFare) {
      discount = totalFare;
    }

    return {
      discount: parseFloat(discount.toFixed(2)),
      promo_applied: true,
      promo_code_id: promo.id,
      promo,
    };
  }

  /**
   * Calculate waiting charges
   */
  calculateWaitingCharge(waitingMinutes, rates = null) {
    const perMin = rates?.waiting_charge_per_min || this.defaultRates.waiting_charge_per_min;
    const freeMinutes = 5; // First 5 minutes free
    const chargeableMinutes = Math.max(0, waitingMinutes - freeMinutes);
    return parseFloat((chargeableMinutes * perMin).toFixed(2));
  }
}

module.exports = new FareService();
