# Zip-Rick Database Schema

## Entity Relationship Overview

```
┌──────────────┐     ┌───────────────┐     ┌──────────────┐
│    users     │────>│   customers   │     │   drivers    │
│  (base auth) │     └───────────────┘     │  (profile)   │
└──────────────┘                           └──────┬───────┘
       │                                          │
       │                                          │
       │               ┌──────────────────────────┘
       │               │
       │               ▼
       │     ┌──────────────────┐     ┌────────────────────┐
       │     │ driver_documents │     │ driver_reg_payments│
       │     ├──────────────────┤     ├────────────────────┤
       │     │ vehicles         │     │ wallets            │
       │     └──────────────────┘     └────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────┐
│                     rides                            │
│  (core transaction table linking customers, drivers) │
├─────────────────────────────────────────────────────┤
│  ride_status_logs                                    │
│  payments                                            │
│  transactions                                        │
│  ratings_reviews                                     │
└─────────────────────────────────────────────────────┘

┌──────────────┐     ┌───────────────┐
│ promo_codes  │     │  referrals    │
├──────────────┤     ├───────────────┤
│ notifications│     │ support_tickets
│ saved_places │     │ admin_users   │
│ fav_locations│     │ system_settings
│ audit_logs   │     └───────────────┘
└──────────────┘
```

## Complete Table Definitions

### 1. users
Core authentication and base profile table.

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone VARCHAR(15) UNIQUE NOT NULL,
  email VARCHAR(255) UNIQUE,
  full_name VARCHAR(255) NOT NULL,
  role VARCHAR(20) NOT NULL CHECK (role IN ('customer', 'driver', 'admin')),
  avatar_url TEXT,
  is_phone_verified BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  is_blocked BOOLEAN DEFAULT FALSE,
  fcm_token TEXT,
  last_login_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_role ON users(role);
```

### 2. customers
Customer-specific profile data.

```sql
CREATE TABLE customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  total_rides INTEGER DEFAULT 0,
  total_spent DECIMAL(10,2) DEFAULT 0.00,
  rating DECIMAL(2,1) DEFAULT 0.0,
  rating_count INTEGER DEFAULT 0,
  referral_code VARCHAR(20) UNIQUE,
  referred_by UUID REFERENCES customers(id),
  loyalty_points INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 3. drivers
Driver-specific profile, verification, and operational data.

```sql
CREATE TABLE drivers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  -- Personal Info
  date_of_birth DATE,
  gender VARCHAR(10),
  address TEXT,
  city VARCHAR(100),
  state VARCHAR(100),
  pincode VARCHAR(10),
  
  -- Document Status
  aadhaar_verified BOOLEAN DEFAULT FALSE,
  rc_verified BOOLEAN DEFAULT FALSE,
  selfie_verified BOOLEAN DEFAULT FALSE,
  is_documents_uploaded BOOLEAN DEFAULT FALSE,
  
  -- Registration
  registration_fee_paid BOOLEAN DEFAULT FALSE,
  registration_fee_amount DECIMAL(10,2) DEFAULT 0.00,
  registration_status VARCHAR(20) DEFAULT 'pending' 
    CHECK (registration_status IN ('pending', 'approved', 'rejected', 'suspended')),
  registration_completed_at TIMESTAMPTZ,
  rejection_reason TEXT,
  approved_by UUID REFERENCES admin_users(id),
  approved_at TIMESTAMPTZ,
  
  -- Operations
  is_online BOOLEAN DEFAULT FALSE,
  is_available BOOLEAN DEFAULT FALSE,
  current_latitude DECIMAL(10,8),
  current_longitude DECIMAL(11,8),
  last_location_update TIMESTAMPTZ,
  current_ride_id UUID,
  
  -- Earnings
  total_earnings DECIMAL(12,2) DEFAULT 0.00,
  total_rides INTEGER DEFAULT 0,
  total_ratings INTEGER DEFAULT 0,
  rating_sum INTEGER DEFAULT 0,
  rating_avg DECIMAL(2,1) DEFAULT 0.0,
  
  -- Commission
  commission_rate DECIMAL(5,2) DEFAULT 10.00,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_drivers_location ON drivers(current_latitude, current_longitude);
CREATE INDEX idx_drivers_online ON drivers(is_online, is_available);
CREATE INDEX idx_drivers_status ON drivers(registration_status);
```

### 4. driver_documents
Uploaded document records.

