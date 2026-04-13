const { asyncHandler } = require("../../common/utils/asyncHandler");
const {
  listNotificationsForUser,
  markNotificationAsRead,
  markAllNotificationsAsRead,
} = require("./notification.service");

const getMyNotifications = asyncHandler(async (req, res) => {
  const data = await listNotificationsForUser({
    userId: req.user._id,
    unreadOnly: String(req.query.unreadOnly || "false") === "true",
    limit: req.query.limit,
  });

  res.status(200).json({
    success: true,
    data,
  });
});

const patchNotificationRead = asyncHandler(async (req, res) => {
  const data = await markNotificationAsRead({
    userId: req.user._id,
    notificationId: req.params.notificationId,
  });

  res.status(200).json({
    success: true,
    data,
  });
});

const patchAllNotificationsRead = asyncHandler(async (req, res) => {
  const data = await markAllNotificationsAsRead({ userId: req.user._id });

  res.status(200).json({
    success: true,
    data,
  });
});

module.exports = {
  getMyNotifications,
  patchNotificationRead,
  patchAllNotificationsRead,
};
