const { asyncHandler } = require("../../common/utils/asyncHandler");
const {
  getLedgerForCustomer,
  getMonthlySummaryForCustomer,
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

module.exports = { getMyLedger, getMyMonthlySummary };
