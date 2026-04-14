const mongoose = require("mongoose");

const { AppError } = require("../../common/errors/AppError");
const { UserModel } = require("../user/user.model");
const { SellerProfileModel } = require("../seller/sellerProfile.model");
const { SellerCapacityModel } = require("../seller/sellerCapacity.model");
const { CustomerProfileModel } = require("../customer/customerProfile.model");
const { JoinRequestModel } = require("./joinRequest.model");
const { createNotification } = require("../notification/notification.service");

function toJoinRequestDto(doc) {
  return {
    id: doc._id,
    customerUserId: doc.customerUserId?._id || doc.customerUserId,
    customerName: doc.customerUserId?.name || null,
    sellerUserId: doc.sellerUserId?._id || doc.sellerUserId,
    sellerName: doc.sellerUserId?.name || null,
    status: doc.status,
    rejectionReason: doc.rejectionReason || null,
    respondedAt: doc.respondedAt || null,
    createdAt: doc.createdAt,
    updatedAt: doc.updatedAt,
  };
}

function toRadians(value) {
  return (value * Math.PI) / 180;
}

function getValidGeoPoint(geo) {
  const lng = Number(geo?.coordinates?.[0]);
  const lat = Number(geo?.coordinates?.[1]);

  if (!Number.isFinite(lng) || !Number.isFinite(lat)) {
    return null;
  }

  if (lng < -180 || lng > 180 || lat < -90 || lat > 90) {
    return null;
  }

  return { lat, lng };
}

function distanceKmBetweenPoints({ fromLat, fromLng, toLat, toLng }) {
  const earthRadiusKm = 6371;
  const dLat = toRadians(toLat - fromLat);
  const dLng = toRadians(toLng - fromLng);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(fromLat)) *
      Math.cos(toRadians(toLat)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return earthRadiusKm * c;
}

function parsePositiveFilter(value, fieldName) {
  if (value === undefined || value === null || String(value).trim() === "") {
    return null;
  }

  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      `${fieldName} must be a positive number.`,
    );
  }

  return parsed;
}

function asValidLimitNumber(value, { field, allowDecimal }) {
  if (value === null || value === undefined || value === "") {
    return null;
  }

  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      `${field} must be a positive number or null.`,
    );
  }

  if (!allowDecimal && !Number.isInteger(parsed)) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      `${field} must be an integer value.`,
    );
  }

  return parsed;
}

async function getSellerCapacityUsage({ sellerUserId, session = null }) {
  const customers = await UserModel.find({
    role: "customer",
    isActive: true,
    activeSellerUserId: sellerUserId,
  })
    .select("_id")
    .session(session)
    .lean();

  const customerIds = customers.map((item) => item._id);
  if (!customerIds.length) {
    return {
      activeCustomersCount: 0,
      estimatedLitresPerDay: 0,
    };
  }

  const profiles = await CustomerProfileModel.find({
    userId: { $in: customerIds },
  })
    .select("userId defaultQuantityLitres")
    .session(session)
    .lean();

  const profileByUserId = new Map(
    profiles.map((profile) => [String(profile.userId), profile]),
  );

  const estimatedLitresPerDay = customers.reduce((sum, customer) => {
    const qty = Number(
      profileByUserId.get(String(customer._id))?.defaultQuantityLitres,
    );
    const normalizedQty = Number.isFinite(qty) && qty > 0 ? qty : 1;
    return sum + normalizedQty;
  }, 0);

  return {
    activeCustomersCount: customers.length,
    estimatedLitresPerDay: Math.round(estimatedLitresPerDay * 1000) / 1000,
  };
}

function toSellerCapacityDto(doc, usage) {
  return {
    maxActiveCustomers: doc?.maxActiveCustomers ?? null,
    maxLitresPerDay: doc?.maxLitresPerDay ?? null,
    activeCustomersCount: usage.activeCustomersCount,
    estimatedLitresPerDay: usage.estimatedLitresPerDay,
  };
}

