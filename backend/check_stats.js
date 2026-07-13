const { sequelize, Customer, Driver, Ride, Payment } = require('./src/models');
async function run() {
  const tc = await Customer.count();
  const td = await Driver.count();
  const pd = await Driver.count({ where: { registration_status: 'pending' } });
  const tr = await Ride.count();
  const trev = await Payment.sum('amount', { where: { payment_status: 'completed' } }) || 0;
  console.log('Stats:', { total_customers: tc, total_drivers: td, pending_drivers: pd, total_rides: tr, total_revenue: trev });
  process.exit(0);
}
run().catch(e => { console.log('ERROR:', e.message); process.exit(1); });
