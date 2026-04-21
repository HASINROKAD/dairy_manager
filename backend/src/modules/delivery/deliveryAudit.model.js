const mongoose = require("mongoose");

const deliveryAuditActionEnum = [
  "log_created",
  "log_slot_updated",
  "log_adjusted_same_day",
  "correction_requested",
  "correction_approved",
  "correction_rejected",
  "dispute_opened",
  "dispute_resolved",
  "dispute_rejected",
];

const deliveryAuditSchema = new mongoose.Schema(
  {
    deliveryLogId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "DeliveryLog",
      default: null,
      index: true,
    },
    customerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
      index: true,
    },
    customerFirebaseUid: {
      type: String,
      default: null,
      trim: true,
      index: true,
    },
    sellerFirebaseUid: {
      type: String,
      default: null,
      trim: true,
      index: true,
    },
    dateKey: {
      type: String,
      default: null,
      trim: true,
      index: true,
    },
    deliverySlot: {
      type: String,
      enum: ["morning", "evening"],
    },
    action: {
      type: String,
      enum: deliveryAuditActionEnum,
      required: true,
      index: true,
    },
    actorFirebaseUid: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    actorRole: {
      type: String,
      enum: ["seller", "customer", "system"],
      required: true,
    },
    reason: {
      type: String,
      default: null,
      trim: true,
      maxlength: 500,
    },
    before: {
      type: mongoose.Schema.Types.Mixed,
      default: null,
    },
    after: {
      type: mongoose.Schema.Types.Mixed,
      default: null,
    },
    metadata: {
      type: mongoose.Schema.Types.Mixed,
      default: null,
    },
  },
  {
    timestamps: true,
    versionKey: false,
  },
);

deliveryAuditSchema.index({ customerFirebaseUid: 1, createdAt: -1 });
deliveryAuditSchema.index({ sellerFirebaseUid: 1, createdAt: -1 });
deliveryAuditSchema.index({ action: 1, createdAt: -1 });

const DeliveryAuditModel = mongoose.model("DeliveryAudit", deliveryAuditSchema);

module.exports = {
  DeliveryAuditModel,
  deliveryAuditActionEnum,
};
