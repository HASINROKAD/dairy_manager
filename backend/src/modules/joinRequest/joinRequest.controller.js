const { asyncHandler } = require("../../common/utils/asyncHandler");
const {
  createJoinRequest,
  listCustomerJoinRequests,
  listSellerJoinRequests,
  reviewJoinRequest,
  listSellerCustomers,
  getCustomerOrganization: getCustomerOrganizationForCustomer,
  getLeaveCustomerOrganizationPreview:
    getLeaveCustomerOrganizationPreviewForCustomer,
  leaveCustomerOrganization,
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
  const { items, pagination } = await listSellerCustomers({
    sellerUserId: req.user._id,
    page: req.query.page,
    limit: req.query.limit,
  });

  res.status(200).json({
    success: true,
    data: items,
    pagination,
  });
});

const getCustomerOrganization = asyncHandler(async (req, res) => {
  const data = await getCustomerOrganizationForCustomer(req.user);

  res.status(200).json({
    success: true,
    data,
  });
});

const getLeaveCustomerOrganizationPreview = asyncHandler(async (req, res) => {
  const data = await getLeaveCustomerOrganizationPreviewForCustomer(req.user);

  res.status(200).json({
    success: true,
    data,
  });
});

const postLeaveCustomerOrganization = asyncHandler(async (req, res) => {
  const data = await leaveCustomerOrganization(req.user);

  res.status(200).json({
    success: true,
    data,
  });
});

module.exports = {
  postJoinRequest,
  getMyJoinRequests,
  getSellerJoinRequests,
  patchSellerJoinRequest,
  getSellerCustomers,
  getCustomerOrganization,
  getLeaveCustomerOrganizationPreview,
  postLeaveCustomerOrganization,
};
