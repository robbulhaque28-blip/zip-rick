const { User, Customer } = require('./src/models');

async function createSampleData() {
  try {
    // Create 5 sample customers
    for (let i = 1; i <= 5; i++) {
      const user = await User.create({
        phone: '+91900000000' + i,
        email: 'customer' + i + '@test.com',
        full_name: 'Test Customer ' + i,
        role: 'customer'
      });
      
      await Customer.create({
        user_id: user.id,
        referral_code: 'REF' + i.toString().padStart(3, '0')
      });
      
      console.log('✅ Created customer:', user.full_name);
    }
  } catch (error) {
    console.error('Error:', error.message);
  }
  process.exit();
}

createSampleData();
