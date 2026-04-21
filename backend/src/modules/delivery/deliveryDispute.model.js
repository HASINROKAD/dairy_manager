const mongoose = require("mongoose");

const deliveryDisputeStatusEnum = ["open", "resolved", "rejected"];
const deliveryDisputeTypeEnum = [
  "wrong_quantity",
  "wrong_slot",
  "not_delivered",
  "other",
];

const deliveryDisputeSchema = new mongoose.Schema(
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
    disputeType: {
      type: String,
      enum: deliveryDisputeTypeEnum,
      default: "other",
    },
    message: {
      type: String,
      required: true,
      trim: true,
      maxlength: 500,
    },
    status: {
      type: String,
      enum: deliveryDisputeStatusEnum,
      default: "open",
      index: true,
    },
    resolvedByFirebaseUid: {
      type: String,
      default: null,
      trim: true,
    },
    resolutionNote: {
      type: String,
      default: null,
      trim: true,
      maxlength: 500,
    },
    resolvedAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
    versionKey: false,
  },
);

deliveryDisputeSchema.index({ deliveryLogId: 1, status: 1 });
deliveryDisputeSchema.index({ customerFirebaseUid: 1, createdAt: -1 });
deliveryDisputeSchema.index({ sellerFirebaseUid: 1, status: 1, createdAt: -1 });

const DeliveryDisputeModel = mongoose.model(
  "DeliveryDispute",
  deliveryDisputeSchema,
);

module.exports = {
  DeliveryDisputeModel,
  deliveryDisputeStatusEnum,
  deliveryDisputeTypeEnum,
};
