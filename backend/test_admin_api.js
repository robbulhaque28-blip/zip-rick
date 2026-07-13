const axios = require('axios');

async function testAdminAPI() {
  try {
    const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOiIwMjhiOTJkZC0wYjAzLTQwNzctODhkZi03NGUxNmEzZjViZDAiLCJwaG9uZSI6IisxMjM0NTY3ODkwMSIsInJvbGUiOiJhZG1pbiIsImlhdCI6MTc4MzY3OTI0NCwiZXhwIjoxNzgzNjgwMTQ0fQ.RMOhc_clXN0i2twFKU2S07uBQoHkKkuQmyJDHOitEdo';
    
    console.log('Testing admin dashboard API...');
    
    const response = await axios.get('http://localhost:3000/api/v1/admin/dashboard', {
      headers: {
        'Authorization': 'Bearer ' + token,
        'Content-Type': 'application/json'
      }
    });
    
    console.log('✅ API call successful!');
    console.log('Status:', response.status);
    console.log('Data:', response.data);
    
  } catch (error) {
    console.log('❌ API call failed!');
    console.log('Status:', error.response?.status);
    console.log('Error:', error.response?.data || error.message);
  }
  process.exit();
}

testAdminAPI();
