const { asyncHandler } = require("../../common/utils/asyncHandler");
const {
  createDeliveryIssue,
  listCustomerDeliveryIssues,
  listSellerDeliveryIssues,
  resolveDeliveryIssue,
} = require("./deliveryIssue.service");

const postCustomerDeliveryIssue = asyncHandler(async (req, res) => {
  const data = await createDeliveryIssue({
    customerUser: req.user,
    issueType: req.body.issueType,
    dateKey: req.body.dateKey,
    description: req.body.description,
  });

  res.status(201).json({
    success: true,
    data,
  });
});

const getCustomerDeliveryIssues = asyncHandler(async (req, res) => {
  const data = await listCustomerDeliveryIssues(req.user._id);

  res.status(200).json({
    success: true,
    data,
  });
});

const getSellerDeliveryIssues = asyncHandler(async (req, res) => {
  const data = await listSellerDeliveryIssues({
    sellerUserId: req.user._id,
    status: req.query.status,
  });

  res.status(200).json({
    success: true,
    data,
  });
});

const patchSellerResolveDeliveryIssue = asyncHandler(async (req, res) => {
  const data = await resolveDeliveryIssue({
    sellerUser: req.user,
    issueId: req.params.issueId,
    resolutionNote: req.body.resolutionNote,
  });

  res.status(200).json({
    success: true,
    data,
  });
});

module.exports = {
  postCustomerDeliveryIssue,
  getCustomerDeliveryIssues,
  getSellerDeliveryIssues,
  patchSellerResolveDeliveryIssue,
};
