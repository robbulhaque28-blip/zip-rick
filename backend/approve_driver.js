const { Driver } = require('./src/models');

async function approveDriver() {
  try {
    const driverId = 'fe84824a-e4a4-4ae0-ad83-7658511f5ebe';
    
    await Driver.update(
      { registration_status: 'approved' },
      { where: { id: driverId } }
    );
    
    console.log('✅ Driver approved successfully!');
    
    const driver = await Driver.findByPk(driverId);
    console.log('New status:', driver.registration_status);
    
  } catch (error) {
    console.error('Error:', error.message);
  }
  process.exit();
}

approveDriver();
