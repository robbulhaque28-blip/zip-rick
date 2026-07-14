require('dotenv').config({ path: require('path').resolve(__dirname, '../../../.env') });
const { sequelize } = require('../config/db');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');

async function seed() {
  try {
    await sequelize.authenticate();
    console.log('Database connected.');

    const password = await bcrypt.hash('Admin@123', 10);
    const userId = uuidv4();
    const adminId = uuidv4();

    // Create user
    const userResult = await sequelize.query(
      `INSERT INTO users (id, phone, full_name, role, is_phone_verified, created_at, updated_at)
       VALUES ('${userId}', '7000000000', 'Super Admin', 'admin', true, NOW(), NOW())
       ON CONFLICT (phone) DO NOTHING
       RETURNING id;`
    );

    // Check if user was inserted or already existed
    const user = await sequelize.query(
      `SELECT id FROM users WHERE phone = '7000000000' LIMIT 1;`,
      { type: sequelize.QueryTypes.SELECT }
    );

    if (user && user.length > 0) {
      const existingAdmin = await sequelize.query(
        `SELECT id FROM admin_users WHERE user_id = '${user[0].id}' LIMIT 1;`,
        { type: sequelize.QueryTypes.SELECT }
      );

      if (!existingAdmin || existingAdmin.length === 0) {
        await sequelize.query(
          `INSERT INTO admin_users (id, user_id, email, password_hash, role, permissions, is_active, created_at, updated_at)
           VALUES ('${adminId}', '${user[0].id}', 'admin@ziprick.com', '${password}', 'super_admin', '{"all": true}', true, NOW(), NOW());`
        );
        console.log('✅ Admin user created!');
      } else {
        console.log('ℹ️  Admin user already exists.');
      }

      console.log('   Email:    admin@ziprick.com');
      console.log('   Password: Admin@123');
      console.log('   Phone:    7000000000');
    }

    await sequelize.close();
    console.log('✅ Done.');
    process.exit(0);
  } catch (e) {
    console.error('❌ Error:', e.message);
    process.exit(1);
  }
}

seed();