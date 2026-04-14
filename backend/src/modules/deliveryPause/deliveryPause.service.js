const mongoose = require("mongoose");

const { AppError } = require("../../common/errors/AppError");
const { UserModel } = require("../user/user.model");
const { DeliveryPauseModel } = require("./deliveryPause.model");

function normalizeDateKey(value, fieldName) {
  const dateKey = String(value || "").trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dateKey)) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      `${fieldName} must be in YYYY-MM-DD format.`,
    );
  }

  return dateKey;
}

function toPauseDto(doc) {
  return {
    id: doc._id,
    customerUserId: doc.customerUserId?._id || doc.customerUserId,
    customerName: doc.customerUserId?.name || null,
    sellerUserId: doc.sellerUserId?._id || doc.sellerUserId,
    sellerName: doc.sellerUserId?.name || null,
    startDateKey: doc.startDateKey,
    endDateKey: doc.endDateKey,
    status: doc.status,
    resumedAt: doc.resumedAt || null,
    createdAt: doc.createdAt,
    updatedAt: doc.updatedAt,
  };
}

async function createPauseForCustomer({
  customerUser,
  startDateKey,
  endDateKey,
}) {
  if (!customerUser.activeSellerUserId) {
    throw new AppError(
      400,
      "NO_ACTIVE_SELLER",
      "You are not linked to a seller organization.",
    );
  }

  const start = normalizeDateKey(startDateKey, "startDateKey");
  const end = normalizeDateKey(endDateKey, "endDateKey");

  if (end < start) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      "endDateKey must be greater than or equal to startDateKey.",
    );
  }

  const doc = await DeliveryPauseModel.create({
    customerUserId: customerUser._id,
    sellerUserId: customerUser.activeSellerUserId,
    startDateKey: start,
    endDateKey: end,
    status: "active",
  });

  const hydrated = await DeliveryPauseModel.findById(doc._id)
    .populate("sellerUserId", "name")
    .lean();

  return toPauseDto(hydrated);
}

async function listCustomerPauses(customerUserId) {
  const docs = await DeliveryPauseModel.find({ customerUserId })
    .sort({ createdAt: -1 })
    .populate("sellerUserId", "name")
    .lean();

  return docs.map(toPauseDto);
}

async function listActivePausesForSeller(sellerUserId) {
  const docs = await DeliveryPauseModel.find({
    sellerUserId,
    status: "active",
  })
    .sort({ startDateKey: 1, createdAt: -1 })
    .populate("customerUserId", "name mobileNumber")
    .lean();

  return docs.map(toPauseDto);
}

async function resumePauseForCustomer({ customerUser, pauseId }) {
  if (!mongoose.Types.ObjectId.isValid(pauseId)) {
    throw new AppError(400, "VALIDATION_ERROR", "Invalid pause id.");
  }

  const pause = await DeliveryPauseModel.findOne({
    _id: pauseId,
    customerUserId: customerUser._id,
  });

  if (!pause) {
    throw new AppError(404, "PAUSE_NOT_FOUND", "Delivery pause not found.");
  }

  if (pause.status === "resumed") {
    throw new AppError(
      409,
      "PAUSE_ALREADY_RESUMED",
      "Pause is already resumed.",
    );
  }

  pause.status = "resumed";
  pause.resumedAt = new Date();
  await pause.save();

  const hydrated = await DeliveryPauseModel.findById(pause._id)
    .populate("sellerUserId", "name")
    .lean();

  return toPauseDto(hydrated);
}

async function resumePauseForSeller({ sellerUser, pauseId }) {
  if (!mongoose.Types.ObjectId.isValid(pauseId)) {
    throw new AppError(400, "VALIDATION_ERROR", "Invalid pause id.");
  }

  const pause = await DeliveryPauseModel.findOne({
    _id: pauseId,
    sellerUserId: sellerUser._id,
  });

  if (!pause) {
    throw new AppError(404, "PAUSE_NOT_FOUND", "Delivery pause not found.");
  }

  const customer = await UserModel.findOne({
    _id: pause.customerUserId,
    role: "customer",
    isActive: true,
  }).select("_id");

  if (!customer) {
    throw new AppError(404, "CUSTOMER_NOT_FOUND", "Customer not found.");
  }

  if (pause.status === "resumed") {
    throw new AppError(
      409,
      "PAUSE_ALREADY_RESUMED",
      "Pause is already resumed.",
    );
  }

  pause.status = "resumed";
  pause.resumedAt = new Date();
  await pause.save();

  const hydrated = await DeliveryPauseModel.findById(pause._id)
    .populate("customerUserId", "name")
    .lean();

  return toPauseDto(hydrated);
}

module.exports = {
  createPauseForCustomer,
  listCustomerPauses,
  listActivePausesForSeller,
  resumePauseForCustomer,
  resumePauseForSeller,
};
