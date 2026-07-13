const http = require('http');

const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/api/v1/admin/drivers',
  method: 'GET',
  headers: { 'Authorization': 'Bearer ' + '' }
};

// First get a token
const loginData = JSON.stringify({ email: 'admin@zip-rick.com', password: 'admin123' });
const loginReq = http.request({ hostname: 'localhost', port: 3000, path: '/api/v1/auth/admin/login', method: 'POST', headers: { 'Content-Type': 'application/json' } }, (res) => {
  let body = '';
  res.on('data', d => body += d);
  res.on('end', () => {
    const data = JSON.parse(body);
    const token = data.data?.tokens?.accessToken;
    console.log('Token obtained:', token ? 'YES' : 'NO');
    
    if (token) {
      const req = http.request({ hostname: 'localhost', port: 3000, path: '/api/v1/admin/drivers', method: 'GET', headers: { 'Authorization': 'Bearer ' + token } }, (res2) => {
        let b = '';
        res2.on('data', d => b += d);
        res2.on('end', () => {
          console.log('Drivers API response status:', res2.statusCode);
          console.log('Response:', b.substring(0, 500));
          process.exit(0);
        });
      });
      req.end();
    } else {
      console.log('Login failed:', JSON.stringify(data));
      process.exit(1);
    }
  });
});
loginReq.write(loginData);
loginReq.end();
