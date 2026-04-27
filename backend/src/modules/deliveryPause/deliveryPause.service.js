const mongoose = require("mongoose");

const { AppError } = require("../../common/errors/AppError");
const { CustomerProfileModel } = require("../customer/customerProfile.model");
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
    customerPhone:
      doc.customerUserId?.mobileNumber || doc.customerPhone || null,
    customerDisplayAddress: doc.customerDisplayAddress || null,
    customerDefaultQuantityLitres:
      Number(doc.customerDefaultQuantityLitres) > 0
        ? Number(doc.customerDefaultQuantityLitres)
        : null,
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

  const customerIds = docs
    .map((doc) => doc.customerUserId?._id || doc.customerUserId)
    .filter(Boolean);

  const profiles = customerIds.length
    ? await CustomerProfileModel.find({ userId: { $in: customerIds } })
        .select("userId defaultQuantityLitres displayAddress")
        .lean()
    : [];

  const profileByUserId = new Map(
    profiles.map((profile) => [String(profile.userId), profile]),
  );

  return docs.map((doc) => {
    const customerId = String(doc.customerUserId?._id || doc.customerUserId);
    const profile = profileByUserId.get(customerId);

    return toPauseDto({
      ...doc,
      customerDisplayAddress: profile?.displayAddress || null,
      customerDefaultQuantityLitres:
        Number(profile?.defaultQuantityLitres) > 0
          ? Number(profile.defaultQuantityLitres)
          : null,
    });
  });
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
  const sellerId = String(sellerUser?._id || "").trim();
  if (!sellerId) {
    throw new AppError(401, "UNAUTHORIZED", "Unauthorized seller user.");
  }

  throw new AppError(
    403,
    "SELLER_RESUME_NOT_ALLOWED",
    "Only customer can resume their delivery pause.",
  );
}

module.exports = {
  createPauseForCustomer,
  listCustomerPauses,
  listActivePausesForSeller,
  resumePauseForCustomer,
  resumePauseForSeller,
};
