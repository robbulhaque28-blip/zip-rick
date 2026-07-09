const { sequelize } = require('./src/models');
async function run() {
  const [cols] = await sequelize.query("PRAGMA table_info('admin_users')");
  console.log('Admin table columns:', JSON.stringify(cols, null, 2));
  
  const [all] = await sequelize.query("SELECT * FROM admin_users");
  console.log('All admin records:', JSON.stringify(all, null, 2));
  
  process.exit(0);
}
run().catch(e => { console.log('ERROR:', e.message); process.exit(1); });
