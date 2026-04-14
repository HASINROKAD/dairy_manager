const mongoose = require("mongoose");

const { AppError } = require("../../common/errors/AppError");
const { UserModel } = require("../user/user.model");
const {
  DeliveryIssueModel,
  deliveryIssueTypeEnum,
} = require("./deliveryIssue.model");

function toIssueDto(doc) {
  return {
    id: doc._id,
    customerUserId: doc.customerUserId?._id || doc.customerUserId,
    customerName: doc.customerUserId?.name || null,
    sellerUserId: doc.sellerUserId?._id || doc.sellerUserId,
    sellerName: doc.sellerUserId?.name || null,
    issueType: doc.issueType,
    dateKey: doc.dateKey || null,
    description: doc.description || null,
    status: doc.status,
    resolvedAt: doc.resolvedAt || null,
    resolutionNote: doc.resolutionNote || null,
    createdAt: doc.createdAt,
    updatedAt: doc.updatedAt,
  };
}

function normalizeIssueType(issueType) {
  const normalized = String(issueType || "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, "_");

  if (!deliveryIssueTypeEnum.includes(normalized)) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      `issueType must be one of: ${deliveryIssueTypeEnum.join(", ")}.`,
    );
  }

  return normalized;
}

async function createDeliveryIssue({
  customerUser,
  issueType,
  dateKey,
  description,
}) {
  if (!customerUser.activeSellerUserId) {
    throw new AppError(
      400,
      "NO_ACTIVE_SELLER",
      "You are not linked to a seller. Join a seller before reporting issues.",
    );
  }

  const issue = await DeliveryIssueModel.create({
    customerUserId: customerUser._id,
    sellerUserId: customerUser.activeSellerUserId,
    issueType: normalizeIssueType(issueType),
    dateKey: String(dateKey || "").trim(),
    description: String(description || "").trim(),
    status: "open",
  });

  const hydrated = await DeliveryIssueModel.findById(issue._id)
    .populate("customerUserId", "name")
    .populate("sellerUserId", "name")
    .lean();

  return toIssueDto(hydrated);
}

async function listCustomerDeliveryIssues(customerUserId) {
  const issues = await DeliveryIssueModel.find({ customerUserId })
    .sort({ createdAt: -1 })
    .populate("sellerUserId", "name")
    .lean();

  return issues.map(toIssueDto);
}

async function listSellerDeliveryIssues({ sellerUserId, status }) {
  const query = {
    sellerUserId,
    ...(status ? { status } : {}),
  };

  const issues = await DeliveryIssueModel.find(query)
    .sort({ createdAt: -1 })
    .populate("customerUserId", "name mobileNumber")
    .lean();

  return issues.map(toIssueDto);
}

async function resolveDeliveryIssue({ sellerUser, issueId, resolutionNote }) {
  if (!mongoose.Types.ObjectId.isValid(issueId)) {
    throw new AppError(400, "VALIDATION_ERROR", "Invalid issue id.");
  }

  const issue = await DeliveryIssueModel.findOne({
    _id: issueId,
    sellerUserId: sellerUser._id,
  });

  if (!issue) {
    throw new AppError(404, "ISSUE_NOT_FOUND", "Delivery issue not found.");
  }

  if (issue.status === "resolved") {
    throw new AppError(
      409,
      "ISSUE_ALREADY_RESOLVED",
      "Issue is already resolved.",
    );
  }

  const customer = await UserModel.findOne({
    _id: issue.customerUserId,
    role: "customer",
    isActive: true,
  }).select("_id");

  if (!customer) {
    throw new AppError(404, "CUSTOMER_NOT_FOUND", "Customer not found.");
  }

  issue.status = "resolved";
  issue.resolvedAt = new Date();
  issue.resolvedByUserId = sellerUser._id;
  issue.resolutionNote = String(resolutionNote || "").trim();
  await issue.save();

  const hydrated = await DeliveryIssueModel.findById(issue._id)
    .populate("customerUserId", "name")
    .populate("sellerUserId", "name")
    .lean();

  return toIssueDto(hydrated);
}

module.exports = {
  createDeliveryIssue,
  listCustomerDeliveryIssues,
  listSellerDeliveryIssues,
  resolveDeliveryIssue,
};
