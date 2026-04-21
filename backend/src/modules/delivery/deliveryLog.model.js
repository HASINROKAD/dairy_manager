const mongoose = require("mongoose");

const deliveryLogSchema = new mongoose.Schema(
  {
    customerId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      ref: "User",
      index: true,
    },
    customerFirebaseUid: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    sellerFirebaseUid: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    dateKey: { type: String, required: true, trim: true, index: true },
    morningQuantityLitres: { type: Number, required: true, min: 0, default: 0 },
    eveningQuantityLitres: { type: Number, required: true, min: 0, default: 0 },
    deliverySlot: {
      type: String,
      enum: ["morning", "evening"],
      default: "morning",
    },
    quantityLitres: { type: Number, required: true, min: 0 },
    basePricePerLitreRupees: { type: Number, required: true, min: 0 },
    totalPriceRupees: { type: Number, required: true, min: 0 },
    delivered: { type: Boolean, required: true, default: false },
    adjustedManually: { type: Boolean, required: true, default: false },
  },
  {
    timestamps: true,
    versionKey: false,
  },
);

deliveryLogSchema.index(
  { customerId: 1, sellerFirebaseUid: 1, dateKey: 1 },
  { unique: true },
);
deliveryLogSchema.index({ customerFirebaseUid: 1, dateKey: -1, createdAt: -1 });
deliveryLogSchema.index({ sellerFirebaseUid: 1, dateKey: -1, createdAt: -1 });

const DeliveryLogModel = mongoose.model("DeliveryLog", deliveryLogSchema);

module.exports = { DeliveryLogModel };
