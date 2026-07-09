const { sequelize } = require('./src/models');
const bcrypt = require('bcryptjs');
async function run() {
  await sequelize.query("DELETE FROM admin_users");
  await sequelize.query("DELETE FROM users");
  await sequelize.query("DELETE FROM customers");
  await sequelize.query("DELETE FROM drivers");
  await sequelize.query("DELETE FROM wallets");
  
  const hash = await bcrypt.hash('admin123', 12);
  console.log('Hash created:', hash.substring(0, 20) + '...');
  
  await sequelize.query(
    "INSERT INTO users (id, phone, full_name, role, is_phone_verified, is_active, created_at, updated_at) VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '+919999999990', 'Super Admin', 'admin', 1, 1, datetime('now'), datetime('now'))"
  );
  
  await sequelize.query(
    "INSERT INTO admin_users (id, user_id, email, password_hash, role, is_active, created_at, updated_at) VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'admin@zip-rick.com', '" + hash + "', 'super_admin', 1, datetime('now'), datetime('now'))"
  );
  
  const [admins] = await sequelize.query("SELECT * FROM admin_users JOIN users ON users.id = admin_users.user_id");
  console.log('Admin created:', admins[0]?.email || 'FAILED');
  console.log('Password: admin123');
  
  if (admins.length > 0) {
    const verify = await bcrypt.compare('admin123', admins[0].password_hash);
    console.log('Password check:', verify ? '? MATCHES' : '? FAILS');
  }
  process.exit(0);
}
run().catch(e => { console.log('ERROR:', e.message); process.exit(1); });
