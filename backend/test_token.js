const jwt = require('jsonwebtoken');
const config = require('./src/config');

async function testTokenVerification() {
  try {
    const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOiIwMjhiOTJkZC0wYjAzLTQwNzctODhkZi03NGUxNmEzZjViZDAiLCJwaG9uZSI6IisxMjM0NTY3ODkwMSIsInJvbGUiOiJhZG1pbiIsImlhdCI6MTc4MzY3OTI0NCwiZXhwIjoxNzgzNjgwMTQ0fQ.RMOhc_clXN0i2twFKU2S07uBQoHkKkuQmyJDHOitEdo';
    
    console.log('JWT Secret from config:', config.jwt.secret);
    console.log('Attempting to verify token...');
    
    const decoded = jwt.verify(token, config.jwt.secret);
    console.log('✅ Token verification successful!');
    console.log('Decoded token:', decoded);
    
  } catch (error) {
    console.log('❌ Token verification failed!');
    console.log('Error name:', error.name);
    console.log('Error message:', error.message);
  }
  process.exit();
}

testTokenVerification();
