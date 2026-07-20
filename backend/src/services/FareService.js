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
  
  return {
    base_fare: b, distance_fare: df, time_fare: tf,
    night_charges: nc, peak_charges: pc,
    waiting_charges: 0, promo_discount: 0,
    total_fare: parseFloat(total.toFixed(2)),
    ride_mode: isSharing ? 'sharing' : 'single'
  };
}

module.exports = { calculateFare, getRates };
