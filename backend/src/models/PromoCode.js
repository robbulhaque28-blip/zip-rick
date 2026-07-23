const { Model, DataTypes } = require('sequelize');
const { sequelize } = require('../config/db');
class PromoCode extends Model {}
PromoCode.init({
    id: { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
    code: { type: DataTypes.STRING, allowNull: false, unique: true },
    discount: { type: DataTypes.DECIMAL(5, 2), allowNull: false, defaultValue: 10 },
    discount_type: { type: DataTypes.STRING, defaultValue: 'percentage' },
    max_uses: { type: DataTypes.INTEGER, defaultValue: 100 },
    min_fare: { type: DataTypes.DECIMAL(10, 2), defaultValue: 0 },
    usage_count: { type: DataTypes.INTEGER, defaultValue: 0 },
    status: { type: DataTypes.STRING, defaultValue: 'active' },
    expires_at: { type: DataTypes.DATE, allowNull: true },
    created_by: { type: DataTypes.UUID, allowNull: true },
}, { sequelize, modelName: 'PromoCode', tableName: 'promo_codes' });
module.exports = PromoCode;
