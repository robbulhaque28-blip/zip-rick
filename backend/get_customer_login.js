const { User, Customer } = require('./src/models');

async function getCustomerCredentials() {
  try {
    const customers = await User.findAll({
      where: { role: 'customer' },
      limit: 1
    });
    
    if (customers.length > 0) {
      console.log('✅ Test Customer Login:');
      console.log('Phone:', customers[0].phone);
      console.log('Email:', customers[0].email);
    }
    
  } catch (error) {
    console.error('Error:', error.message);
  }
  process.exit();
}

getCustomerCredentials();
