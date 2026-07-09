const { sequelize } = require('./src/models');
const bcrypt = require('bcryptjs');
async function run() {
  const hash = await bcrypt.hash('admin123', 12);
  
  // First, delete any previous admin
  await sequelize.query("DELETE FROM admin_users");
  await sequelize.query("DELETE FROM users WHERE role='admin'");
  
  // Create user
  await sequelize.query(
    "INSERT INTO users (id, phone, full_name, role, is_phone_verified, is_active, created_at, updated_at) VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '+919999999990', 'Super Admin', 'admin', 1, 1, datetime('now'), datetime('now'))"
  );
  
  // Insert into admin_users using actual column names: username, email, password, role, status
  await sequelize.query(
    "INSERT INTO admin_users (id, user_id, username, email, password, role, status, created_at, updated_at) VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'admin', 'admin@zip-rick.com', '" + hash + "', 'super_admin', 'active', datetime('now'), datetime('now'))"
  );
  
  console.log('Admin created with current schema');
  
  // Verify
  const [admins] = await sequelize.query("SELECT * FROM admin_users WHERE email='admin@zip-rick.com'");
  const match = await bcrypt.compare('admin123', admins[0].password);
  console.log('Password check:', match ? '? MATCHES' : '? FAILS');
  console.log('Login: admin@zip-rick.com / admin123');
  
  process.exit(0);
}
run().catch(e => { console.log('ERROR:', e.message); process.exit(1); });
