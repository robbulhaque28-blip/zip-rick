const { User, Customer } = require('./src/models');

async function checkCustomers() {
  try {
    const customerUsers = await User.findAll({
      where: { role: 'customer' }
    });
    console.log('Total customer users found:', customerUsers.length);
    
    const customers = await Customer.findAll();
    console.log('Total customer records found:', customers.length);
    
  } catch (error) {
    console.error('Error:', error.message);
  }
  process.exit();
}

checkCustomers();
