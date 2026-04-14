const express = require("express");

const { authenticate } = require("../../middleware/authenticate");
const { attachUser } = require("../../middleware/attachUser");
const { requireRole } = require("../../middleware/requireRole");
const {
  postCustomerDeliveryIssue,
  getCustomerDeliveryIssues,
  getSellerDeliveryIssues,
  patchSellerResolveDeliveryIssue,
} = require("./deliveryIssue.controller");

const deliveryIssueRouter = express.Router();

deliveryIssueRouter.use(authenticate, attachUser);

deliveryIssueRouter.post(
  "/customer/delivery-issues",
  requireRole("customer"),
  postCustomerDeliveryIssue,
);
deliveryIssueRouter.get(
  "/customer/delivery-issues",
  requireRole("customer"),
  getCustomerDeliveryIssues,
);

deliveryIssueRouter.get(
  "/seller/delivery-issues",
  requireRole("seller"),
  getSellerDeliveryIssues,
);
deliveryIssueRouter.patch(
  "/seller/delivery-issues/:issueId/resolve",
  requireRole("seller"),
  patchSellerResolveDeliveryIssue,
);

module.exports = { deliveryIssueRouter };
