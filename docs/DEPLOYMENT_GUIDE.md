# Zip-Rick Deployment Guide

## Prerequisites

### Production Environment
- AWS Account with admin access
- Domain name (zip-rick.com)
- SSL certificates (AWS Certificate Manager)
- Docker & Docker Compose (for containerized deployment)
- Node.js 18+ (for direct deployment)
- PostgreSQL 15 (AWS RDS)
- Redis 7 (AWS ElastiCache)
- Firebase project (for OTP & push notifications)
- Google Cloud Project (for Maps API)
- Razorpay merchant account
- AWS S3 bucket (for document storage)

### Development Environment
- Node.js 18+
- PostgreSQL 15
- Redis 7
- Docker (optional)

---

## 1. Infrastructure Setup (AWS)

### 1.1 VPC Configuration
```
VPC CIDR: 10.0.0.0/16
Public Subnets: 10.0.1.0/24, 10.0.2.0/24 (AZ a, b)
Private Subnets: 10.0.10.0/24, 10.0.11.0/24 (AZ a, b)
NAT Gateway: Yes (for private instances)
```

### 1.2 RDS PostgreSQL
```
Instance: db.r6g.large (min) / db.r6g.xlarge (prod)
Multi-AZ: Yes
Storage: 100GB gp3 (auto-scaling enabled)
Backup: Daily automated, 30-day retention
Port: 5432
```

### 1.3 ElastiCache Redis
```
Node Type: cache.r6g.large
Num Nodes: 2 (cluster mode)
Port: 6379
```

### 1.4 ECS / EKS (Backend)
```
Task Definition:
  CPU: 2 vCPU
  Memory: 4 GB
  Min Tasks: 2
  Max Tasks: 10
  Auto-scaling: CPU > 70%
```

### 1.5 S3 Buckets
```
zip-rick-documents/ (driver documents)
zip-rick-uploads/ (general uploads)
Lifecycle: 90-day transition to Glacier
```

---

## 2. Environment Configuration

### 2.1 Environment Variables

Create `/home/user/zip-rick/backend/.env.production`:

```env
NODE_ENV=production
PORT=4000
API_PREFIX=/api/v1

# Database
DB_HOST=zip-rick-db.cluster-xxxxx.ap-south-1.rds.amazonaws.com
DB_PORT=5432
DB_NAME=zip_rick_prod
DB_USER=ziprick_admin
DB_PASSWORD=<secure-password>
DB_POOL_MAX=20
DB_POOL_MIN=5

# Redis
REDIS_HOST=zip-rick-redis.xxxxx.ng.0001.apse1.cache.amazonaws.com
REDIS_PORT=6379

# JWT
JWT_SECRET=<64-char-random-hex>
JWT_EXPIRES_IN=15m
JWT_REFRESH_SECRET=<64-char-random-hex>
JWT_REFRESH_EXPIRES_IN=7d

# Firebase
FIREBASE_PROJECT_ID=zip-rick-production
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n..."
FIREBASE_CLIENT_EMAIL=firebase-adminsdk@zip-rick-production.iam.gserviceaccount.com

# Google Maps
GOOGLE_MAPS_API_KEY=AIzaSy...

# Razorpay
RAZORPAY_KEY_ID=rzp_live_xxxxx
RAZORPAY_KEY_SECRET=<secret>

# AWS
AWS_REGION=ap-south-1
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=<secret>
AWS_S3_BUCKET=zip-rick-uploads
AWS_S3_BUCKET_DOCUMENTS=zip-rick-documents

# CORS
CORS_ORIGINS=https://admin.zip-rick.com,https://www.zip-rick.com

# Sentry
SENTRY_DSN=https://xxxxx@sentry.io/xxxxx

# Rate Limiting
RATE_LIMIT_MAX_REQUESTS=100
RATE_LIMIT_AUTH_MAX=30
```

---

## 3. Database Migration

```bash
# Run migrations
cd backend
NODE_ENV=production npx sequelize-cli db:migrate

# Seed initial settings
NODE_ENV=production npx sequelize-cli db:seed:all
```

---

## 4. Deployment Steps

### 4.1 Docker Deployment (ECS)

