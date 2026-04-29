const { asyncHandler } = require("../../common/utils/asyncHandler");
const {
  getDailySheetForSeller,
  deliverCustomerForSeller,
  bulkDeliverForSeller,
  adjustLogForSeller,
  getMilkSettingsForSeller,
  updateMilkBasePriceForSeller,
  updateCustomerDefaultQuantityForSeller,
  getMonthlySummaryForSeller,
  getLedgerLogsForSeller,
  listDisputesForSeller,
  resolveDisputeForSeller,
  requestPastLogCorrectionBySeller,
  listCorrectionRequestsForSeller,
  listAuditEntriesForSeller,
} = require("./delivery.service");

const getDailySheet = asyncHandler(async (req, res) => {
  const result = await getDailySheetForSeller(req.auth.firebaseUid);

  res.status(200).json({
    success: true,
    data: result,
  });
});

const bulkDeliver = asyncHandler(async (req, res) => {
  const result = await bulkDeliverForSeller({
    sellerFirebaseUid: req.auth.firebaseUid,
    customerIds: req.body.customerIds,
  });

  res.status(200).json({
    success: true,
    data: result,
  });
});

const deliverCustomer = asyncHandler(async (req, res) => {
  const result = await deliverCustomerForSeller({
    sellerFirebaseUid: req.auth.firebaseUid,
    customerId: req.body.customerId,
    quantityLitres: req.body.quantityLitres,
  });

  res.status(200).json({
    success: true,
    data: result,
  });
});

const adjustLog = asyncHandler(async (req, res) => {
  const result = await adjustLogForSeller({
    sellerFirebaseUid: req.auth.firebaseUid,
    logId: req.body.logId,
    quantityLitres: req.body.quantityLitres,
  });

  res.status(200).json({
    success: true,
    data: result,
  });
});

const getMonthlySummary = asyncHandler(async (req, res) => {
  const result = await getMonthlySummaryForSeller(
    req.auth.firebaseUid,
    req.query.month,
  );

  res.status(200).json({
    success: true,
    data: result,
  });
});

const getSellerLedgerLogs = asyncHandler(async (req, res) => {
  const result = await getLedgerLogsForSeller(
    req.auth.firebaseUid,
    req.query.month,
  );

  res.status(200).json({
    success: true,
    data: result,
  });
});

const getMilkSettings = asyncHandler(async (req, res) => {
  const result = await getMilkSettingsForSeller(req.auth.firebaseUid);

  res.status(200).json({
    success: true,
    data: result,
  });
});

const patchMilkBasePrice = asyncHandler(async (req, res) => {
  const result = await updateMilkBasePriceForSeller({
    sellerFirebaseUid: req.auth.firebaseUid,
    basePricePerLitreRupees: req.body.basePricePerLitreRupees,
  });

  res.status(200).json({
    success: true,
    data: result,
  });
});

const patchCustomerDefaultQuantity = asyncHandler(async (req, res) => {
  const result = await updateCustomerDefaultQuantityForSeller({
    sellerFirebaseUid: req.auth.firebaseUid,
    customerUserId: req.body.customerUserId,
    defaultQuantityLitres: req.body.defaultQuantityLitres,
  });

  res.status(200).json({
    success: true,
    data: result,
  });
});

const getSellerDeliveryDisputes = asyncHandler(async (req, res) => {
  const result = await listDisputesForSeller({
    sellerFirebaseUid: req.auth.firebaseUid,
    status: req.query.status,
    page: req.query.page,
    limit: req.query.limit,
  });

  res.status(200).json({
    success: true,
    data: result,
  });
});

const patchSellerResolveDeliveryDispute = asyncHandler(async (req, res) => {
  const result = await resolveDisputeForSeller({
    sellerFirebaseUid: req.auth.firebaseUid,
    disputeId: req.params.disputeId,
    status: req.body.status,
    resolutionNote: req.body.resolutionNote,
  });

  res.status(200).json({
    success: true,
    data: result,
  });
});

const postSellerCorrectionRequest = asyncHandler(async (req, res) => {
  const result = await requestPastLogCorrectionBySeller({
    sellerFirebaseUid: req.auth.firebaseUid,
    logId: req.body.logId,
    requestedSlot: req.body.requestedSlot,
    requestedQuantityLitres: req.body.requestedQuantityLitres,
    reason: req.body.reason,
  });

  res.status(201).json({
    success: true,
    data: result,
  });
});

const getSellerCorrectionRequests = asyncHandler(async (req, res) => {
  const result = await listCorrectionRequestsForSeller(
    req.auth.firebaseUid,
    req.query.status,
  );

  res.status(200).json({
    success: true,
    data: result,
  });
});

const getSellerDeliveryAudit = asyncHandler(async (req, res) => {
  const result = await listAuditEntriesForSeller({
    sellerFirebaseUid: req.auth.firebaseUid,
    logId: req.query.logId,
    customerFirebaseUid: req.query.customerFirebaseUid,
    page: req.query.page,
    limit: req.query.limit,
  });

  res.status(200).json({
    success: true,
    data: result,
  });
});

module.exports = {
  getDailySheet,
  deliverCustomer,
  bulkDeliver,
  adjustLog,
  getMonthlySummary,
  getMilkSettings,
  patchMilkBasePrice,
  patchCustomerDefaultQuantity,
  getSellerLedgerLogs,
  getSellerDeliveryDisputes,
  patchSellerResolveDeliveryDispute,
  postSellerCorrectionRequest,
  getSellerCorrectionRequests,
  getSellerDeliveryAudit,
};
