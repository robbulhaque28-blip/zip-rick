const { Model, DataTypes } = require('sequelize');
const { sequelize } = require('../config/db');

class RatingReview extends Model {}

RatingReview.init(
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    ride_id: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    rating: {
      type: DataTypes.INTEGER,
      allowNull: false,
    },
    review: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    rater_id: {
      type: DataTypes.UUID,
      allowNull: true,
    },
  },
  {
    sequelize,
    modelName: 'RatingReview',
    tableName: 'rating_reviews',
  }
);

module.exports = RatingReview;
