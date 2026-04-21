const { asyncHandler } = require("../../common/utils/asyncHandler");
const {
  getLedgerForCustomer,
  getMonthlySummaryForCustomer,
  openDisputeForCustomer,
  listDisputesForCustomer,
  listCorrectionRequestsForCustomer,
  reviewCorrectionRequestByCustomer,
  listAuditEntriesForCustomer,
} = require("./delivery.service");

const getMyLedger = asyncHandler(async (req, res) => {
  const result = await getLedgerForCustomer(req.auth.firebaseUid);

  res.status(200).json({
    success: true,
    data: result,
  });
});

const getMyMonthlySummary = asyncHandler(async (req, res) => {
  const result = await getMonthlySummaryForCustomer(
    req.auth.firebaseUid,
    req.query.month,
  );

  res.status(200).json({
    success: true,
    data: result,
  });
});

const postMyLedgerDispute = asyncHandler(async (req, res) => {
  const result = await openDisputeForCustomer({
    customerFirebaseUid: req.auth.firebaseUid,
    logId: req.body.logId,
    disputeType: req.body.disputeType,
    message: req.body.message,
  });

  res.status(201).json({
    success: true,
    data: result,
  });
});

const getMyLedgerDisputes = asyncHandler(async (req, res) => {
  const result = await listDisputesForCustomer({
    customerFirebaseUid: req.auth.firebaseUid,
    status: req.query.status,
    page: req.query.page,
    limit: req.query.limit,
  });

  res.status(200).json({
    success: true,
    data: result,
  });
});

const getMyCorrectionRequests = asyncHandler(async (req, res) => {
  const result = await listCorrectionRequestsForCustomer(
    req.auth.firebaseUid,
    req.query.status,
  );

  res.status(200).json({
    success: true,
    data: result,
  });
});

const postApproveMyCorrectionRequest = asyncHandler(async (req, res) => {
  const result = await reviewCorrectionRequestByCustomer({
    customerFirebaseUid: req.auth.firebaseUid,
    requestId: req.params.requestId,
    approve: true,
    reviewNote: req.body.reviewNote,
  });

  res.status(200).json({
    success: true,
    data: result,
  });
});

const postRejectMyCorrectionRequest = asyncHandler(async (req, res) => {
  const result = await reviewCorrectionRequestByCustomer({
    customerFirebaseUid: req.auth.firebaseUid,
    requestId: req.params.requestId,
    approve: false,
    reviewNote: req.body.reviewNote,
  });

  res.status(200).json({
    success: true,
    data: result,
  });
});

const getMyLedgerAudit = asyncHandler(async (req, res) => {
  const result = await listAuditEntriesForCustomer({
    customerFirebaseUid: req.auth.firebaseUid,
    logId: req.query.logId,
    page: req.query.page,
    limit: req.query.limit,
  });

  res.status(200).json({
    success: true,
    data: result,
  });
});

module.exports = {
  getMyLedger,
  getMyMonthlySummary,
  postMyLedgerDispute,
  getMyLedgerDisputes,
  getMyCorrectionRequests,
  postApproveMyCorrectionRequest,
  postRejectMyCorrectionRequest,
  getMyLedgerAudit,
};
