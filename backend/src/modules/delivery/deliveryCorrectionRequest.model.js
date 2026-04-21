const mongoose = require("mongoose");

const deliveryCorrectionRequestStatusEnum = ["pending", "approved", "rejected"];

const deliveryCorrectionRequestSchema = new mongoose.Schema(
  {
    deliveryLogId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      ref: "DeliveryLog",
      index: true,
    },
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
    dateKey: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    requestedSlot: {
      type: String,
      enum: ["morning", "evening"],
      required: true,
    },
    requestedQuantityLitres: {
      type: Number,
      required: true,
      min: 0.001,
    },
    reason: {
      type: String,
      required: true,
      trim: true,
      maxlength: 500,
    },
    status: {
      type: String,
      enum: deliveryCorrectionRequestStatusEnum,
      default: "pending",
      index: true,
    },
    reviewedByFirebaseUid: {
      type: String,
      default: null,
      trim: true,
    },
    reviewNote: {
      type: String,
      default: null,
      trim: true,
      maxlength: 500,
    },
    reviewedAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
    versionKey: false,
  },
);

deliveryCorrectionRequestSchema.index({ deliveryLogId: 1, status: 1 });
deliveryCorrectionRequestSchema.index({
  customerFirebaseUid: 1,
  status: 1,
  createdAt: -1,
});
deliveryCorrectionRequestSchema.index({
  sellerFirebaseUid: 1,
  status: 1,
  createdAt: -1,
});

const DeliveryCorrectionRequestModel = mongoose.model(
  "DeliveryCorrectionRequest",
  deliveryCorrectionRequestSchema,
);

module.exports = {
  DeliveryCorrectionRequestModel,
  deliveryCorrectionRequestStatusEnum,
};
