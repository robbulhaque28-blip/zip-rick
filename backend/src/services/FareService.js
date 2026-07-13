const fareRates = Object.freeze({
  base_fare: 30, per_km: 12, per_minute: 1, minimum_fare: 30,
  waiting_charge_per_min: 2, night_charge_multiplier: 1.5,
  night_start_hour: 22, night_end_hour: 6, peak_multiplier: 1.2,
  peak_hours: [{ start: 8, end: 10 }, { start: 17, end: 20 }],
  cancellation_fee_customer: 10,
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
  const b = parseFloat(rates.base_fare);
  const df = parseFloat((dk * rates.per_km).toFixed(2));
  const tf = parseFloat((dm * rates.per_minute).toFixed(2));
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
    total_fare: parseFloat(total.toFixed(2))
  };
}

module.exports = { calculateFare, getRates };
