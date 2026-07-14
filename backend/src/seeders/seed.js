require('dotenv').config({ path: require('path').resolve(__dirname, '../../../.env') });
const { sequelize } = require('../config/db');
const { User, AdminUser } = require('../models');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');

async function seed() {
  try {
    await sequelize.authenticate();
    console.log('Database connected.');

    const password = await bcrypt.hash('Admin@123', 10);
    const userId = uuidv4();

    await sequelize.query(
      `INSERT INTO users (id, phone, full_name, role, is_phone_verified, created_at, updated_at)
       VALUES ('${userId}', '7000000000', 'Super Admin', 'admin', true, NOW(), NOW())
       ON CONFLICT (phone) DO NOTHING;`
    );

    const user = await User.findOne({ where: { phone: '7000000000' } });

    if (user) {
      await sequelize.query(
        `INSERT INTO admin_users (id, user_id, email, password_hash, role, permissions, is_active, created_at, updated_at)
         VALUES (uuid_generate_v4(), '${user.id}', 'admin@ziprick.com', '${password}', 'super_admin', '{"all": true}', true, NOW(), NOW())
         ON CONFLICT (email) DO NOTHING;`
      );
      console.log('✅ Admin user created!');
      console.log('   Email:    admin@ziprick.com');
      console.log('   Password: Admin@123');
      console.log('   Phone:    7000000000');
    } else {
      console.log('ℹ️  Admin user already exists.');
    }

    await sequelize.close();
    console.log('✅ Done.');
    process.exit(0);
  } catch (e) {
    console.error('❌ Error:', e.message);
    console.error(e);
    process.exit(1);
  }
}

seed();