async function createJoinRequest({ customerUser, sellerUserId }) {
  if (!mongoose.Types.ObjectId.isValid(sellerUserId)) {
    throw new AppError(400, "VALIDATION_ERROR", "Invalid seller user id.");
  }

  if (String(customerUser._id) === String(sellerUserId)) {
    throw new AppError(400, "VALIDATION_ERROR", "Cannot request yourself.");
  }

  if (customerUser.activeSellerUserId) {
    throw new AppError(
      400,
      "ALREADY_LINKED",
      "You are already linked to a seller organization.",
    );
  }

  const seller = await UserModel.findOne({
    _id: sellerUserId,
    role: "seller",
    isActive: true,
    profileCompleted: true,
  }).select("_id name");

  if (!seller) {
    throw new AppError(404, "SELLER_NOT_FOUND", "Seller not found.");
  }

  const pendingByCustomer = await JoinRequestModel.findOne({
    customerUserId: customerUser._id,
    status: "pending",
  }).select("_id");

  if (pendingByCustomer) {
    throw new AppError(
      409,
      "PENDING_REQUEST_EXISTS",
      "You already have a pending join request.",
    );
  }

  const request = await JoinRequestModel.create({
    customerUserId: customerUser._id,
    sellerUserId: seller._id,
    status: "pending",
  });

  await createNotification({
    recipientUserId: seller._id,
    actorUserId: customerUser._id,
    type: "request_sent",
    title: "New customer join request",
    message: `${customerUser.name || "A customer"} requested to join your organization.`,
    metadata: {
      requestId: request._id,
      customerUserId: customerUser._id,
      sellerUserId: seller._id,
    },
  });

  const hydrated = await JoinRequestModel.findById(request._id)
    .populate("customerUserId", "name")
    .populate("sellerUserId", "name")
    .lean();

  return toJoinRequestDto(hydrated);
}

async function listCustomerJoinRequests(customerUserId) {
  const requests = await JoinRequestModel.find({ customerUserId })
    .sort({ createdAt: -1 })
    .populate("sellerUserId", "name")
    .lean();

  return requests.map(toJoinRequestDto);
}

async function listSellerJoinRequests({
  sellerUserId,
  status,
  sortBy,
  area,
  minQuantityLitres,
  maxDistanceKm,
}) {
  const query = {
    sellerUserId,
    ...(status ? { status } : {}),
  };

  const normalizedSortBy = String(sortBy || "newest")
    .trim()
    .toLowerCase();
  const allowedSortBy = new Set(["newest", "distance", "quantity"]);
  if (!allowedSortBy.has(normalizedSortBy)) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      "sortBy must be one of newest, distance, quantity.",
    );
  }

  const areaFilter = String(area || "")
    .trim()
    .toLowerCase();
  const minQuantity = parsePositiveFilter(
    minQuantityLitres,
    "minQuantityLitres",
  );
  const maxDistance = parsePositiveFilter(maxDistanceKm, "maxDistanceKm");

  const requests = await JoinRequestModel.find(query)
    .sort({ createdAt: -1 })
    .populate("customerUserId", "name mobileNumber")
    .lean();

  if (!requests.length) {
    return [];
  }

  const customerIds = requests
    .map((item) => item.customerUserId?._id)
    .filter(Boolean);

  const [customerProfiles, sellerProfile] = await Promise.all([
    CustomerProfileModel.find({ userId: { $in: customerIds } })
      .select(
        "userId defaultQuantityLitres displayAddress addressComponents geo",
      )
      .lean(),
    SellerProfileModel.findOne({ userId: sellerUserId }).select("geo").lean(),
  ]);

  const sellerPoint = getValidGeoPoint(sellerProfile?.geo);
  const profileByUserId = new Map(
    customerProfiles.map((profile) => [String(profile.userId), profile]),
  );

  const enriched = requests.map((request) => {
    const base = toJoinRequestDto(request);
    const profile = profileByUserId.get(String(base.customerUserId));

    const requestedQuantityLitres =
      Number(profile?.defaultQuantityLitres) > 0
        ? Number(profile.defaultQuantityLitres)
        : 1;

    const areaCity = profile?.addressComponents?.city || "";
    const areaState = profile?.addressComponents?.state || "";
    const customerArea = [areaCity, areaState].filter(Boolean).join(", ");

    const customerPoint = getValidGeoPoint(profile?.geo);
    const distanceKm =
      sellerPoint && customerPoint
        ? Number(
            distanceKmBetweenPoints({
              fromLat: sellerPoint.lat,
              fromLng: sellerPoint.lng,
              toLat: customerPoint.lat,
              toLng: customerPoint.lng,
            }).toFixed(2),
          )
        : null;

    return {
      ...base,
      requestedQuantityLitres,
      distanceKm,
      customerArea: customerArea || null,
      customerDisplayAddress: profile?.displayAddress || null,
    };
  });

  const filtered = enriched.filter((item) => {
    if (areaFilter) {
      const haystack = [
        item.customerArea || "",
        item.customerDisplayAddress || "",
      ]
        .join(" ")
        .toLowerCase();

      if (!haystack.includes(areaFilter)) {
        return false;
      }
    }

    if (
      minQuantity !== null &&
      Number(item.requestedQuantityLitres || 0) < minQuantity
    ) {
      return false;
    }

    if (maxDistance !== null) {
      if (item.distanceKm === null) {
        return false;
      }

      if (item.distanceKm > maxDistance) {
        return false;
      }
    }

    return true;
  });

  if (normalizedSortBy === "distance") {
    filtered.sort((a, b) => {
      if (a.distanceKm === null && b.distanceKm === null) {
        return b.createdAt.getTime() - a.createdAt.getTime();
      }

      if (a.distanceKm === null) {
        return 1;
      }

      if (b.distanceKm === null) {
        return -1;
      }

      return a.distanceKm - b.distanceKm;
    });
  } else if (normalizedSortBy === "quantity") {
    filtered.sort((a, b) => {
      const quantityDelta =
        Number(b.requestedQuantityLitres || 0) -
        Number(a.requestedQuantityLitres || 0);

      if (quantityDelta !== 0) {
        return quantityDelta;
      }

      return b.createdAt.getTime() - a.createdAt.getTime();
    });
  } else {
    filtered.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
  }

  return filtered;
}

