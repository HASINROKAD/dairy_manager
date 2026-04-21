const mongoose = require("mongoose");

const { AppError } = require("../../common/errors/AppError");
const {
  parsePaginationParams,
  buildPaginationMeta,
} = require("../../common/utils/pagination");
const { NotificationModel } = require("./notification.model");

const UNREAD_COUNT_CACHE_TTL_MS = 15000;
const unreadCountCacheByUserId = new Map();

function normalizeCacheUserId(userId) {
  return String(userId || "").trim();
}

function getCachedUnreadCount(userId) {
  const key = normalizeCacheUserId(userId);
  if (!key) {
    return null;
  }

  const cached = unreadCountCacheByUserId.get(key);
  if (!cached) {
    return null;
  }

  if (cached.expiresAt <= Date.now()) {
    unreadCountCacheByUserId.delete(key);
    return null;
  }

  return cached.value;
}

function setCachedUnreadCount(userId, count) {
  const key = normalizeCacheUserId(userId);
  if (!key) {
    return;
  }

  unreadCountCacheByUserId.set(key, {
    value: Math.max(0, Number(count) || 0),
    expiresAt: Date.now() + UNREAD_COUNT_CACHE_TTL_MS,
  });
}

function invalidateUnreadCountCache(userId) {
  const key = normalizeCacheUserId(userId);
  if (!key) {
    return;
  }

  unreadCountCacheByUserId.delete(key);
}

function invalidateUnreadCountCacheForUsers(userIds) {
  for (const userId of userIds || []) {
    invalidateUnreadCountCache(userId);
  }
}

async function getUnreadCountForUser(userId) {
  const cached = getCachedUnreadCount(userId);
  if (cached !== null) {
    return cached;
  }

  const count = await NotificationModel.countDocuments({
    recipientUserId: userId,
    isRead: false,
  });

  setCachedUnreadCount(userId, count);
  return count;
}

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
    invalidateUnreadCountCache(recipientUserId);
    return docs[0];
  }

  const created = await NotificationModel.create(payload);
  invalidateUnreadCountCache(recipientUserId);
  return created;
}

async function listNotificationsForUser({
  userId,
  unreadOnly = false,
  page,
  limit = 50,
}) {
  const pagination = parsePaginationParams({
    page,
    limit,
    defaultLimit: 50,
    maxLimit: 100,
  });

  const query = {
    recipientUserId: userId,
    ...(unreadOnly ? { isRead: false } : {}),
  };

  const unreadCountPromise = getUnreadCountForUser(userId);
  const totalCountPromise = unreadOnly
    ? unreadCountPromise
    : NotificationModel.countDocuments(query);

  const [notifications, totalCount, unreadCount] = await Promise.all([
    NotificationModel.find(query)
      .select("_id type title message metadata isRead readAt createdAt")
      .sort({ createdAt: -1 })
      .skip(pagination.skip)
      .limit(pagination.limit)
      .lean(),
    totalCountPromise,
    unreadCountPromise,
  ]);

  return {
    items: notifications.map(toNotificationDto),
    unreadCount,
    count: notifications.length,
    pagination: buildPaginationMeta({
      page: pagination.page,
      limit: pagination.limit,
      totalItems: totalCount,
      returnedItems: notifications.length,
    }),
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
  )
    .select("_id type title message metadata isRead readAt createdAt")
    .lean();

  if (!updated) {
    throw new AppError(
      404,
      "NOTIFICATION_NOT_FOUND",
      "Notification not found.",
    );
  }

  invalidateUnreadCountCache(userId);

  return toNotificationDto(updated);
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

  invalidateUnreadCountCache(userId);

  return { updatedCount: result.modifiedCount || 0 };
}

async function deleteJoinRequestSentNotificationsForSellers({
  customerUserId,
  sellerUserIds,
  session = null,
}) {
  const normalizedSellerIds = Array.isArray(sellerUserIds)
    ? sellerUserIds.filter(Boolean)
    : [];

  if (!customerUserId || normalizedSellerIds.length === 0) {
    return { deletedCount: 0 };
  }

  const query = {
    recipientUserId: { $in: normalizedSellerIds },
    type: "request_sent",
    "metadata.customerUserId": customerUserId,
  };

  const result = session
    ? await NotificationModel.deleteMany(query, { session })
    : await NotificationModel.deleteMany(query);

  if ((result.deletedCount || 0) > 0) {
    invalidateUnreadCountCacheForUsers(normalizedSellerIds);
  }

  return { deletedCount: result.deletedCount || 0 };
}

module.exports = {
  createNotification,
  listNotificationsForUser,
  markNotificationAsRead,
  markAllNotificationsAsRead,
  deleteJoinRequestSentNotificationsForSellers,
};
