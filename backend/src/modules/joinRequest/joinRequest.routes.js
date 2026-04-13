const express = require("express");

const { authenticate } = require("../../middleware/authenticate");
const { attachUser } = require("../../middleware/attachUser");
const { requireRole } = require("../../middleware/requireRole");
const {
  postJoinRequest,
  getMyJoinRequests,
  getSellerJoinRequests,
  patchSellerJoinRequest,
  getSellerCustomers,
  getCustomerOrganization,
} = require("./joinRequest.controller");

const joinRequestRouter = express.Router();

joinRequestRouter.use(authenticate, attachUser);

joinRequestRouter.post(
  "/customer/join-requests",
  requireRole("customer"),
  postJoinRequest,
);
joinRequestRouter.get(
  "/customer/join-requests",
  requireRole("customer"),
  getMyJoinRequests,
);
joinRequestRouter.get(
  "/customer/organization",
  requireRole("customer"),
  getCustomerOrganization,
);

joinRequestRouter.get(
  "/seller/join-requests",
  requireRole("seller"),
  getSellerJoinRequests,
);
joinRequestRouter.get(
  "/seller/customers",
  requireRole("seller"),
  getSellerCustomers,
);
joinRequestRouter.patch(
  "/seller/join-requests/:requestId",
  requireRole("seller"),
  patchSellerJoinRequest,
);

module.exports = { joinRequestRouter };
