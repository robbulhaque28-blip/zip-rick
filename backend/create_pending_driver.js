const { sequelize } = require('./src/models');
async function run() {
  // Create a pending test driver
  const [existing] = await sequelize.query("SELECT id FROM users WHERE phone = '+919876543211'");
  
  if (existing.length === 0) {
    await sequelize.query("INSERT INTO users (id, phone, full_name, role, is_phone_verified, is_active, created_at, updated_at) VALUES ('cccccccc-cccc-cccc-cccc-cccccccccccc', '+919876543211', 'Pending Driver', 'driver', 1, 1, datetime('now'), datetime('now'))");
    await sequelize.query("INSERT INTO drivers (id, user_id, registration_status, is_documents_uploaded, created_at, updated_at) VALUES ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'pending', 1, datetime('now'), datetime('now'))");
    console.log('Created pending test driver');
  } else {
    console.log('Test driver already exists');
    await sequelize.query("UPDATE drivers SET registration_status = 'pending' WHERE user_id = '" + existing[0].id + "'");
    console.log('Set driver to pending');
  }
  
  // Now show all pending drivers
  const [pending] = await sequelize.query("SELECT u.full_name, u.phone, d.registration_status, d.id FROM users u JOIN drivers d ON u.id = d.user_id WHERE d.registration_status = 'pending'");
  console.log('Pending drivers:', JSON.stringify(pending, null, 2));
  
  process.exit(0);
}
run().catch(e => { console.log('ERROR:', e.message); process.exit(1); });
