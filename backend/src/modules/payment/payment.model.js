const mongoose = require("mongoose");

const paymentStatusEnum = [
  "created",
  "authorized",
  "captured",
  "paid",
  "verified",
  "failed",
  "webhook_received",
];

const paymentTransactionSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: false,
      default: null,
      index: true,
    },
    provider: {
      type: String,
      required: true,
      default: "razorpay",
      trim: true,
      index: true,
    },
    source: {
      type: String,
      required: true,
      default: "customer_monthly_due",
      trim: true,
      index: true,
    },
    orderId: {
      type: String,
      required: true,
      trim: true,
      unique: true,
      index: true,
    },
    paymentId: {
      type: String,
      required: false,
      default: null,
      trim: true,
    },
    razorpaySignature: {
      type: String,
      required: false,
      default: null,
      trim: true,
    },
    amountInPaise: { type: Number, required: true, min: 0, default: 0 },
    amountInRupees: { type: Number, required: true, min: 0, default: 0 },
    currency: {
      type: String,
      required: true,
      default: "INR",
      trim: true,
      uppercase: true,
    },
    receipt: { type: String, required: false, default: null, trim: true },
    status: {
      type: String,
      required: true,
      enum: paymentStatusEnum,
      default: "created",
      index: true,
    },
    notes: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
    },
    verificationMethod: {
      type: String,
      required: false,
      default: null,
      trim: true,
    },
    verifiedAt: { type: Date, required: false, default: null },
    webhookLastEventId: {
      type: String,
      required: false,
      default: null,
      trim: true,
    },
    webhookLastEvent: {
      type: String,
      required: false,
      default: null,
      trim: true,
    },
    webhookLastReceivedAt: { type: Date, required: false, default: null },
    metadata: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
    },
  },
  {
    timestamps: true,
    versionKey: false,
  },
);

paymentTransactionSchema.index({ paymentId: 1 }, { sparse: true });
paymentTransactionSchema.index({ orderId: 1, status: 1 });
paymentTransactionSchema.index({
  userId: 1,
  source: 1,
  status: 1,
  "notes.month": 1,
});

const PaymentTransactionModel = mongoose.model(
  "PaymentTransaction",
  paymentTransactionSchema,
);

module.exports = { PaymentTransactionModel, paymentStatusEnum };
