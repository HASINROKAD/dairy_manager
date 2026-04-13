const mongoose = require("mongoose");

const joinRequestStatusEnum = ["pending", "accepted", "rejected", "cancelled"];

const joinRequestSchema = new mongoose.Schema(
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
    status: {
      type: String,
      enum: joinRequestStatusEnum,
      default: "pending",
      index: true,
    },
    respondedAt: { type: Date, default: null },
    respondedByUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },
    rejectionReason: { type: String, trim: true, default: "" },
  },
  {
    timestamps: true,
    versionKey: false,
  },
);

joinRequestSchema.index(
  { customerUserId: 1, sellerUserId: 1, status: 1 },
  { unique: true, partialFilterExpression: { status: "pending" } },
);

const JoinRequestModel = mongoose.model("JoinRequest", joinRequestSchema);

module.exports = { JoinRequestModel, joinRequestStatusEnum };