```sql
CREATE TABLE driver_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
  document_type VARCHAR(50) NOT NULL CHECK (document_type IN ('aadhaar_front', 'aadhaar_back', 'rc_front', 'rc_back', 'selfie', 'driving_license', 'other')),
  document_url TEXT NOT NULL,
  document_status VARCHAR(20) DEFAULT 'pending' CHECK (document_status IN ('pending', 'verified', 'rejected')),
  verification_notes TEXT,
  verified_by UUID REFERENCES admin_users(id),
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_driver_docs_driver ON driver_documents(driver_id);
```

### 5. driver_registration_payments
Registration fee payment records.

```sql
CREATE TABLE driver_registration_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
  amount DECIMAL(10,2) NOT NULL,
  payment_method VARCHAR(20) NOT NULL CHECK (payment_method IN ('upi', 'cash', 'card', 'wallet')),
  payment_status VARCHAR(20) NOT NULL CHECK (payment_status IN ('pending', 'completed', 'failed', 'refunded')),
  razorpay_order_id VARCHAR(100),
  razorpay_payment_id VARCHAR(100),
  razorpay_signature VARCHAR(255),
  transaction_id TEXT,
  payment_details JSONB,
  refunded_at TIMESTAMPTZ,
  refund_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 6. vehicles
E-Rickshaw details.

```sql
CREATE TABLE vehicles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID UNIQUE NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
  registration_number VARCHAR(20) UNIQUE NOT NULL,
  vehicle_model VARCHAR(100),
  manufacturer VARCHAR(100),
  year INTEGER,
  color VARCHAR(50),
  battery_capacity VARCHAR(50),
  range_per_charge INTEGER, -- in kms
  seating_capacity INTEGER DEFAULT 4,
  rc_document_url TEXT,
  insurance_document_url TEXT,
  vehicle_image_url TEXT,
  is_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 7. rides
Core ride transaction table.

```sql
CREATE TABLE rides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_number VARCHAR(20) UNIQUE NOT NULL, -- e.g., ZR-20260706-XXXXX
  
  -- Customer
  customer_id UUID NOT NULL REFERENCES customers(id),
  driver_id UUID REFERENCES drivers(id),
  
  -- Route
  pickup_latitude DECIMAL(10,8) NOT NULL,
  pickup_longitude DECIMAL(11,8) NOT NULL,
  pickup_address TEXT NOT NULL,
  drop_latitude DECIMAL(10,8) NOT NULL,
  drop_longitude DECIMAL(11,8) NOT NULL,
  drop_address TEXT NOT NULL,
  pickup_place_id VARCHAR(255),
  drop_place_id VARCHAR(255),
  
  -- Route Data
  route_distance DECIMAL(10,2), -- in meters
  route_duration INTEGER, -- in seconds
  route_polyline TEXT, -- encoded polyline
  
  -- Fare
  base_fare DECIMAL(10,2) NOT NULL,
  distance_fare DECIMAL(10,2) NOT NULL DEFAULT 0,
  time_fare DECIMAL(10,2) NOT NULL DEFAULT 0,
  waiting_charges DECIMAL(10,2) DEFAULT 0,
  night_charges DECIMAL(10,2) DEFAULT 0,
  peak_charges DECIMAL(10,2) DEFAULT 0,
  promo_discount DECIMAL(10,2) DEFAULT 0,
  cancellation_charges DECIMAL(10,2) DEFAULT 0,
  total_fare DECIMAL(10,2) NOT NULL,
  commission_amount DECIMAL(10,2) DEFAULT 0,
  driver_earnings DECIMAL(10,2) DEFAULT 0,
  
  -- Status
  status VARCHAR(30) NOT NULL CHECK (status IN (
    'pending', 'searching', 'driver_assigned', 'driver_arrived',
    'started', 'completed', 'cancelled', 'no_driver_found'
  )),
  cancellation_reason TEXT,
  cancelled_by VARCHAR(20) CHECK (cancelled_by IN ('customer', 'driver', 'system', 'admin')),
  cancelled_at TIMESTAMPTZ,
  
  -- Timing
  driver_assigned_at TIMESTAMPTZ,
  driver_arrived_at TIMESTAMPTZ,
  ride_started_at TIMESTAMPTZ,
  ride_completed_at TIMESTAMPTZ,
  
  -- Payment
  payment_method VARCHAR(20) CHECK (payment_method IN ('cash', 'upi')),
  payment_status VARCHAR(20) DEFAULT 'pending' CHECK (payment_status IN ('pending', 'completed', 'failed', 'refunded')),
  
  -- Tracking
  tracking_enabled BOOLEAN DEFAULT TRUE,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_rides_customer ON rides(customer_id);
CREATE INDEX idx_rides_driver ON rides(driver_id);
CREATE INDEX idx_rides_status ON rides(status);
CREATE INDEX idx_rides_created ON rides(created_at DESC);
```

