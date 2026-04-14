const mongoose = require("mongoose");

const deliveryIssueTypeEnum = [
  "not_delivered",
  "late_delivery",
  "wrong_quantity",
];

const deliveryIssueStatusEnum = ["open", "resolved"];

const deliveryIssueSchema = new mongoose.Schema(
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
    issueType: {
      type: String,
      enum: deliveryIssueTypeEnum,
      required: true,
      index: true,
    },
    dateKey: {
      type: String,
      default: "",
      trim: true,
      index: true,
    },
    description: {
      type: String,
      default: "",
      trim: true,
    },
    status: {
      type: String,
      enum: deliveryIssueStatusEnum,
      default: "open",
      index: true,
    },
    resolvedByUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },
    resolvedAt: {
      type: Date,
      default: null,
    },
    resolutionNote: {
      type: String,
      default: "",
      trim: true,
    },
  },
  {
    timestamps: true,
    versionKey: false,
  },
);

deliveryIssueSchema.index({ sellerUserId: 1, status: 1, createdAt: -1 });
deliveryIssueSchema.index({ customerUserId: 1, createdAt: -1 });

const DeliveryIssueModel = mongoose.model("DeliveryIssue", deliveryIssueSchema);

module.exports = {
  DeliveryIssueModel,
  deliveryIssueTypeEnum,
  deliveryIssueStatusEnum,
};
