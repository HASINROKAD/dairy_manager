const mongoose = require("mongoose");

const sellerCapacitySchema = new mongoose.Schema(
  {
    sellerUserId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      unique: true,
      ref: "User",
      index: true,
    },
    maxActiveCustomers: {
      type: Number,
      min: 1,
      default: null,
    },
    maxLitresPerDay: {
      type: Number,
      min: 0.1,
      default: null,
    },
  },
  {
    timestamps: true,
    versionKey: false,
  },
);

const SellerCapacityModel = mongoose.model(
  "SellerCapacity",
  sellerCapacitySchema,
);

module.exports = { SellerCapacityModel };
