const express = require("express");

const { authenticate } = require("../../middleware/authenticate");
const { attachUser } = require("../../middleware/attachUser");
const { checkRole } = require("../../middleware/checkRole");
const {
  getMyLedger,
  getMyMonthlySummary,
  postMyLedgerDispute,
  getMyLedgerDisputes,
  getMyCorrectionRequests,
  postApproveMyCorrectionRequest,
  postRejectMyCorrectionRequest,
  getMyLedgerAudit,
} = require("./customer.controller");

const customerRouter = express.Router();

customerRouter.use(authenticate, attachUser, checkRole("customer"));
customerRouter.get("/my-ledger", getMyLedger);
customerRouter.get("/my-ledger/summary", getMyMonthlySummary);
customerRouter.post("/my-ledger/disputes", postMyLedgerDispute);
customerRouter.get("/my-ledger/disputes", getMyLedgerDisputes);
customerRouter.get("/my-ledger/correction-requests", getMyCorrectionRequests);
customerRouter.post(
  "/my-ledger/correction-requests/:requestId/approve",
  postApproveMyCorrectionRequest,
);
customerRouter.post(
  "/my-ledger/correction-requests/:requestId/reject",
  postRejectMyCorrectionRequest,
);
customerRouter.get("/my-ledger/audit", getMyLedgerAudit);

module.exports = { customerRouter };
