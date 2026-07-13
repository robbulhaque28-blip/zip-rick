const { User } = require('./src/models');

async function checkTokenUser() {
  try {
    const userId = '028b92dd-0b03-4077-88df-74e16a3f5bd0';
    const user = await User.findByPk(userId);
    
    if (user) {
      console.log('✅ User found!');
      console.log('User ID:', user.id);
      console.log('User role:', user.role);
      console.log('User email:', user.email);
      console.log('User phone:', user.phone);
    } else {
      console.log('❌ User NOT found in database!');
    }
    
  } catch (error) {
    console.error('Error:', error.message);
  }
  process.exit();
}

checkTokenUser();
