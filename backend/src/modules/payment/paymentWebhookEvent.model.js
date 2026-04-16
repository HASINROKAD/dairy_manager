const mongoose = require("mongoose");

const paymentWebhookEventSchema = new mongoose.Schema(
  {
    provider: {
      type: String,
      required: true,
      default: "razorpay",
      trim: true,
      index: true,
    },
    eventId: {
      type: String,
      required: true,
      trim: true,
      unique: true,
      index: true,
    },
    eventName: {
      type: String,
      required: false,
      default: null,
      trim: true,
    },
    payloadHash: {
      type: String,
      required: true,
      trim: true,
    },
    status: {
      type: String,
      required: true,
      enum: ["processing", "processed", "failed"],
      default: "processing",
      index: true,
    },
    processedAt: { type: Date, required: false, default: null },
    transactionId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "PaymentTransaction",
      required: false,
      default: null,
      index: true,
    },
    errorMessage: {
      type: String,
      required: false,
      default: null,
      trim: true,
    },
  },
  {
    timestamps: true,
    versionKey: false,
  },
);

const PaymentWebhookEventModel = mongoose.model(
  "PaymentWebhookEvent",
  paymentWebhookEventSchema,
);

module.exports = { PaymentWebhookEventModel };
