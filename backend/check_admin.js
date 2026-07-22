const { User, AdminUser } = require('./src/models');

async function checkAdmin() {
  try {
    const users = await User.findAll({
      where: { email: 'admin@vybe.com' }
    });
    console.log('Users with admin email:', users.length);
    
    const admins = await AdminUser.findAll({
      where: { email: 'admin@vybe.com' }
    });
    console.log('Admin users with admin email:', admins.length);
    
    if (admins.length > 0) {
      console.log('✅ Admin user already exists!');
      console.log('Try logging in with: admin@vybe.com / admin123');
    }
    
  } catch (error) {
    console.error('Error:', error.message);
  }
  process.exit();
}

checkAdmin();
