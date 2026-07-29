const fareRates = Object.freeze({
  // Single ride rates
  single_base_fare: 30, single_per_km: 12, single_per_minute: 1,
  // Sharing ride rates  
  sharing_base_fare: 20, sharing_per_km: 8, sharing_per_minute: 0.5,
  // Common
  minimum_fare: 30,
  waiting_charge_per_min: 2, night_charge_multiplier: 1.5,
  night_start_hour: 22, night_end_hour: 6, peak_multiplier: 1.2,
  peak_hours: [{ start: 8, end: 10 }, { start: 17, end: 20 }],
  cancellation_fee_customer: 10,
  sharing_multiplier: 0.7,
});

/**
 * Round a fare to a whole rupee.
 *
 * Business rule: anything up to and including .50 rounds DOWN, anything
 * above .50 rounds UP. So 45.30 and 45.50 both become 45, while 45.51 and
 * 45.60 become 46.
 *
 * Note this is NOT Math.round(), which would push 45.50 up to 46. Using
 * Math.ceil(x - 0.5) puts the .50 case in the customer's favour, and keeps
 * cash amounts clean for drivers - no paise to hand back.
 */
function roundFare(amount) {
  const n = parseFloat(amount);
  if (!Number.isFinite(n)) return 0;
  if (n <= 0) return 0;
  return Math.max(0, Math.ceil(n - 0.5));
}

async function getRates() {
  try {
    const { SystemSetting } = require("../models");
    const s = await SystemSetting.findOne({ where: { key: "fare_rates" } });
    if (s && s.value) return { ...fareRates, ...s.value };
  } catch (e) {}
  return fareRates;
}

async function calculateFare(params) {
  const rates = await getRates();
  const h = new Date().getHours();
  const dk = params.distanceMeters / 1000;
  const dm = params.durationSeconds / 60;
  const isSharing = params.ride_mode === 'sharing';
  
  const b = parseFloat(isSharing ? rates.sharing_base_fare : rates.single_base_fare);
  const df = parseFloat((dk * (isSharing ? rates.sharing_per_km : rates.single_per_km)).toFixed(2));
  const tf = parseFloat((dm * (isSharing ? rates.sharing_per_minute : rates.single_per_minute)).toFixed(2));
  
  let nc = 0, pc = 0;
  if (h >= rates.night_start_hour || h < rates.night_end_hour)
    nc = parseFloat(((b + df) * (rates.night_charge_multiplier - 1)).toFixed(2));
  if (rates.peak_hours.some(function(x) { return h >= x.start && h < x.end; }))
    pc = parseFloat(((b + df) * (rates.peak_multiplier - 1)).toFixed(2));
  
  let total = b + df + tf + nc + pc;
  if (total < rates.minimum_fare) total = parseFloat(rates.minimum_fare);

  // Customers and drivers only ever deal in whole rupees.
  total = roundFare(total);

  return {
    base_fare: b, distance_fare: df, time_fare: tf,
    night_charges: nc, peak_charges: pc,
    waiting_charges: 0, promo_discount: 0,
    total_fare: total,
    ride_mode: isSharing ? 'sharing' : 'single'
  };
}

/**
 * Apply a promo code to a fare.
 *
 * RideController has always called FareService.applyPromo(), but this
 * function never existed - so ANY request carrying a promo_code threw
 * "FareService.applyPromo is not a function" and returned a 500. Both the
 * fare estimate and the booking endpoint were affected, meaning promo codes
 * have never worked at all.
 *
 * An unknown, inactive or expired code is NOT an error: it simply yields no
 * discount, so a bad code can never block a booking.
 */
async function applyPromo(totalFare, code) {
  const none = { discount: 0, promo_applied: false, promo_code_id: null };
  try {
    if (!code || typeof code !== 'string') return none;

    const { PromoCode } = require('../models');
    const promo = await PromoCode.findOne({ where: { code: code.trim().toUpperCase() } });
    if (!promo) return none;

    // 'status' is the column in this schema; treat anything not active as off.
    if (promo.status && String(promo.status).toLowerCase() !== 'active') return none;

    if (promo.expiry_date && new Date(promo.expiry_date) < new Date()) return none;

    const fare = parseFloat(totalFare) || 0;
    const value = parseFloat(promo.discount) || 0;
    if (value <= 0) return none;

    let discount;
    if (String(promo.discount_type).toLowerCase() === 'percentage') {
      discount = fare * (value / 100);
    } else {
      discount = value;
    }

    // Never discount below zero, and never more than the fare itself.
    // Rounded to a whole rupee so a rounded fare minus the discount is still
    // a whole rupee - the customer never sees paise.
    discount = Math.max(0, Math.min(discount, fare));
    discount = roundFare(discount);
    if (discount <= 0) return none;

    return { discount, promo_applied: true, promo_code_id: promo.id };
  } catch (e) {
    // A promo lookup must never break a booking.
    return none;
  }
}

module.exports = { calculateFare, getRates, applyPromo, roundFare };
