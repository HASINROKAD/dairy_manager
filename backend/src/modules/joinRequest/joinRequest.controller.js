const { asyncHandler } = require("../../common/utils/asyncHandler");
const {
  createJoinRequest,
  listCustomerJoinRequests,
  listSellerJoinRequests,
  getSellerCapacitySettings,
  upsertSellerCapacitySettings,
  reviewJoinRequest,
  listSellerCustomers,
  getCustomerOrganization: getCustomerOrganizationForCustomer,
} = require("./joinRequest.service");

const postJoinRequest = asyncHandler(async (req, res) => {
  const data = await createJoinRequest({
    customerUser: req.user,
    sellerUserId: req.body.sellerUserId,
  });

  res.status(201).json({
    success: true,
    data,
  });
});

const getMyJoinRequests = asyncHandler(async (req, res) => {
  const data = await listCustomerJoinRequests(req.user._id);

  res.status(200).json({
    success: true,
    data,
  });
});

const getSellerJoinRequests = asyncHandler(async (req, res) => {
  const data = await listSellerJoinRequests({
    sellerUserId: req.user._id,
    status: req.query.status,
    sortBy: req.query.sortBy,
    area: req.query.area,
    minQuantityLitres: req.query.minQuantityLitres,
    maxDistanceKm: req.query.maxDistanceKm,
  });

  res.status(200).json({
    success: true,
    data,
  });
});

const getSellerCapacity = asyncHandler(async (req, res) => {
  const data = await getSellerCapacitySettings(req.user._id);

  res.status(200).json({
    success: true,
    data,
  });
});

const patchSellerCapacity = asyncHandler(async (req, res) => {
  const data = await upsertSellerCapacitySettings({
    sellerUserId: req.user._id,
    maxActiveCustomers: req.body.maxActiveCustomers,
    maxLitresPerDay: req.body.maxLitresPerDay,
  });

  res.status(200).json({
    success: true,
    data,
  });
});

const patchSellerJoinRequest = asyncHandler(async (req, res) => {
  const data = await reviewJoinRequest({
    sellerUser: req.user,
    requestId: req.params.requestId,
    action: req.body.action,
    rejectionReason: req.body.rejectionReason,
  });

  res.status(200).json({
    success: true,
    data,
  });
});

const getSellerCustomers = asyncHandler(async (req, res) => {
  const data = await listSellerCustomers(req.user._id);

  res.status(200).json({
    success: true,
    data,
  });
});

const getCustomerOrganization = asyncHandler(async (req, res) => {
  const data = await getCustomerOrganizationForCustomer(req.user);

  res.status(200).json({
    success: true,
    data,
  });
});

module.exports = {
  postJoinRequest,
  getMyJoinRequests,
  getSellerJoinRequests,
  getSellerCapacity,
  patchSellerCapacity,
  patchSellerJoinRequest,
  getSellerCustomers,
  getCustomerOrganization,
};
