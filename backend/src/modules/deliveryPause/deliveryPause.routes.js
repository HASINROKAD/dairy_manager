const express = require("express");

const { authenticate } = require("../../middleware/authenticate");
const { attachUser } = require("../../middleware/attachUser");
const { requireRole } = require("../../middleware/requireRole");
const {
  postCustomerDeliveryPause,
  getCustomerDeliveryPauses,
  patchCustomerResumeDeliveryPause,
  getSellerActiveDeliveryPauses,
  patchSellerResumeDeliveryPause,
} = require("./deliveryPause.controller");

const deliveryPauseRouter = express.Router();

deliveryPauseRouter.use(authenticate, attachUser);

deliveryPauseRouter.post(
  "/customer/delivery-pauses",
  requireRole("customer"),
  postCustomerDeliveryPause,
);
deliveryPauseRouter.get(
  "/customer/delivery-pauses",
  requireRole("customer"),
  getCustomerDeliveryPauses,
);
deliveryPauseRouter.patch(
  "/customer/delivery-pauses/:pauseId/resume",
  requireRole("customer"),
  patchCustomerResumeDeliveryPause,
);

deliveryPauseRouter.get(
  "/seller/delivery-pauses",
  requireRole("seller"),
  getSellerActiveDeliveryPauses,
);
deliveryPauseRouter.patch(
  "/seller/delivery-pauses/:pauseId/resume",
  requireRole("seller"),
  patchSellerResumeDeliveryPause,
);

module.exports = { deliveryPauseRouter };
