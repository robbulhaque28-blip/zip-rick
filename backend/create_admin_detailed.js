const { User, AdminUser } = require('./src/models');
const bcrypt = require('bcryptjs');

async function createAdminDetailed() {
  try {
    console.log('Creating user...');
    const user = await User.create({
      phone: '+12345678901',
      email: 'admin@zip-rick.com',
      full_name: 'Admin User',
      role: 'admin'
    });
    
    console.log('✅ User created successfully:', user.id);
    
    console.log('Creating admin...');
    const hash = await bcrypt.hash('admin123', 12);
    const admin = await AdminUser.create({
      user_id: user.id,
      email: 'admin@zip-rick.com',
      password_hash: hash,
      role: 'super_admin',
      is_active: true
    });
    
    console.log('✅ Admin created successfully!');
    console.log('Email: admin@zip-rick.com');
    console.log('Password: admin123');
    
  } catch (error) {
    console.error('Detailed Error:', error);
    if (error.errors) {
      error.errors.forEach(err => {
        console.error('Field:', err.path, 'Message:', err.message);
      });
    }
  }
  process.exit();
}

createAdminDetailed();
