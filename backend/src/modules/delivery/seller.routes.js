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
  getMilkSettings,
  patchMilkBasePrice,
  patchCustomerDefaultQuantity,
} = require("./seller.controller");

const sellerRouter = express.Router();

sellerRouter.use(authenticate, attachUser, checkRole("seller"));
sellerRouter.get("/daily-sheet", getDailySheet);
sellerRouter.get("/monthly-summary", getMonthlySummary);
sellerRouter.get("/settings/milk", getMilkSettings);
sellerRouter.patch("/settings/milk/price", patchMilkBasePrice);
sellerRouter.patch(
  "/settings/milk/customer-default-quantity",
  patchCustomerDefaultQuantity,
);
sellerRouter.post("/deliver-customer", deliverCustomer);
sellerRouter.post("/bulk-deliver", bulkDeliver);
sellerRouter.patch("/adjust-log", adjustLog);

module.exports = { sellerRouter };
