const { User } = require('./src/models');

async function checkUserStatus() {
  try {
    const userId = '028b92dd-0b03-4077-88df-74e16a3f5bd0';
    const user = await User.findByPk(userId);
    
    console.log('User Status Check:');
    console.log('is_active:', user.is_active);
    console.log('is_blocked:', user.is_blocked);
    console.log('role:', user.role);
    
    if (!user.is_active) {
      console.log('❌ PROBLEM: User is not active!');
    }
    if (user.is_blocked) {
      console.log('❌ PROBLEM: User is blocked!');
    }
    if (user.is_active && !user.is_blocked) {
      console.log('✅ User status is fine');
    }
    
  } catch (error) {
    console.error('Error:', error.message);
  }
  process.exit();
}

checkUserStatus();