```bash
# Build image
docker build -t zip-rick-api:latest -f docker/Dockerfile backend/

# Tag and push to ECR
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin <account>.dkr.ecr.ap-south-1.amazonaws.com
docker tag zip-rick-api:latest <account>.dkr.ecr.ap-south-1.amazonaws.com/zip-rick-api:latest
docker push <account>.dkr.ecr.ap-south-1.amazonaws.com/zip-rick-api:latest

# Deploy to ECS
aws ecs update-service --cluster zip-rick-prod --service zip-rick-api --force-new-deployment
```

### 4.2 Direct Deployment (EC2)

```bash
# Copy files to server
rsync -avz --exclude 'node_modules' --exclude '.env' backend/ ubuntu@<server-ip>:/opt/zip-rick/

# Install PM2 globally
npm install -g pm2

# Start with PM2 cluster mode
pm2 start src/server.js -i max --name "zip-rick-api"

# Save PM2 config
pm2 save
pm2 startup
```

### 4.3 Deploy Admin Dashboard

```bash
# Build React app
cd apps/admin_dashboard
npm run build

# Copy to S3
aws s3 sync build/ s3://zip-rick-admin

# Invalidate CloudFront
aws cloudfront create-invalidation --distribution-id <id> --paths "/*"
```

---

## 5. SSL/TLS Setup

```bash
# Using AWS Certificate Manager (ACM) - for ALB/CloudFront
# Request certificate for:
#   *.zip-rick.com
#   zip-rick.com

# Using Let's Encrypt (direct EC2)
sudo certbot --nginx -d api.zip-rick.com -d admin.zip-rick.com
```

---

## 6. CI/CD Pipeline (GitHub Actions)

### 6.1 Backend Pipeline

File: `.github/workflows/backend.yml`

```yaml
name: Backend CI/CD

on:
  push:
    branches: [main, develop]
    paths:
      - 'backend/**'

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      redis:
        image: redis:7
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 18
          cache: 'npm'
          cache-dependency-path: backend/package-lock.json
      
      - run: npm ci
        working-directory: ./backend
      - run: npm test
        working-directory: ./backend
      - run: npm run lint
        working-directory: ./backend

  deploy:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build & Deploy to ECS
        run: |
          # Build and push Docker image
          # Update ECS service
```

---

## 7. Monitoring & Logging

### 7.1 CloudWatch Alarms
```
CPUUtilization > 80% (5 min period) → SNS → Auto-scaling
5XXErrorCount > 10 (5 min period) → SNS → PagerDuty
DBConnections > 100 → SNS → Alert
```

### 7.2 Sentry Error Tracking
```javascript
// src/config/sentry.js
const Sentry = require('@sentry/node');
Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  tracesSampleRate: 0.2,
});
```

### 7.3 Logging
- Application logs: CloudWatch Logs (retention: 30 days)
- Error logs: Sentry (real-time)
- Audit logs: PostgreSQL (retention: 90 days)
- Access logs: CloudFront/ALB logs → S3 → Athena

---

## 8. Backup & Disaster Recovery

### 8.1 Database Backup
```bash
# Daily backup
pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME -F c -f /backups/zip-rick-$(date +%Y%m%d).dump

# Upload to S3
aws s3 cp /backups/zip-rick-$(date +%Y%m%d).dump s3://zip-rick-backups/db/
```

### 8.2 Recovery
```bash
# Restore from backup
pg_restore -h $DB_HOST -U $DB_USER -d $DB_NAME -c /backups/zip-rick-20260705.dump
```

### 8.3 RTO/RPO
- Recovery Time Objective: 4 hours
- Recovery Point Objective: 1 hour

---

## 9. Security Hardening

- [x] All traffic over HTTPS
- [x] WAF enabled (SQL injection, XSS protection)
- [x] Security groups: least privilege
- [x] Secrets in AWS Secrets Manager (not .env)
- [x] Regular security patching
- [x] Database encryption at rest
- [x] EBS volumes encrypted
- [x] S3 bucket policies: no public access
- [x] CloudFront signed URLs for documents
- [x] Rate limiting on all API endpoints
- [x] Input validation on all endpoints
- [x] JWT short expiry (15 min)
- [x] CORS restricted to known domains
