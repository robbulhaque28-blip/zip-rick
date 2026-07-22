const { sequelize } = require('./src/models');
const bcrypt = require('bcryptjs');
async function run() {
  const [cols] = await sequelize.query("PRAGMA table_info('admin_users')");
  console.log('Admin columns:', cols.map(c => c.name).join(', '));
  
  const hash = await bcrypt.hash('admin123', 12);
  
  await sequelize.query(
    "INSERT INTO users (id, phone, full_name, role, is_phone_verified, is_active, created_at, updated_at) VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '+919999999990', 'Super Admin', 'admin', 1, 1, datetime('now'), datetime('now'))"
  );
  console.log('User created');
  
  const colNames = cols.map(c => c.name);
  let sql;
  if (colNames.includes('password_hash')) {
    sql = "INSERT INTO admin_users (id, user_id, email, password_hash, role, is_active, created_at, updated_at) VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'admin@vybe.com', '" + hash + "', 'super_admin', 1, datetime('now'), datetime('now'))";
  } else if (colNames.includes('password')) {
    sql = "INSERT INTO admin_users (id, user_id, email, password, role, status, created_at, updated_at) VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'admin@vybe.com', '" + hash + "', 'super_admin', 'active', datetime('now'), datetime('now'))";
  }
  
  await sequelize.query(sql);
  console.log('Admin created');
  
  const [admins] = await sequelize.query("SELECT * FROM admin_users JOIN users ON users.id = admin_users.user_id WHERE admin_users.email='admin@vybe.com'");
  const pwField = admins[0].password_hash || admins[0].password;
  const match = await bcrypt.compare('admin123', pwField);
  console.log('Password check:', match ? '? MATCHES' : '? FAILS');
  console.log('Login: admin@vybe.com / admin123');
  
  process.exit(0);
}
run().catch(e => { console.log('ERROR:', e.message); process.exit(1); });
