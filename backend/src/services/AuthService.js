const jwt = require('jsonwebtoken');
const config = require('../config');
const { User, Customer, Driver, AdminUser, Wallet } = require('../models');
const { generateTokens } = require('../middleware/auth');
const { ApiError } = require('../middleware/errorHandler');
const OtpService = require('./OtpService');

class AuthService {
  async sendOTP(phone) {
    const result = await OtpService.sendOTP(phone);
    return result;
  }

  async verifyOTP(phone, otp, role = 'customer', fullName = null) {
    // Verify OTP
    OtpService.verifyOTP(phone, otp);

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

  /**
   * Update the signed-in user's own profile.
   *
   * AuthController.updateProfile has always called authService.updateProfile(),
   * but this method never existed - so PUT /auth/profile threw
   * "authService.updateProfile is not a function" and returned a 500 on every
   * request, including an empty body. Only a safe allow-list of columns is
   * writable here; role, phone and verification flags are deliberately not.
   */
  async updateProfile(userId, data = {}) {
    const user = await User.findByPk(userId);
    if (!user) throw new ApiError(404, 'User not found');

    if (typeof data.full_name === 'string' && data.full_name.trim() !== '') {
      user.full_name = data.full_name.trim();
    }
    if (typeof data.email === 'string') {
      const email = data.email.trim();
      if (email === '') {
        user.email = null;
      } else {
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
          throw new ApiError(400, 'Please enter a valid email address');
        }
        const clash = await User.findOne({ where: { email } });
        if (clash && clash.id !== user.id) {
          throw new ApiError(409, 'That email is already in use');
        }
        user.email = email;
      }
    }
    if (typeof data.avatar_url === 'string') {
      user.avatar_url = data.avatar_url.trim() === '' ? null : data.avatar_url.trim();
    }

    await user.save();

    let profile = null;
    const customer = await Customer.findOne({ where: { user_id: user.id } });
    if (customer) {
      if (data.gender !== undefined) customer.gender = data.gender;
      if (data.date_of_birth !== undefined) customer.date_of_birth = data.date_of_birth || null;
      await customer.save();
      profile = customer;
    } else {
      const driver = await Driver.findOne({ where: { user_id: user.id } });
      if (driver) {
        if (data.gender !== undefined) driver.gender = data.gender;
        if (data.date_of_birth !== undefined) driver.date_of_birth = data.date_of_birth || null;
        if (data.address !== undefined) driver.address = data.address;
        if (data.city !== undefined) driver.city = data.city;
        if (data.state !== undefined) driver.state = data.state;
        if (data.pincode !== undefined) driver.pincode = data.pincode;
        await driver.save();
        profile = driver;
      }
    }

    return { user: user.getSafeProfile(), profile };
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