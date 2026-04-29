const mongoose = require("mongoose");

const notificationTypeEnum = [
  "request_sent",
  "request_accepted",
  "request_rejected",
  "request_auto_cancelled",
  "organization_left",
];

const notificationSchema = new mongoose.Schema(
  {
    recipientUserId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      ref: "User",
      index: true,
    },
    actorUserId: {
      type: mongoose.Schema.Types.ObjectId,
      required: false,
      ref: "User",
      default: null,
    },
    type: {
      type: String,
      enum: notificationTypeEnum,
      required: true,
      index: true,
    },
    title: { type: String, required: true, trim: true },
    message: { type: String, required: true, trim: true },
    metadata: { type: mongoose.Schema.Types.Mixed, default: {} },
    isRead: { type: Boolean, default: false, index: true },
    readAt: { type: Date, default: null },
  },
  {
    timestamps: true,
    versionKey: false,
  },
);

notificationSchema.index({ recipientUserId: 1, createdAt: -1 });
notificationSchema.index({ recipientUserId: 1, isRead: 1, createdAt: -1 });

const NotificationModel = mongoose.model("Notification", notificationSchema);

module.exports = { NotificationModel, notificationTypeEnum };
