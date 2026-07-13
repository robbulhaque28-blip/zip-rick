const { sequelize } = require('./src/models');
async function run() {
  const [allDrivers] = await sequelize.query(`
    SELECT u.id, u.full_name, u.phone, d.registration_status, 
           d.is_documents_uploaded, d.total_rides, d.rating_avg,
           d.created_at, d.registration_fee_paid
    FROM drivers d
    JOIN users u ON u.id = d.user_id
    ORDER BY d.created_at DESC
  `);
  console.log('All drivers count:', allDrivers.length);
  console.log('All drivers:', JSON.stringify(allDrivers, null, 2));
  process.exit(0);
}
run().catch(e => { console.log('ERROR:', e.message); process.exit(1); });
