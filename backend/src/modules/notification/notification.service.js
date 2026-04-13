const mongoose = require("mongoose");

const { AppError } = require("../../common/errors/AppError");
const { NotificationModel } = require("./notification.model");

function toNotificationDto(notification) {
  return {
    id: notification._id,
    type: notification.type,
    title: notification.title,
    message: notification.message,
    metadata: notification.metadata || {},
    isRead: notification.isRead,
    readAt: notification.readAt || null,
    createdAt: notification.createdAt,
  };
}

async function createNotification({
  recipientUserId,
  actorUserId = null,
  type,
  title,
  message,
  metadata = {},
  session = null,
}) {
  const payload = {
    recipientUserId,
    actorUserId,
    type,
    title,
    message,
    metadata,
  };

  if (session) {
    const docs = await NotificationModel.create([payload], { session });
    return docs[0];
  }

  return NotificationModel.create(payload);
}

async function listNotificationsForUser({
  userId,
  unreadOnly = false,
  limit = 50,
}) {
  const size = Math.min(Math.max(Number(limit) || 50, 1), 100);

  const query = {
    recipientUserId: userId,
    ...(unreadOnly ? { isRead: false } : {}),
  };

  const [notifications, unreadCount] = await Promise.all([
    NotificationModel.find(query).sort({ createdAt: -1 }).limit(size).lean(),
    NotificationModel.countDocuments({
      recipientUserId: userId,
      isRead: false,
    }),
  ]);

  return {
    items: notifications.map(toNotificationDto),
    unreadCount,
  };
}

async function markNotificationAsRead({ userId, notificationId }) {
  if (!mongoose.Types.ObjectId.isValid(notificationId)) {
    throw new AppError(400, "VALIDATION_ERROR", "Invalid notification id.");
  }

  const updated = await NotificationModel.findOneAndUpdate(
    {
      _id: notificationId,
      recipientUserId: userId,
    },
    {
      $set: {
        isRead: true,
        readAt: new Date(),
      },
    },
    { new: true },
  );

  if (!updated) {
    throw new AppError(
      404,
      "NOTIFICATION_NOT_FOUND",
      "Notification not found.",
    );
  }

  return toNotificationDto(updated.toObject());
}

async function markAllNotificationsAsRead({ userId }) {
  const now = new Date();
  const result = await NotificationModel.updateMany(
    {
      recipientUserId: userId,
      isRead: false,
    },
    {
      $set: {
        isRead: true,
        readAt: now,
      },
    },
  );

  return { updatedCount: result.modifiedCount || 0 };
}

module.exports = {
  createNotification,
  listNotificationsForUser,
  markNotificationAsRead,
  markAllNotificationsAsRead,
};
