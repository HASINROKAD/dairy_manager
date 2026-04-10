const express = require("express");
const { authenticate } = require("../../middleware/authenticate");
const { attachUser } = require("../../middleware/attachUser");
const { requireRole } = require("../../middleware/requireRole");
const { getNearbySellers } = require("./discovery.controller");

const discoveryRouter = express.Router();

discoveryRouter.use(authenticate, attachUser);
discoveryRouter.get(
  "/sellers/nearby",
  requireRole("customer"),
  getNearbySellers,
);

module.exports = { discoveryRouter };
