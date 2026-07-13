const { sequelize } = require('./src/models');
async function run() {
  const [users] = await sequelize.query("SELECT id, phone, full_name, role FROM users WHERE role = 'driver'");
  console.log('Drivers:', JSON.stringify(users, null, 2));
  
  const [drivers] = await sequelize.query("SELECT id, user_id, registration_status, is_documents_uploaded FROM drivers");
  console.log('DriverProfiles:', JSON.stringify(drivers, null, 2));
  
  process.exit(0);
}
run().catch(e => { console.log('ERROR:', e.message); process.exit(1); });
