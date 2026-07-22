const http = require('http');

const loginData = JSON.stringify({ email: 'admin@vybe.com', password: 'admin123' });
const loginReq = http.request({ hostname: 'localhost', port: 3000, path: '/api/v1/auth/admin/login', method: 'POST', headers: { 'Content-Type': 'application/json' } }, (res) => {
  let body = '';
  res.on('data', d => body += d);
  res.on('end', () => {
    const data = JSON.parse(body);
    const token = data.data?.tokens?.accessToken;
    console.log('Token:', token ? 'YES' : 'NO');
    
    if (token) {
      // Test dashboard
      const req2 = http.request({ hostname: 'localhost', port: 3000, path: '/api/v1/admin/dashboard', method: 'GET', headers: { 'Authorization': 'Bearer ' + token } }, (res2) => {
        let b = '';
        res2.on('data', d => b += d);
        res2.on('end', () => {
          console.log('Dashboard status:', res2.statusCode);
          console.log('Response:', b.substring(0, 500));
          
          // Test drivers
          const req3 = http.request({ hostname: 'localhost', port: 3000, path: '/api/v1/admin/drivers', method: 'GET', headers: { 'Authorization': 'Bearer ' + token } }, (res3) => {
            let b3 = '';
            res3.on('data', d => b3 += d);
            res3.on('end', () => {
              console.log('Drivers status:', res3.statusCode);
              console.log('Drivers response:', b3.substring(0, 500));
              process.exit(0);
            });
          });
          req3.end();
        });
      });
      req2.end();
    }
  });
});
loginReq.write(loginData);
loginReq.end();
