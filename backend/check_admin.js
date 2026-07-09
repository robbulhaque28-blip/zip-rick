const { sequelize } = require('./src/models');
async function run() {
  const [users] = await sequelize.query("SELECT * FROM users WHERE role = 'admin'");
  console.log('Admin Users:', JSON.stringify(users, null, 2));
  
  const [admins] = await sequelize.query("SELECT email, role, is_active FROM admin_users");
  console.log('Admin Table:', JSON.stringify(admins, null, 2));
  
  process.exit(0);
}
run().catch(e => { console.log('ERROR:', e.message); process.exit(1); });