async function getSellerCapacitySettings(sellerUserId) {
  const [doc, usage] = await Promise.all([
    SellerCapacityModel.findOne({ sellerUserId }).lean(),
    getSellerCapacityUsage({ sellerUserId }),
  ]);

  return toSellerCapacityDto(doc, usage);
}

async function upsertSellerCapacitySettings({
  sellerUserId,
  maxActiveCustomers,
  maxLitresPerDay,
}) {
  const sanitizedMaxActiveCustomers = asValidLimitNumber(maxActiveCustomers, {
    field: "maxActiveCustomers",
    allowDecimal: false,
  });
  const sanitizedMaxLitresPerDay = asValidLimitNumber(maxLitresPerDay, {
    field: "maxLitresPerDay",
    allowDecimal: true,
  });

  const doc = await SellerCapacityModel.findOneAndUpdate(
    { sellerUserId },
    {
      $set: {
        maxActiveCustomers: sanitizedMaxActiveCustomers,
        maxLitresPerDay: sanitizedMaxLitresPerDay,
      },
    },
    {
      upsert: true,
      new: true,
      setDefaultsOnInsert: true,
    },
  ).lean();

  const usage = await getSellerCapacityUsage({ sellerUserId });
  return toSellerCapacityDto(doc, usage);
}

