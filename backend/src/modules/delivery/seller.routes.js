const express = require("express");

const { authenticate } = require("../../middleware/authenticate");
const { attachUser } = require("../../middleware/attachUser");
const { checkRole } = require("../../middleware/checkRole");
const {
  getDailySheet,
  deliverCustomer,
  bulkDeliver,
  adjustLog,
  getMonthlySummary,
  getSellerLedgerLogs,
  getMilkSettings,
  patchMilkBasePrice,
  patchCustomerDefaultQuantity,
  getSellerDeliveryDisputes,
  patchSellerResolveDeliveryDispute,
  postSellerCorrectionRequest,
  getSellerCorrectionRequests,
  getSellerDeliveryAudit,
} = require("./seller.controller");

const sellerRouter = express.Router();

sellerRouter.use(authenticate, attachUser, checkRole("seller"));
sellerRouter.get("/daily-sheet", getDailySheet);
sellerRouter.get("/monthly-summary", getMonthlySummary);
sellerRouter.get("/ledger-logs", getSellerLedgerLogs);
sellerRouter.get("/settings/milk", getMilkSettings);
sellerRouter.patch("/settings/milk/price", patchMilkBasePrice);
sellerRouter.patch(
  "/settings/milk/customer-default-quantity",
  patchCustomerDefaultQuantity,
);
sellerRouter.post("/deliver-customer", deliverCustomer);
sellerRouter.post("/bulk-deliver", bulkDeliver);
sellerRouter.patch("/adjust-log", adjustLog);
sellerRouter.get("/delivery-disputes", getSellerDeliveryDisputes);
sellerRouter.patch(
  "/delivery-disputes/:disputeId/resolve",
  patchSellerResolveDeliveryDispute,
);
sellerRouter.post("/correction-requests", postSellerCorrectionRequest);
sellerRouter.get("/correction-requests", getSellerCorrectionRequests);
sellerRouter.get("/delivery-audit", getSellerDeliveryAudit);

module.exports = { sellerRouter };
