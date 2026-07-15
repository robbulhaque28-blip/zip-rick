const jwt = require('jsonwebtoken');
const config = require('../config');
const { User, Customer, Driver, AdminUser, Wallet } = require('../models');
const { generateTokens } = require('../middleware/auth');
const { ApiError } = require('../middleware/errorHandler');

class AuthService {
  async sendOTP(phone) { return { message: 'OTP sent', phone }; }

  async verifyOTP(phone, otp, role = 'customer', fullName = null) {
    let user = await User.findOne({ where: { phone } });

    if (!user) {
      if (!fullName || fullName.trim() === '') throw new ApiError(400, 'Name is required');
      user = await User.create({ phone, full_name: fullName, role, is_phone_verified: true });
    } else {
      if (fullName && fullName.trim() !== '') user.full_name = fullName;
      user.last_login_at = new Date();
      await user.save();
    }

    if (role === 'customer') {
      let cust = await Customer.findOne({ where: { user_id: user.id } });
      if (!cust) cust = await Customer.create({ user_id: user.id });
      let w = await Wallet.findOne({ where: { user_id: user.id } });
      if (!w) w = await Wallet.create({ user_id: user.id });
    } else if (role === 'driver') {
      let drv = await Driver.findOne({ where: { user_id: user.id } });
      if (!drv) drv = await Driver.create({ user_id: user.id, registration_status: 'pending' });
      let w = await Wallet.findOne({ where: { user_id: user.id } });
      if (!w) w = await Wallet.create({ user_id: user.id });
    }

    const tokens = generateTokens(user);
    let profile = null;
    if (role === 'customer') profile = await Customer.findOne({ where: { user_id: user.id } });
    else if (role === 'driver') profile = await Driver.findOne({ where: { user_id: user.id } });

    return { user: user.getSafeProfile(), profile, tokens, is_new_user: !user.last_login_at };
  }

  async adminLogin(email, password) {
    const bcrypt = require('bcryptjs');
    const { sequelize } = require('../models');

    // Fixed: Using parameterized query instead of string concatenation
    const [admins] = await sequelize.query(
      'SELECT * FROM admin_users WHERE email = $1',
      { bind: [email] }
    );

    if (!admins || admins.length === 0) throw new ApiError(401, 'Invalid credentials');
    const a = admins[0];
    const pw = a.password_hash || a.password;
    if (!pw || !(await bcrypt.compare(password, pw))) throw new ApiError(401, 'Invalid credentials');
    const user = await User.findByPk(a.user_id);
    if (!user || !user.is_active) throw new ApiError(401, 'Invalid credentials');
    const tokens = generateTokens(user);
    return { admin: { id: a.id, email: a.email, role: a.role, user: user.getSafeProfile() }, tokens };
  }
}

module.exports = new AuthService();