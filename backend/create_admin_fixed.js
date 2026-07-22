const { User, AdminUser } = require('./src/models');
const bcrypt = require('bcryptjs');

async function createAdmin() {
  try {
    // First create a regular user with correct fields
    const user = await User.create({
      id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      phone: '+1234567890',
      email: 'admin@vybe.com',
      full_name: 'Admin User',
      role: 'admin'
    });
    
    console.log('Base user created:', user.id);
    
    // Then create admin user
    const hash = await bcrypt.hash('admin123', 12);
    const admin = await AdminUser.create({
      id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      user_id: user.id,
      email: 'admin@vybe.com',
      password_hash: hash,
      role: 'super_admin',
      is_active: true
    });
    
    console.log('✅ Admin created successfully!');
    console.log('Email: admin@vybe.com');
    console.log('Password: admin123');
    
  } catch (error) {
    console.error('Error:', error.message);
  }
  process.exit();
}

createAdmin();