### 8. ride_status_logs
Audit trail for ride status changes.

```sql
CREATE TABLE ride_status_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  previous_status VARCHAR(30),
  new_status VARCHAR(30) NOT NULL,
  changed_by VARCHAR(20) NOT NULL,
  changed_by_id UUID,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ride_logs_ride ON ride_status_logs(ride_id);
```

### 9. payments
Ride payment records.

```sql
CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES customers(id),
  driver_id UUID REFERENCES drivers(id),
  amount DECIMAL(10,2) NOT NULL,
  commission DECIMAL(10,2) DEFAULT 0,
  driver_amount DECIMAL(10,2) DEFAULT 0,
  payment_method VARCHAR(20) NOT NULL CHECK (payment_method IN ('cash', 'upi')),
  payment_status VARCHAR(20) NOT NULL CHECK (payment_status IN ('pending', 'processing', 'completed', 'failed', 'refunded')),
  razorpay_order_id VARCHAR(100),
  razorpay_payment_id VARCHAR(100),
  razorpay_signature VARCHAR(255),
  transaction_reference VARCHAR(255),
  payment_details JSONB,
  refund_id VARCHAR(100),
  refund_amount DECIMAL(10,2),
  refund_reason TEXT,
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 10. transactions
Wallet and financial transactions.

```sql
CREATE TABLE transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  type VARCHAR(30) NOT NULL CHECK (type IN (
    'ride_payment', 'ride_earning', 'commission_deduction',
    'registration_fee', 'wallet_topup', 'wallet_withdrawal',
    'refund', 'bonus', 'referral_reward', 'promo_credit'
  )),
  amount DECIMAL(10,2) NOT NULL,
  balance_before DECIMAL(10,2),
  balance_after DECIMAL(10,2),
  reference_type VARCHAR(30), -- 'ride', 'registration', etc.
  reference_id UUID,
  description TEXT,
  status VARCHAR(20) DEFAULT 'completed',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_transactions_user ON transactions(user_id);
CREATE INDEX idx_transactions_type ON transactions(type);
```

### 11. wallets

```sql
CREATE TABLE wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  balance DECIMAL(10,2) DEFAULT 0.00,
  total_credited DECIMAL(12,2) DEFAULT 0.00,
  total_debited DECIMAL(12,2) DEFAULT 0.00,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 12. ratings_reviews

```sql
CREATE TABLE ratings_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id UUID UNIQUE NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES customers(id),
  driver_id UUID NOT NULL REFERENCES drivers(id),
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  review TEXT,
  customer_comment TEXT,
  driver_comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ratings_driver ON ratings_reviews(driver_id);
CREATE INDEX idx_ratings_customer ON ratings_reviews(customer_id);
```

### 13. notifications

```sql
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type VARCHAR(50) NOT NULL,
  title VARCHAR(255) NOT NULL,
  body TEXT,
  data JSONB,
  is_read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMPTZ,
  image_url TEXT,
  deep_link TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON notifications(user_id, is_read, created_at DESC);
```

### 14. promo_codes

```sql
CREATE TABLE promo_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(50) UNIQUE NOT NULL,
  description TEXT,
  discount_type VARCHAR(20) NOT NULL CHECK (discount_type IN ('percentage', 'fixed')),
  discount_value DECIMAL(10,2) NOT NULL,
  max_discount DECIMAL(10,2),
  min_order_value DECIMAL(10,2) DEFAULT 0,
  max_uses INTEGER,
  max_uses_per_user INTEGER DEFAULT 1,
  usage_count INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  starts_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  applicable_for VARCHAR(20) CHECK (applicable_for IN ('all', 'new_customers', 'existing_customers')),
  created_by UUID REFERENCES admin_users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE promo_redemptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  promo_code_id UUID NOT NULL REFERENCES promo_codes(id),
  user_id UUID NOT NULL REFERENCES users(id),
  ride_id UUID REFERENCES rides(id),
  discount_amount DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(promo_code_id, user_id, ride_id)
);
```

