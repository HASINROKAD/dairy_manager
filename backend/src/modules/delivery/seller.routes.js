const express = require("express");

const { authenticate } = require("../../middleware/authenticate");
const { attachUser } = require("../../middleware/attachUser");
const { checkRole } = require("../../middleware/checkRole");
const {
  getDailySheet,
  bulkDeliver,
  adjustLog,
} = require("./seller.controller");

const sellerRouter = express.Router();

sellerRouter.use(authenticate, attachUser, checkRole("seller"));
sellerRouter.get("/daily-sheet", getDailySheet);
sellerRouter.post("/bulk-deliver", bulkDeliver);
sellerRouter.patch("/adjust-log", adjustLog);

module.exports = { sellerRouter };
