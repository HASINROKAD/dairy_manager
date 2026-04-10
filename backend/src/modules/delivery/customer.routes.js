const express = require("express");

const { authenticate } = require("../../middleware/authenticate");
const { attachUser } = require("../../middleware/attachUser");
const { checkRole } = require("../../middleware/checkRole");
const { getMyLedger } = require("./customer.controller");

const customerRouter = express.Router();

customerRouter.use(authenticate, attachUser, checkRole("customer"));
customerRouter.get("/my-ledger", getMyLedger);

module.exports = { customerRouter };
