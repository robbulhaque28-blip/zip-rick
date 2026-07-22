# Vybe System Architecture

## Overview
Production-grade E-Rickshaw ride-hailing platform. India-first, Assam launch.

## Architecture Layers

```
CLIENT LAYER
  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────────┐
  │ Customer App    │  │ Driver App      │  │ Admin Dashboard  │
  │ (Flutter)       │  │ (Flutter)       │  │ (React 18)       │
  └────────┬────────┘  └────────┬────────┘  └────────┬─────────┘
           │                    │                    │
           ▼                    ▼                    ▼
API GATEWAY (Nginx/ALB - HTTPS, WAF, Rate Limiting)
           │                    │                    │
           ▼                    ▼                    ▼
APPLICATION LAYER (Node.js/Express - Horizontal Scaling)
  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐
  │ Auth │ │ Ride │ │ Pay  │ │Driver│ │Admin │
  │ Svc  │ │Match │ │ Svc  │ │ Svc  │ │ Svc  │
  └──────┘ └──────┘ └──────┘ └──────┘ └──────┘
  ┌──────────────────────────────────────────┐
  │ Socket.IO Cluster (Redis Adapter)        │
  └──────────────────────────────────────────┘
           │                    │                    │
           ▼                    ▼                    ▼
DATA LAYER
  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐
  │PostgreSQL│ │ Redis    │ │ AWS S3   │ │Sentry  │
  │ (RDS)    │ │(ElastiCache)│ (Docs)   │ │(Errors)│
  └──────────┘ └──────────┘ └──────────┘ └────────┘
```

## Tech Stack
- **Customer App**: Flutter 3.x, Material Design 3, Google Maps
- **Driver App**: Flutter 3.x, Google Maps, Camera
- **Admin Dashboard**: React 18, Material-UI 5, Recharts
- **Backend**: Node.js 18, Express 4, Socket.IO 4
- **Database**: PostgreSQL 15 (Sequelize ORM)
- **Cache**: Redis 7 (ioredis)
- **Auth**: JWT + Firebase OTP
- **Payments**: Razorpay (UPI)
- **Maps**: Google Maps API
- **Storage**: AWS S3
- **Notifications**: Firebase Cloud Messaging

## Security
- HTTPS (TLS 1.3), Helmet headers
- JWT (15min access + 7-day refresh)
- RBAC (Customer/Driver/Admin)
- Rate limiting (100/min general, 30/min auth)
- Input validation (Joi), SQL injection protection
- CORS whitelist, XSS protection
- Audit logging for all admin operations

## Scaling
- Horizontal: Auto-scaling API servers (2-10)
- Socket.IO: Redis adapter for multi-instance
- Database: Read replicas, connection pooling
- CDN: CloudFront for static assets
