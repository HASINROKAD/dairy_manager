const express = require("express");

const { authenticate } = require("../../middleware/authenticate");
const { attachUser } = require("../../middleware/attachUser");
const {
  getMyNotifications,
  patchNotificationRead,
  patchAllNotificationsRead,
} = require("./notification.controller");

const notificationRouter = express.Router();

notificationRouter.use(authenticate, attachUser);
notificationRouter.get("/notifications", getMyNotifications);
notificationRouter.patch(
  "/notifications/:notificationId/read",
  patchNotificationRead,
);
notificationRouter.patch("/notifications/read-all", patchAllNotificationsRead);

module.exports = { notificationRouter };
