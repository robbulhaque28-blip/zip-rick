const s = require('./src/models').sequelize;
const bcrypt = require('bcryptjs');
(async () => {
  await s.sync();
  const h = bcrypt.hashSync('admin123', 12);
  await s.query("INSERT INTO users(id,phone,full_name,role,is_phone_verified,is_active,created_at,updated_at) VALUES('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','+919999999990','Super Admin','admin',1,1,datetime('now'),datetime('now'))");
  const [cols] = await s.query("PRAGMA table_info('admin_users')");
  const names = cols.map(c => c.name);
  if (names.includes('password_hash')) {
    await s.query("INSERT INTO admin_users(id,user_id,email,password_hash,role,is_active,created_at,updated_at) VALUES('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','admin@vybe.com','" + h + "','super_admin',1,datetime('now'),datetime('now'))");
    console.log('Admin created with password_hash');
  } else {
    await s.query("INSERT INTO admin_users(id,user_id,username,email,password,role,status,created_at,updated_at) VALUES('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','admin','admin@vybe.com','" + h + "','super_admin','active',datetime('now'),datetime('now'))");
    console.log('Admin created with password field');
  }
  console.log('Login: admin@vybe.com / admin123');
  process.exit(0);
})();