const { asyncHandler } = require("../../common/utils/asyncHandler");
const { getLedgerForCustomer } = require("./delivery.service");

const getMyLedger = asyncHandler(async (req, res) => {
  const result = await getLedgerForCustomer(req.auth.firebaseUid);

  res.status(200).json({
    success: true,
    data: result,
  });
});

module.exports = { getMyLedger };
