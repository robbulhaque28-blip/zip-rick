const { sequelize } = require('./src/models');
async function run() {
  // Direct query - count all drivers with their user info
  const [allDrivers] = await sequelize.query(`
    SELECT u.id, u.full_name, u.phone, u.email, d.registration_status, 
           d.is_documents_uploaded, d.total_rides, d.rating_avg,
           d.created_at, d.registration_fee_paid,
           v.registration_number as vehicle_reg
    FROM drivers d
    JOIN users u ON u.id = d.user_id
    LEFT JOIN vehicles v ON v.driver_id = d.id
    ORDER BY d.created_at DESC
  `);
  console.log('All drivers count:', allDrivers.length);
  console.log('All drivers:', JSON.stringify(allDrivers, null, 2));
  process.exit(0);
}
run().catch(e => { console.log('ERROR:', e.message); process.exit(1); });
