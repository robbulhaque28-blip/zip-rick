# 🛺 Vybe - E-Rickshaw Ride-Hailing Platform

**Vybe** is a production-grade, full-stack ride-hailing platform exclusively for **E-Rickshaws**, built for the Indian market. Designed as a scalable startup system ready to serve millions of users across India.

---

## 🚀 Overview

| Feature | Details |
|---------|---------|
| **App Name** | Vybe |
| **Country** | India |
| **Initial Launch** | Assam (all cities) |
| **Future Expansion** | Entire India |
| **Vehicle Type** | E-Rickshaw Only |
| **Languages** | English (i18n-ready) |
| **Payment** | Cash + UPI (Razorpay) |

---

## 🏗️ Platform Components

| Component | Technology | Status |
|-----------|-----------|--------|
| ✅ Customer Mobile App | Flutter 3.x | ✅ Complete |
| ✅ Driver Mobile App | Flutter 3.x | ✅ Complete |
| ✅ Admin Dashboard | React 18 + Material-UI | ✅ Complete |
| ✅ Backend API | Node.js + Express | ✅ Complete |
| ✅ Database | PostgreSQL 15 | ✅ Complete |
| ✅ Real-time | Socket.IO + Redis | ✅ Complete |
| ✅ Documentation | Full system docs | ✅ Complete |

---

## ✨ Features

### 👤 Customer App
- Mobile OTP Login via Firebase
- Live GPS tracking with Google Maps
- Multiple pickup/drop methods (GPS, Search, Pin Drop)
- Fare estimation before booking
- Real-time driver tracking
- Cash & UPI payments (Razorpay)
- Ride history with ratings
- Saved places (Home/Work/Favorites)
- Referral system & promo codes
- SOS emergency button
- Driver chat
- In-app support tickets
- Trip sharing
- Push notifications
- Dark mode support
- Material Design 3 UI

### 🚗 Driver App
- OTP Login & Registration
- Document upload (Aadhaar, RC, Selfie)
- Registration fee payment (₹499/₹999)
- Manual admin approval workflow
- Online/Offline toggle
- Ride request with 60s timer
- Google Maps navigation
- Earnings dashboard & wallet
- Ride history & ratings
- Push notifications

### 🖥️ Admin Dashboard
- Real-time analytics dashboard
- Driver management (approve/reject/suspend)
- Customer management
- Ride monitoring with live map
- Fare & commission management (10%)
- Registration fee configuration
- Promo code management
- Revenue analytics & reports
- Support ticket system
- Broadcast notifications
- System settings
- Audit logs
- Export reports (CSV/JSON)

---

## 🛠️ Technology Stack

### Frontend
```
Customer App:     Flutter 3.x, Material Design 3, Google Maps, Provider
Driver App:       Flutter 3.x, Material Design 3, Google Maps, Provider
Admin Dashboard:  React 18, Material-UI 5, Recharts, React Query
```

### Backend
```
Runtime:          Node.js 18 LTS
Framework:        Express.js 4.x
Auth:             JWT + Firebase OTP
Database ORM:     Sequelize (PostgreSQL)
Cache:            Redis 7 (ioredis)
Realtime:         Socket.IO 4.x + Redis Adapter
Validation:       Joi
Payments:         Razorpay
Maps:             Google Maps API
Storage:          AWS S3
Notifications:    Firebase Cloud Messaging
Queues:           Bull (Redis)
Logging:          Winston + Morgan + Sentry
Testing:          Jest + Supertest
Docs:             Swagger/OpenAPI 3.0
```

### Infrastructure
```
Containerization: Docker + Docker Compose
CI/CD:            GitHub Actions
Hosting:          AWS (ECS/EKS, RDS, ElastiCache, S3, CloudFront)
Monitoring:       CloudWatch + Sentry
```

---

## 📊 Database (23 Tables)

`users`, `customers`, `drivers`, `driver_documents`, `driver_registration_payments`, `vehicles`, `rides`, `ride_status_logs`, `payments`, `transactions`, `wallets`, `ratings_reviews`, `notifications`, `promo_codes`, `promo_redemptions`, `referrals`, `saved_places`, `support_tickets`, `support_ticket_messages`, `admin_users`, `system_settings`, `audit_logs`, `chat_messages`

---

## 🚦 Getting Started

### Prerequisites
- Node.js 18+
- PostgreSQL 15
- Redis 7
- Docker (optional)

### Backend Setup

```bash
cd vybe/backend

# Install dependencies
npm install

# Configure environment
cp .env.example .env
# Edit .env with your credentials

# Run database migrations
npm run migrate

# Seed initial settings
npm run seed

# Start development server
npm run dev
```

### Docker Setup

```bash
cd vybe/docker
docker-compose up -d
# API at http://localhost:4000
# Swagger docs at http://localhost:4000/api/docs
# pgAdmin at http://localhost:5050
```

### Flutter Apps

```bash
cd apps/customer_app
flutter pub get
flutter run

cd apps/driver_app
flutter pub get
flutter run
```

### Admin Dashboard

```bash
cd apps/admin_dashboard
npm install
npm run dev
# Opens at http://localhost:5173
```

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [System Architecture](docs/SYSTEM_ARCHITECTURE.md) | Complete architecture, data flow, security |
| [Database Schema](docs/DATABASE_SCHEMA.md) | Full SQL schema with 23 tables |
| [ER Diagram](docs/ER_DIAGRAM.png) | Entity Relationship Diagram |
| [Deployment Guide](docs/DEPLOYMENT_GUIDE.md) | AWS deployment, CI/CD, monitoring |
| [Testing Strategy](docs/TESTING_STRATEGY.md) | Unit, integration, E2E, performance tests |
| [Production Checklist](docs/PRODUCTION_READINESS_CHECKLIST.md) | Pre-launch verification |
| [Customer Manual](docs/USER_MANUAL_CUSTOMER.md) | Customer app user guide |
| [Driver Manual](docs/USER_MANUAL_DRIVER.md) | Driver app user guide |
| [Admin Manual](docs/USER_MANUAL_ADMIN.md) | Admin dashboard guide |
| [Folder Structure](docs/FOLDER_STRUCTURE.md) | Complete project tree |

---

## 🔒 Security

- HTTPS everywhere (TLS 1.3)
- JWT authentication (15min expiry + 7-day refresh)
- Firebase OTP verification
- Role-based access control (Customer/Driver/Admin)
- Input sanitization & validation (Joi)
- SQL injection protection (Sequelize parameterized queries)
- XSS protection (Helmet)
- CORS restricted to known domains
- Rate limiting (100 req/min general, 30 req/min auth)
- File upload validation & malware scanning
- Audit logging for all admin actions
- Secrets management (AWS Secrets Manager)

---

## 📈 Scaling Strategy

- **Horizontal Scaling**: Auto-scaling API servers (2-10 instances)
- **Socket Clustering**: Redis adapter for multi-instance real-time
- **Database**: Read replicas for reporting, connection pooling
- **Caching**: Redis cluster for session & data cache
- **CDN**: CloudFront for static assets & map tiles
- **Performance**: Target p95 < 500ms, 10,000+ concurrent users

---

## 📄 License

MIT License - See [LICENSE](LICENSE) file

---

## 🤝 Support

For support, email support@vybe.com or raise an issue on GitHub.

---

*Built with ❤️ for Assam and all of India*
