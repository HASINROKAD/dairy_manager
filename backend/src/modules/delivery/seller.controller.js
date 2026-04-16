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

module.exports = {
  getDailySheet,
  deliverCustomer,
  bulkDeliver,
  adjustLog,
  getMonthlySummary,
  getMilkSettings,
  patchMilkBasePrice,
  patchCustomerDefaultQuantity,
};
