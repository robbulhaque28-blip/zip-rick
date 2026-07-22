# Vybe Project Folder Structure

```
vybe/
├── README.md
├── LICENSE
├── .gitignore
│
├── backend/
│   ├── package.json
│   ├── .env.example
│   ├── .eslintrc.js
│   ├── nodemon.json
│   ├── src/
│   │   ├── server.js                    # Entry point - HTTP server + Socket.IO
│   │   ├── app.js                       # Express app configuration
│   │   │
│   │   ├── config/
│   │   │   ├── index.js                 # Centralized config (env vars)
│   │   │   ├── database.js              # Sequelize config for migrations
│   │   │   └── db.js                    # Sequelize connection manager
│   │   │
│   │   ├── models/
│   │   │   ├── index.js                 # Model associations & exports
│   │   │   ├── User.js
│   │   │   ├── Customer.js
│   │   │   ├── Driver.js
│   │   │   ├── DriverDocument.js
│   │   │   ├── DriverRegistrationPayment.js
│   │   │   ├── Vehicle.js
│   │   │   ├── Ride.js
│   │   │   ├── RideStatusLog.js
│   │   │   ├── Payment.js
│   │   │   ├── Transaction.js
│   │   │   ├── Wallet.js
│   │   │   ├── RatingReview.js
│   │   │   ├── Notification.js
│   │   │   ├── PromoCode.js
│   │   │   ├── PromoRedemption.js
│   │   │   ├── Referral.js
│   │   │   ├── SavedPlace.js
│   │   │   ├── SupportTicket.js
│   │   │   ├── SupportTicketMessage.js
│   │   │   ├── AdminUser.js
│   │   │   ├── SystemSetting.js
│   │   │   ├── AuditLog.js
│   │   │   └── ChatMessage.js
│   │   │
│   │   ├── services/
│   │   │   ├── AuthService.js           # OTP, JWT, Firebase auth
│   │   │   ├── FareService.js           # Pricing calculation engine
│   │   │   ├── RideMatchingService.js   # Driver matching algorithm
│   │   │   ├── PaymentService.js        # Razorpay, wallet, refunds
│   │   │   ├── GoogleMapsService.js     # Maps API wrapper
│   │   │   └── NotificationService.js   # Push + in-app notifications
│   │   │
│   │   ├── controllers/
│   │   │   ├── AuthController.js
│   │   │   ├── RideController.js
│   │   │   └── (more controllers)
│   │   │
│   │   ├── routes/
│   │   │   ├── index.js                 # Route aggregator
│   │   │   ├── auth.js
│   │   │   ├── rides.js
│   │   │   ├── drivers.js
│   │   │   ├── customers.js
│   │   │   ├── payments.js
│   │   │   ├── maps.js
│   │   │   ├── admin.js
│   │   │   └── webhooks.js
│   │   │
│   │   ├── middleware/
│   │   │   ├── auth.js                  # JWT verify + RBAC
│   │   │   ├── validate.js              # Joi request validation
│   │   │   └── errorHandler.js          # Global error handling
│   │   │
│   │   ├── validators/                  # Request validation schemas
│   │   │   └── (Joi schemas)
│   │   │
│   │   ├── sockets/
│   │   │   └── index.js                 # Socket.IO events
│   │   │
│   │   ├── jobs/
│   │   │   └── (Bull queue jobs)
│   │   │
│   │   ├── utils/
│   │   │   ├── logger.js                # Winston logger
│   │   │   ├── response.js              # API response helpers
│   │   │   └── swagger.js               # OpenAPI docs
│   │   │
│   │   └── tests/
│   │       ├── setup.js
│   │       ├── unit/
│   │       │   ├── services/
│   │       │   │   ├── FareService.test.js
│   │       │   │   ├── AuthService.test.js
│   │       │   │   └── RideMatchingService.test.js
│   │       │   └── models/
│   │       │       ├── User.test.js
│   │       │       └── Ride.test.js
│   │       └── integration/
│   │           ├── auth.test.js
│   │           ├── rides.test.js
│   │           └── drivers.test.js
│   │
│   ├── migrations/                      # Sequelize migrations
│   └── seeds/                           # Database seeders
│
├── apps/
│   ├── customer_app/                    # Flutter App
│   │   ├── pubspec.yaml
│   │   ├── lib/
│   │   │   ├── main.dart
│   │   │   ├── theme/
│   │   │   │   └── app_theme.dart
│   │   │   ├── routes/
│   │   │   │   └── app_routes.dart
│   │   │   ├── providers/
│   │   │   │   ├── auth_provider.dart
│   │   │   │   ├── ride_provider.dart
│   │   │   │   ├── location_provider.dart
│   │   │   │   ├── payment_provider.dart
│   │   │   │   └── notification_provider.dart
│   │   │   ├── screens/
│   │   │   │   ├── splash_screen.dart
│   │   │   │   ├── login_screen.dart
│   │   │   │   ├── home_screen.dart
│   │   │   │   ├── booking_screen.dart
│   │   │   │   ├── ride_tracking_screen.dart
│   │   │   │   ├── ride_history_screen.dart
│   │   │   │   ├── profile_screen.dart
│   │   │   │   ├── saved_places_screen.dart
│   │   │   │   ├── referrals_screen.dart
│   │   │   │   ├── support_screen.dart
│   │   │   │   └── sos_screen.dart
│   │   │   ├── widgets/
│   │   │   │   ├── pickup_drop_widget.dart
│   │   │   │   ├── fare_estimate_sheet.dart
│   │   │   │   ├── driver_card.dart
│   │   │   │   ├── ride_status_card.dart
│   │   │   │   ├── rating_widget.dart
│   │   │   │   └── bottom_nav_bar.dart
│   │   │   ├── services/
│   │   │   │   ├── api_service.dart
│   │   │   │   └── socket_service.dart
│   │   │   ├── models/
│   │   │   │   ├── user_model.dart
│   │   │   │   ├── ride_model.dart
│   │   │   │   └── driver_model.dart
│   │   │   └── utils/
│   │   │       ├── constants.dart
│   │   │       ├── helpers.dart
│   │   │       └── validators.dart
│   │   ├── android/
│   │   ├── ios/
│   │   ├── test/
│   │   └── assets/
│   │
│   ├── driver_app/                      # Flutter App (Driver)
│   │   ├── pubspec.yaml
│   │   ├── lib/
│   │   │   ├── main.dart
│   │   │   ├── theme/
│   │   │   ├── screens/
│   │   │   │   ├── splash_screen.dart
│   │   │   │   ├── login_screen.dart
│   │   │   │   ├── registration_screen.dart
│   │   │   │   ├── document_upload_screen.dart
│   │   │   │   ├── payment_screen.dart
│   │   │   │   ├── home_screen.dart
│   │   │   │   ├── ride_request_screen.dart
│   │   │   │   ├── ride_navigation_screen.dart
│   │   │   │   ├── earnings_screen.dart
│   │   │   │   ├── ride_history_screen.dart
│   │   │   │   └── profile_screen.dart
│   │   │   ├── widgets/
│   │   │   │   ├── document_card.dart
│   │   │   │   ├── ride_request_card.dart
│   │   │   │   ├── earnings_card.dart
│   │   │   │   └── status_toggle.dart
│   │   │   ├── providers/
│   │   │   ├── services/
│   │   │   └── utils/
│   │   ├── android/
│   │   ├── ios/
│   │   └── assets/
│   │
│   └── admin_dashboard/                 # React App
│       ├── package.json
│       ├── vite.config.js
│       ├── index.html
│       ├── public/
│       │   └── favicon.ico
│       └── src/
│           ├── main.jsx
│           ├── App.jsx
│           ├── components/
│           │   ├── common/
│           │   │   ├── AdminLayout.jsx
│           │   │   ├── Sidebar.jsx
│           │   │   ├── Header.jsx
│           │   │   ├── ProtectedRoute.jsx
│           │   │   ├── DataTable.jsx
│           │   │   ├── StatusChip.jsx
│           │   │   └── ConfirmDialog.jsx
│           │   ├── dashboard/
│           │   │   ├── StatCard.jsx
│           │   │   └── RevenueChart.jsx
│           │   ├── drivers/
│           │   │   ├── DriverTable.jsx
│           │   │   ├── DriverDetail.jsx
│           │   │   └── DocumentViewer.jsx
│           │   ├── rides/
│           │   │   ├── RideTable.jsx
│           │   │   └── LiveMap.jsx
│           │   └── settings/
│           │       ├── FareSettings.jsx
│           │       └── CommissionSettings.jsx
│           ├── pages/
│           │   ├── LoginPage.jsx
│           │   ├── DashboardPage.jsx
│           │   ├── DriversPage.jsx
│           │   ├── DriverDetailPage.jsx
│           │   ├── CustomersPage.jsx
│           │   ├── RidesPage.jsx
│           │   ├── ActiveRidesPage.jsx
│           │   ├── PaymentsPage.jsx
│           │   ├── RevenuePage.jsx
│           │   ├── PromoCodesPage.jsx
│           │   ├── RegistrationFeesPage.jsx
│           │   ├── SettingsPage.jsx
│           │   ├── SupportPage.jsx
│           │   ├── AuditLogsPage.jsx
│           │   └── NotFoundPage.jsx
│           ├── services/
│           │   └── api.js
│           ├── context/
│           │   ├── AuthContext.jsx
│           │   └── SocketContext.jsx
│           ├── hooks/
│           │   ├── useDrivers.js
│           │   ├── useRides.js
│           │   └── useSettings.js
│           ├── utils/
│           │   ├── formatters.js
│           │   └── validators.js
│           └── styles/
│               └── theme.js
│
├── docker/
│   ├── Dockerfile                       # Backend Docker image
│   ├── docker-compose.yml               # Local dev environment
│   └── init-db.sql                      # Database initialization
│
├── scripts/
│   ├── deploy.sh                        # Deployment script
│   ├── backup.sh                        # Database backup
│   └── seed.sh                          # Data seeding
│
├── infrastructure/
│   ├── terraform/                       # IaC (future)
│   └── cloudformation/                  # AWS templates (future)
│
└── docs/
    ├── SYSTEM_ARCHITECTURE.md
    ├── DATABASE_SCHEMA.md
    ├── ER_DIAGRAM.png
    ├── DEPLOYMENT_GUIDE.md
    ├── TESTING_STRATEGY.md
    ├── PRODUCTION_READINESS_CHECKLIST.md
    ├── USER_MANUAL_CUSTOMER.md
    ├── USER_MANUAL_DRIVER.md
    ├── USER_MANUAL_ADMIN.md
    └── FOLDER_STRUCTURE.md
```
