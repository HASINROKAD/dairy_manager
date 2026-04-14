const mongoose = require("mongoose");

const deliveryPauseStatusEnum = ["active", "resumed"];

const deliveryPauseSchema = new mongoose.Schema(
  {
    customerUserId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      ref: "User",
      index: true,
    },
    sellerUserId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      ref: "User",
      index: true,
    },
    startDateKey: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    endDateKey: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    status: {
      type: String,
      enum: deliveryPauseStatusEnum,
      default: "active",
      index: true,
    },
    resumedAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
    versionKey: false,
  },
);

deliveryPauseSchema.index({
  customerUserId: 1,
  sellerUserId: 1,
  startDateKey: 1,
  endDateKey: 1,
});

const DeliveryPauseModel = mongoose.model("DeliveryPause", deliveryPauseSchema);

module.exports = { DeliveryPauseModel, deliveryPauseStatusEnum };