async function reviewJoinRequest({
  sellerUser,
  requestId,
  action,
  rejectionReason,
}) {
  if (!mongoose.Types.ObjectId.isValid(requestId)) {
    throw new AppError(400, "VALIDATION_ERROR", "Invalid request id.");
  }

  const normalizedAction = String(action || "")
    .trim()
    .toLowerCase();
  if (!["accept", "reject"].includes(normalizedAction)) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      "action must be accept or reject.",
    );
  }

  const session = await mongoose.startSession();

  try {
    let output;

    await session.withTransaction(async () => {
      const request = await JoinRequestModel.findOne({
        _id: requestId,
        sellerUserId: sellerUser._id,
        status: "pending",
      }).session(session);

      if (!request) {
        throw new AppError(404, "REQUEST_NOT_FOUND", "Join request not found.");
      }

      const customer = await UserModel.findOne({
        _id: request.customerUserId,
        role: "customer",
        isActive: true,
      }).session(session);

      if (!customer) {
        throw new AppError(404, "CUSTOMER_NOT_FOUND", "Customer not found.");
      }

      if (normalizedAction === "accept") {
        if (
          customer.activeSellerUserId &&
          String(customer.activeSellerUserId) !== String(sellerUser._id)
        ) {
          throw new AppError(
            409,
            "CUSTOMER_ALREADY_LINKED",
            "Customer is already linked to another seller.",
          );
        }

        const capacity = await SellerCapacityModel.findOne({
          sellerUserId: sellerUser._id,
        })
          .session(session)
          .lean();

        if (capacity) {
          const [usage, incomingProfile] = await Promise.all([
            getSellerCapacityUsage({ sellerUserId: sellerUser._id, session }),
            CustomerProfileModel.findOne({ userId: customer._id })
              .select("defaultQuantityLitres")
              .session(session)
              .lean(),
          ]);

          if (
            capacity.maxActiveCustomers !== null &&
            usage.activeCustomersCount >= capacity.maxActiveCustomers
          ) {
            throw new AppError(
              409,
              "CAPACITY_LIMIT_REACHED",
              "Seller has reached maximum active customers limit.",
            );
          }

          const incomingQty = Number(incomingProfile?.defaultQuantityLitres);
          const incomingEstimatedLitres =
            Number.isFinite(incomingQty) && incomingQty > 0 ? incomingQty : 1;

          if (
            capacity.maxLitresPerDay !== null &&
            usage.estimatedLitresPerDay + incomingEstimatedLitres >
              capacity.maxLitresPerDay
          ) {
            throw new AppError(
              409,
              "DAILY_LITRES_LIMIT_REACHED",
              "Seller has reached maximum litres per day capacity.",
            );
          }
        }

        customer.activeSellerUserId = sellerUser._id;
        customer.activeSellerLinkedAt = new Date();
        await customer.save({ session });

        request.status = "accepted";
        request.rejectionReason = "";
        request.respondedAt = new Date();
        request.respondedByUserId = sellerUser._id;
        await request.save({ session });

        await JoinRequestModel.updateMany(
          {
            customerUserId: customer._id,
            status: "pending",
            _id: { $ne: request._id },
          },
          {
            $set: {
              status: "rejected",
              rejectionReason: "Another seller request already accepted.",
              respondedAt: new Date(),
              respondedByUserId: sellerUser._id,
            },
          },
          { session },
        );

        await createNotification({
          recipientUserId: customer._id,
          actorUserId: sellerUser._id,
          type: "request_accepted",
          title: "Join request accepted",
          message: `${sellerUser.name || "Seller"} accepted your join request.`,
          metadata: {
            requestId: request._id,
            customerUserId: customer._id,
            sellerUserId: sellerUser._id,
          },
          session,
        });
      } else {
        request.status = "rejected";
        request.rejectionReason = (rejectionReason || "").trim();
        request.respondedAt = new Date();
        request.respondedByUserId = sellerUser._id;
        await request.save({ session });

        await createNotification({
          recipientUserId: customer._id,
          actorUserId: sellerUser._id,
          type: "request_rejected",
          title: "Join request rejected",
          message: `${sellerUser.name || "Seller"} rejected your join request.${
            request.rejectionReason ? ` Reason: ${request.rejectionReason}` : ""
          }`,
          metadata: {
            requestId: request._id,
            customerUserId: customer._id,
            sellerUserId: sellerUser._id,
          },
          session,
        });
      }

      const hydrated = await JoinRequestModel.findById(request._id)
        .populate("customerUserId", "name")
        .populate("sellerUserId", "name")
        .session(session)
        .lean();

      output = toJoinRequestDto(hydrated);
    });

    return output;
  } finally {
    await session.endSession();
  }
}

async function listSellerCustomers(sellerUserId) {
  const customers = await UserModel.find({
    role: "customer",
    isActive: true,
    activeSellerUserId: sellerUserId,
  })
    .select("_id firebaseUid name mobileNumber email activeSellerLinkedAt")
    .sort({ activeSellerLinkedAt: -1, createdAt: -1 })
    .lean();

  return customers.map((customer) => ({
    customerUserId: customer._id,
    customerFirebaseUid: customer.firebaseUid,
    name: customer.name || null,
    phone: customer.mobileNumber || null,
    email: customer.email || null,
    linkedAt: customer.activeSellerLinkedAt || null,
  }));
}

async function getCustomerOrganization(customerUser) {
  if (!customerUser.activeSellerUserId) {
    return null;
  }

  const sellerUser = await UserModel.findOne({
    _id: customerUser.activeSellerUserId,
    role: "seller",
    isActive: true,
  })
    .select("_id firebaseUid name mobileNumber email")
    .lean();

  if (!sellerUser) {
    return null;
  }

  const sellerProfile = await SellerProfileModel.findOne({
    userId: sellerUser._id,
  })
    .select("shopName displayAddress")
    .lean();

  return {
    sellerUserId: sellerUser._id,
    sellerFirebaseUid: sellerUser.firebaseUid,
    sellerName: sellerUser.name || null,
    shopName: sellerProfile?.shopName || null,
    displayAddress: sellerProfile?.displayAddress || null,
    phone: sellerUser.mobileNumber || null,
    email: sellerUser.email || null,
    linkedAt: customerUser.activeSellerLinkedAt || null,
  };
}

module.exports = {
  createJoinRequest,
  listCustomerJoinRequests,
  listSellerJoinRequests,
  getSellerCapacitySettings,
  upsertSellerCapacitySettings,
  reviewJoinRequest,
  listSellerCustomers,
  getCustomerOrganization,
};
