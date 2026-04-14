const { asyncHandler } = require("../../common/utils/asyncHandler");
const {
  createPauseForCustomer,
  listCustomerPauses,
  listActivePausesForSeller,
  resumePauseForCustomer,
  resumePauseForSeller,
} = require("./deliveryPause.service");

const postCustomerDeliveryPause = asyncHandler(async (req, res) => {
  const data = await createPauseForCustomer({
    customerUser: req.user,
    startDateKey: req.body.startDateKey,
    endDateKey: req.body.endDateKey,
  });

  res.status(201).json({ success: true, data });
});

const getCustomerDeliveryPauses = asyncHandler(async (req, res) => {
  const data = await listCustomerPauses(req.user._id);
  res.status(200).json({ success: true, data });
});

const patchCustomerResumeDeliveryPause = asyncHandler(async (req, res) => {
  const data = await resumePauseForCustomer({
    customerUser: req.user,
    pauseId: req.params.pauseId,
  });

  res.status(200).json({ success: true, data });
});

const getSellerActiveDeliveryPauses = asyncHandler(async (req, res) => {
  const data = await listActivePausesForSeller(req.user._id);
  res.status(200).json({ success: true, data });
});

const patchSellerResumeDeliveryPause = asyncHandler(async (req, res) => {
  const data = await resumePauseForSeller({
    sellerUser: req.user,
    pauseId: req.params.pauseId,
  });

  res.status(200).json({ success: true, data });
});

module.exports = {
  postCustomerDeliveryPause,
  getCustomerDeliveryPauses,
  patchCustomerResumeDeliveryPause,
  getSellerActiveDeliveryPauses,
  patchSellerResumeDeliveryPause,
};
