# Zip-Rick Testing Strategy

## Testing Pyramid

```
        ╱╲
       ╱ E2E ╲
      ╱────────╲
     ╱Integration╲
    ╱──────────────╲
   ╱   Unit Tests   ╲
  ╱────────────────────╲
 ╱   Static Analysis    ╲
╱──────────────────────────╲
```

## 1. Unit Tests (Jest + Supertest)

### Coverage Targets
- Lines: 80%+
- Branches: 70%+
- Functions: 80%+
- Statements: 80%+

### Test Categories

#### Services
```javascript
// Example: FareService test
describe('FareService', () => {
  describe('calculateFare', () => {
    it('should calculate base fare correctly', async () => {});
    it('should apply night charges between 10PM-6AM', async () => {});
    it('should apply peak pricing during rush hours', async () => {});
    it('should enforce minimum fare', async () => {});
    it('should handle zero distance rides', async () => {});
  });

  describe('applyPromo', () => {
    it('should apply percentage discount', async () => {});
    it('should respect max discount limit', async () => {});
    it('should reject expired promo codes', async () => {});
  });
});
```

#### Models
```javascript
describe('User model', () => {
  it('should validate phone number format', async () => {});
  it('should enforce unique phone numbers', async () => {});
  it('should hash password on creation', async () => {});
});

describe('Ride model', () => {
  it('should generate unique ride number', async () => {});
  it('should calculate total fare correctly', async () => {});
  it('should calculate payouts with commission', async () => {});
});
```

#### Controllers
```javascript
describe('AuthController', () => {
  it('should send OTP for valid phone', async () => {});
  it('should reject invalid phone numbers', async () => {});
  it('should create new user on first login', async () => {});
});

describe('RideController', () => {
  it('should estimate fare for valid route', async () => {});
  it('should create ride in pending status', async () => {});
  it('should cancel ride in cancellable state', async () => {});
  it('should reject cancel for started ride', async () => {});
});
```

## 2. Integration Tests

### API Endpoint Tests
```javascript
describe('POST /api/v1/rides/book', () => {
  beforeEach(async () => {
    await seedTestData();
  });

  afterEach(async () => {
    await cleanupTestData();
  });

  it('should book ride and start driver search', async () => {
    const response = await request(app)
      .post('/api/v1/rides/book')
      .set('Authorization', `Bearer ${customerToken}`)
      .send(validBookingPayload);

    expect(response.status).toBe(201);
    expect(response.body.data.ride.status).toBe('searching');
  });

  it('should reject booking without required fields', async () => {});
  it('should return 401 without auth token', async () => {});
});

describe('Ride Matching Flow', () => {
  it('should find nearby drivers within radius', async () => {});
  it('should send request to nearest driver first', async () => {});
  it('should timeout after 60 seconds', async () => {});
  it('should handle driver acceptance', async () => {});
  it('should handle all drivers rejecting', async () => {});
});
```

## 3. E2E Tests (Playwright / Cypress)

### Customer Flow
```
1. Open app → Login via OTP → 2. Set pickup location (GPS)
3. Search destination → 4. View fare estimate
5. Book ride → 6. See driver assigned
7. Track driver → 8. Ride completed
9. Payment → 10. Rate driver
```

### Driver Flow
```
1. Login → 2. Upload documents
3. Pay registration fee → 4. Wait for approval
5. Go online → 6. Receive ride request
7. Accept → 8. Navigate to pickup
9. Start ride → 10. Complete ride
11. View earnings
```

### Admin Flow
```
1. Login to dashboard → 2. View analytics
3. Approve driver → 4. View active rides
5. Update fare settings → 6. Manage promo codes
7. Export reports → 8. Handle support tickets
```

## 4. Performance Testing

### Load Testing (k6 / Artillery)
```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '2m', target: 100 },  // Ramp up to 100 users
    { duration: '5m', target: 100 },  // Stay at 100 users
    { duration: '2m', target: 200 },  // Ramp up to 200 users
    { duration: '5m', target: 200 },  // Stay at 200 users
    { duration: '2m', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'],  // 95% of requests under 2s
    http_req_failed: ['rate<0.01'],     // Less than 1% failure rate
  },
};

export default function () {
  const res = http.get('https://api.zip-rick.com/v1/health');
  check(res, { 'status is 200': (r) => r.status === 200 });
  sleep(1);
}
```

### Key Performance Metrics
| Metric | Target | Critical |
|--------|--------|----------|
| API Response Time (p95) | < 500ms | < 2s |
| Ride Matching Time | < 10s | < 30s |
| Location Update Latency | < 1s | < 3s |
| Concurrent Users | 10,000 | 50,000 |
| Database Queries/Request | < 10 | < 20 |

## 5. Security Testing

### OWASP Top 10 Checklist
- [x] Injection (SQL, NoSQL, OS) - Parameterized queries, input validation
- [x] Broken Authentication - JWT, rate limiting, OTP expiration
- [x] Sensitive Data Exposure - Encryption at rest, HTTPS
- [x] XML External Entities (XXE) - Not applicable (JSON only)
- [x] Broken Access Control - RBAC, middleware checks
- [x] Security Misconfiguration - Helmet, CORS, secure headers
- [x] Cross-Site Scripting (XSS) - Helmet, input sanitization
- [x] Insecure Deserialization - JSON only, no eval
- [x] Using Components with Known Vulnerabilities - npm audit
- [x] Insufficient Logging & Monitoring - Winston, Sentry, CloudWatch

### Penetration Testing Scenarios
- JWT token manipulation
- OTP brute force
- Fare manipulation
- Location spoofing
- Payment bypass
- Document upload bypass
- SQL injection
- Rate limit bypass

## 6. Test Data Management

### Test Fixtures
```javascript
// tests/fixtures/index.js
module.exports = {
  users: {
    customer: { phone: '+919999999991', full_name: 'Test Customer', role: 'customer' },
    driver: { phone: '+919999999992', full_name: 'Test Driver', role: 'driver' },
    admin: { email: 'admin@test.com', password: 'admin123', role: 'admin' },
  },
  locations: {
    guwahati: {
      railwayStation: { lat: 26.1833, lng: 91.7444, address: 'Guwahati Railway Station' },
      airport: { lat: 26.1061, lng: 91.5851, address: 'Lokpriya Gopinath Bordoloi International Airport' },
    },
  },
  rides: {
    shortTrip: { distance: 5000, duration: 900 },  // 5km, 15 min
    mediumTrip: { distance: 15000, duration: 2700 }, // 15km, 45 min
  },
};
```

### Database Cleanup
```javascript
// tests/setup.js
beforeEach(async () => {
  await sequelize.sync({ force: true });
  await seedSystemSettings();
});

afterAll(async () => {
  await sequelize.close();
});
```

## 7. CI/CD Integration

### GitHub Actions Workflow
```yaml
name: Test Suite

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: test
        options: --health-cmd pg_isready
    
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
      
      - run: npm ci
      - run: npm run lint
      - run: npm test -- --coverage
      - run: npm run test:integration
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
```
