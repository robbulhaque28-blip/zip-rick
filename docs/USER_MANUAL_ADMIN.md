# Vybe Admin Dashboard User Manual

## Accessing the Dashboard

1. Open your browser and go to `https://admin.vybe.com`
2. Enter your **Email** and **Password**
3. Click **"Sign In"**
4. You'll be redirected to the main dashboard

---

## Dashboard Overview

The dashboard provides real-time analytics:

### Key Metrics Cards
- **Total Customers**: Registered users
- **Total Drivers**: All registered drivers
- **Pending Approvals**: Drivers awaiting review
- **Active Rides**: Rides currently in progress
- **Today's Revenue**: Earnings for today
- **Total Revenue**: Platform earnings all-time

### Charts & Graphs
- **Revenue Trend**: Daily/weekly/monthly revenue chart
- **Ride Volume**: Number of rides over time
- **Driver Status**: Online/offline/active drivers
- **Customer Growth**: New customer registrations

---

## Driver Management

### View All Drivers
1. Click **"Drivers"** in sidebar
2. Filter by status:
   - All
   - Pending Approval
   - Approved
   - Rejected
   - Suspended
3. Search by name or phone number
4. Sort by registration date

### Driver Details
Click on any driver to view:
- Personal information
- Documents (Aadhaar, RC, Selfie)
- Vehicle details
- Registration payment status
- Ride history
- Earnings summary
- Ratings & reviews

### Approve Driver
1. Review all uploaded documents
2. Verify:
   - Aadhaar details match selfie
   - RC document is valid
   - Registration fee paid (₹499/₹999)
3. Click **"Approve"**
4. Optional: Add approval notes
5. Driver receives notification

### Reject Driver
1. Select reason from dropdown:
   - Document mismatch
   - Blurry/illegible documents
   - Incomplete information
   - Expired documents
   - Other (specify)
2. Click **"Reject"**
3. Driver receives rejection reason
4. Driver can re-upload and resubmit

### Suspend Driver
1. Click **"Suspend"**
2. Enter suspension reason
3. Driver immediately goes offline
4. Cannot accept rides until unsuspended

---

## Customer Management

### View Customers
1. Click **"Customers"** in sidebar
2. Search by name, phone, or email
3. View:
   - Total rides taken
   - Total spent
   - Average rating
   - Referral code
   - Loyalty points

### Customer Actions
- **View Details**: Complete profile and ride history
- **Block**: Prevent customer from booking rides
- **Unblock**: Restore access

---

## Ride Management

### Active Rides
1. Click **"Rides"** → **"Active Rides"**
2. Live map showing all ongoing rides
3. Each ride shows:
   - Customer name
   - Driver name
   - Pickup → Drop route
   - Current status
   - Duration

### Ride Details
Click any ride to view:
- Complete route on map
- Fare breakdown
- Payment status
- Status history timeline
- Customer & driver info
- Chat logs (if any)

### Ride History
1. Click **"Rides"** → **"History"**
2. Filter by date range
3. Export as CSV/JSON
4. View detailed analytics

---

## Fare Management

### Configure Pricing
1. Click **"Settings"** → **"Fare Rates"**
2. Edit parameters:

| Parameter | Default | Description |
|-----------|---------|-------------|
| Base Fare | ₹30 | Starting fare |
| Per KM Rate | ₹12 | Cost per kilometer |
| Per Minute Rate | ₹1 | Cost per minute |
| Minimum Fare | ₹30 | Minimum charge |
| Night Charge Multiplier | 1.5x | 10 PM - 6 AM |
| Peak Hour Multiplier | 1.2x | 8-10 AM, 5-8 PM |
| Waiting Charge | ₹2/min | After 5 min free |

3. Click **"Save Changes"**

### Night Charge Hours
- Start: 22:00 (10 PM)
- End: 06:00 (6 AM)

### Peak Hours
- Morning: 8:00 - 10:00
- Evening: 17:00 - 20:00

---

## Registration Fee Management

