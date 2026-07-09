const jwt = require('jsonwebtoken');
const config = require('../config');
const { User, Customer, Driver, AdminUser, Wallet } = require('../models');
const { generateTokens } = require('../middleware/auth');
const { ApiError } = require('../middleware/errorHandler');
const logger = require('../utils/logger');

class AuthService {
  async sendOTP(phone) { return { message: 'OTP sent', phone }; }
  
  async verifyOTP(phone, otp, role = 'customer', fullName = null) {
    let user = await User.findOne({ where: { phone } });
    
    if (!user) {
      // New user - name is required
      if (!fullName) {
        throw new ApiError(400, 'Name is required for new users');
      }
      user = await User.create({
        phone,
        full_name: fullName,
        role,
        is_phone_verified: true,
      });
      if (role === 'customer') await Customer.create({ user_id: user.id });
      else if (role === 'driver') await Driver.create({ user_id: user.id, registration_status: 'pending' });
      await Wallet.create({ user_id: user.id });
    } else {
      // Existing user - update name if provided
      if (fullName && fullName.isNotEmpty) {
        user.full_name = fullName;
      }
      user.last_login_at = new Date();
      await user.save();
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
    const [admins] = await sequelize.query("SELECT * FROM admin_users WHERE email = '" + email + "'");
    if (!admins || admins.length === 0) throw new ApiError(401, 'Invalid credentials');
    const adminRecord = admins[0];
    const storedPassword = adminRecord.password_hash || adminRecord.password;
    if (!storedPassword || !(await bcrypt.compare(password, storedPassword))) {
      throw new ApiError(401, 'Invalid credentials');
    }
    const user = await User.findByPk(adminRecord.user_id);
    if (!user || !user.is_active) throw new ApiError(401, 'Invalid credentials');
    const tokens = generateTokens(user);
    return { admin: { id: adminRecord.id, email: adminRecord.email, role: adminRecord.role, user: user.getSafeProfile() }, tokens };
  }
}
module.exports = new AuthService();
