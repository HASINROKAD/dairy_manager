const { asyncHandler } = require("../../common/utils/asyncHandler");
const {
  getDailySheetForSeller,
  bulkDeliverForSeller,
  adjustLogForSeller,
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

module.exports = { getDailySheet, bulkDeliver, adjustLog };