### Configure Fee
1. Click **"Settings"** → **"Registration Fee"**
2. Set:
   - **Standard Fee**: Default ₹999
   - **Promotional Fee**: Default ₹499
   - **Promotion Active**: Toggle on/off

### View Payments
1. Click **"Registration Payments"**
2. See all fee payments with:
   - Driver name & phone
   - Amount paid
   - Payment method
   - Payment status
   - Date & time

### Issue Refund
1. Find the driver's payment
2. Click **"Refund"**
3. Enter reason for refund
4. Confirm refund
5. Amount reversed to driver's account

---

## Commission Management

### View Commission Settings
1. Click **"Settings"** → **"Commission"**
2. Default: 10%
3. Adjust as needed
4. Changes apply immediately to future rides

### Commission Reports
- Total commission collected
- Daily/Weekly/Monthly breakdown
- Top-earning drivers

---

## Promo Code Management

### Create Promo Code
1. Click **"Promotions"** → **"Create Promo"**
2. Enter:
   - **Code**: e.g., "ZIP50"
   - **Description**: e.g., "50% off up to ₹50"
   - **Discount Type**: Percentage or Fixed
   - **Discount Value**: e.g., 50 (for 50%)
   - **Max Discount**: e.g., ₹50
   - **Min Order Value**: e.g., ₹100
   - **Max Uses**: Total redemption limit
   - **Max Per User**: Times each user can use
   - **Valid From/To**: Date range
   - **Applicable To**: All/New/Existing customers

3. Click **"Create"**

### Manage Promos
- **Edit**: Modify existing promo codes
- **Disable**: Temporarily stop a promo
- **Delete**: Remove permanently
- **View Stats**: Redemption count, total discount given

---

## Revenue & Reports

### Revenue Dashboard
1. Click **"Revenue"** in sidebar
2. View:
   - **Daily Revenue**: Today's earnings
   - **Monthly Revenue**: Current month
   - **Total Revenue**: All-time
   - **Commission Collected**: Platform fees
   - **Average Ride Value**: Revenue per ride

### Export Reports
1. Click **"Reports"** → Select type:
   - **Rides Report**: All ride data
   - **Drivers Report**: Driver database
   - **Payments Report**: Payment transactions
   - **Revenue Report**: Financial summary
   - **Registration Payments**: Fee collections

2. Select format: **CSV** or **JSON**
3. Optional: Set date range
4. Click **"Export"**
5. File downloads automatically

---

## Support Tickets

### View Tickets
1. Click **"Support"** in sidebar
2. Filter by status:
   - Open
   - In Progress
   - Resolved
   - Closed
3. Sort by priority: Low, Medium, High, Urgent

### Handle Ticket
1. Click a ticket to open
2. Read customer/driver message
3. **Assign** to yourself or another admin
4. Reply with solution
5. Change status as work progresses
6. Mark **"Resolved"** when complete

---

## Notification Broadcast

### Send Broadcast
1. Click **"Notifications"** → **"Send Broadcast"**
2. Compose:
   - **Title**: Notification heading
   - **Body**: Message content
   - **Target**: All / Customers / Drivers
3. Click **"Send"**
4. Push notification sent to all target users

---

## System Settings

### Manage Settings
1. Click **"Settings"** → **"System"**
2. View all configurable settings:
   - Ride matching radius (default: 5 km)
   - Search timeout (default: 60 sec)
   - SOS alert timeout
   - Referral reward amount
   - Cancellation charges

---

## Audit Logs

### View Activity
1. Click **"Audit Logs"** in sidebar
2. See all admin actions:
   - Driver approvals/rejections
   - Setting changes
   - Refund issuances
   - Customer blocks
3. Filter by action type, date, or admin

---

## Best Practices

1. **Review drivers promptly** - Aim for < 24 hours
2. **Monitor active rides** - Check live map regularly
3. **Update fares competitively** - Review market rates weekly
4. **Promote during off-peak** - Use promo codes to boost demand
5. **Handle support quickly** - Target < 1 hour response time
6. **Review commission structure** - Balance driver earnings with platform revenue
7. **Regular data backups** - Verify backup completion daily
8. **Track suspicious activity** - Monitor for fraud patterns