### 15. referrals

```sql
CREATE TABLE referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_customer_id UUID NOT NULL REFERENCES customers(id),
  referred_customer_id UUID NOT NULL REFERENCES customers(id),
  referral_code VARCHAR(20) NOT NULL,
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'expired')),
  reward_amount DECIMAL(10,2),
  reward_paid BOOLEAN DEFAULT FALSE,
  referred_ride_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);
```

### 16. saved_places

```sql
CREATE TABLE saved_places (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  label VARCHAR(50) NOT NULL, -- 'Home', 'Work', or custom
  address TEXT NOT NULL,
  latitude DECIMAL(10,8) NOT NULL,
  longitude DECIMAL(11,8) NOT NULL,
  place_id VARCHAR(255),
  is_favorite BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_saved_places_customer ON saved_places(customer_id);
```

### 17. support_tickets

```sql
CREATE TABLE support_tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  ticket_number VARCHAR(20) UNIQUE NOT NULL,
  category VARCHAR(50) NOT NULL,
  subject VARCHAR(255) NOT NULL,
  description TEXT NOT NULL,
  priority VARCHAR(20) DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
  status VARCHAR(20) DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
  assigned_to UUID REFERENCES admin_users(id),
  ride_id UUID REFERENCES rides(id),
  attachments JSONB,
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE support_ticket_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id UUID NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES users(id),
  sender_role VARCHAR(20) NOT NULL,
  message TEXT NOT NULL,
  attachments JSONB,
  is_admin_reply BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 18. admin_users

```sql
CREATE TABLE admin_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(30) NOT NULL CHECK (role IN ('super_admin', 'admin', 'support', 'finance', 'operations')),
  permissions JSONB,
  is_active BOOLEAN DEFAULT TRUE,
  last_login_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 19. system_settings

```sql
CREATE TABLE system_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key VARCHAR(100) UNIQUE NOT NULL,
  value JSONB NOT NULL,
  description TEXT,
  category VARCHAR(50),
  is_public BOOLEAN DEFAULT FALSE,
  updated_by UUID REFERENCES admin_users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed default settings
INSERT INTO system_settings (key, value, description, category) VALUES
('registration_fee', '{"standard": 999, "promotional": 499, "promotion_active": true}', 'Driver registration fee configuration', 'drivers'),
('fare_rates', '{"base_fare": 30, "per_km": 12, "per_minute": 1, "minimum_fare": 30, "waiting_charge_per_min": 2, "night_charge_multiplier": 1.5, "night_start_hour": 22, "night_end_hour": 6}', 'Fare calculation rates', 'pricing'),
('commission', '{"rate": 10, "type": "percentage"}', 'Platform commission settings', 'pricing'),
('cancellation', '{"customer_cancel_fee": 10, "driver_cancel_fee": 5, "cancel_within_seconds": 120}', 'Cancellation charges', 'pricing'),
('ride_matching', '{"max_search_radius_km": 5, "search_timeout_seconds": 60, "max_drivers_to_try": 10}', 'Ride matching configuration', 'operations'),
('sos', '{"emergency_contacts": [], "alert_timeout_minutes": 5}', 'SOS emergency settings', 'safety'),
('referral', '{"reward_amount": 50, "min_rides_for_reward": 3}', 'Referral program settings', 'marketing');
```

### 20. audit_logs

```sql
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID,
  action VARCHAR(50) NOT NULL,
  resource_type VARCHAR(50) NOT NULL,
  resource_id UUID,
  old_values JSONB,
  new_values JSONB,
  ip_address VARCHAR(45),
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_resource ON audit_logs(resource_type, resource_id);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at DESC);
```

### 21. chat_messages

```sql
CREATE TABLE chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES users(id),
  sender_role VARCHAR(20) NOT NULL,
  message TEXT NOT NULL,
  message_type VARCHAR(20) DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'location', 'system')),
  is_read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_chat_ride ON chat_messages(ride_id, created_at);
```

## Migration Strategy

- Use Sequelize migrations for schema versioning
- All migrations forward-only, no destructive backfills
- Blue-green deployment for zero-downtime migrations

## Backup Strategy

- Daily automated pg_dump to S3 (30-day retention)
- Write-ahead log (WAL) archiving for point-in-time recovery
- Cross-region replication for disaster recovery
