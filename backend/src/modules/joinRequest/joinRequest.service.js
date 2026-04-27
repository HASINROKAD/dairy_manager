const mongoose = require("mongoose");

const { AppError } = require("../../common/errors/AppError");
const { UserModel } = require("../user/user.model");
const { SellerProfileModel } = require("../seller/sellerProfile.model");
const { CustomerProfileModel } = require("../customer/customerProfile.model");
const { DeliveryPauseModel } = require("../deliveryPause/deliveryPause.model");
const { JoinRequestModel } = require("./joinRequest.model");
const {
  createNotification,
  deleteJoinRequestSentNotificationsForSellers,
} = require("../notification/notification.service");
const {
  parsePaginationParams,
  buildPaginationMeta,
} = require("../../common/utils/pagination");
const { DeliveryLogModel } = require("../delivery/deliveryLog.model");
const { PaymentTransactionModel } = require("../payment/payment.model");

const SUCCESS_PAYMENT_STATUSES = ["verified", "captured", "paid", "authorized"];

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

function getTodayDateKey() {
  const now = new Date();
  const mm = String(now.getMonth() + 1).padStart(2, "0");
  const dd = String(now.getDate()).padStart(2, "0");
  return `${now.getFullYear()}-${mm}-${dd}`;
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

  const existingPendingForSeller = await JoinRequestModel.findOne({
    customerUserId: customerUser._id,
    sellerUserId: seller._id,
    status: "pending",
  }).select("_id");

  if (existingPendingForSeller) {
    throw new AppError(
      409,
      "PENDING_REQUEST_EXISTS",
      "You already have a pending join request for this seller.",
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

        customer.activeSellerUserId = sellerUser._id;
        customer.activeSellerLinkedAt = new Date();
        await customer.save({ session });

        request.status = "accepted";
        request.rejectionReason = "";
        request.respondedAt = new Date();
        request.respondedByUserId = sellerUser._id;
        await request.save({ session });

        const otherPendingRequests = await JoinRequestModel.find({
          customerUserId: customer._id,
          status: "pending",
          _id: { $ne: request._id },
        })
          .select("_id sellerUserId")
          .session(session)
          .lean();

        const otherPendingRequestIds = otherPendingRequests.map(
          (item) => item._id,
        );
        const otherSellerUserIds = Array.from(
          new Set(
            otherPendingRequests
              .map((item) => String(item.sellerUserId || "").trim())
              .filter(Boolean),
          ),
        );

        await JoinRequestModel.updateMany(
          {
            _id: { $in: otherPendingRequestIds },
          },
          {
            $set: {
              status: "cancelled",
              rejectionReason:
                "Cancelled because another seller accepted your request.",
              respondedAt: new Date(),
              respondedByUserId: sellerUser._id,
            },
          },
          { session },
        );

        await deleteJoinRequestSentNotificationsForSellers({
          customerUserId: customer._id,
          sellerUserIds: otherSellerUserIds,
          session,
        });

        if (otherSellerUserIds.length > 0) {
          await Promise.all(
            otherSellerUserIds.map((otherSellerUserId) =>
              createNotification({
                recipientUserId: otherSellerUserId,
                actorUserId: sellerUser._id,
                type: "request_auto_cancelled",
                title: "Join request auto-cancelled",
                message: `${customer.name || "Customer"} joined another seller organization. This pending request was auto-cancelled.`,
                metadata: {
                  customerUserId: customer._id,
                  acceptedSellerUserId: sellerUser._id,
                  acceptedRequestId: request._id,
                },
                session,
              }),
            ),
          );
        }

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

async function listSellerCustomers({ sellerUserId, page, limit }) {
  const pagination = parsePaginationParams({
    page,
    limit,
    defaultLimit: 50,
    maxLimit: 100,
  });

  const query = {
    role: "customer",
    isActive: true,
    activeSellerUserId: sellerUserId,
  };

  const [customers, totalCount] = await Promise.all([
    UserModel.find(query)
      .select("_id firebaseUid name mobileNumber email activeSellerLinkedAt")
      .sort({ activeSellerLinkedAt: -1, createdAt: -1 })
      .skip(pagination.skip)
      .limit(pagination.limit)
      .lean(),
    UserModel.countDocuments(query),
  ]);

  const customerIds = customers.map((customer) => customer._id);
  const [profiles, activePauses] = await Promise.all([
    customerIds.length
      ? CustomerProfileModel.find({
          userId: { $in: customerIds },
        })
          .select("userId defaultQuantityLitres displayAddress")
          .lean()
      : Promise.resolve([]),
    customerIds.length
      ? DeliveryPauseModel.find({
          sellerUserId,
          customerUserId: { $in: customerIds },
          status: "active",
        })
          .select("customerUserId startDateKey endDateKey")
          .sort({ startDateKey: 1, createdAt: -1 })
          .lean()
      : Promise.resolve([]),
  ]);

  const profileByUserId = new Map(
    profiles.map((profile) => [String(profile.userId), profile]),
  );

  const todayDateKey = getTodayDateKey();
  const pauseByUserId = new Map();
  for (const pause of activePauses) {
    const key = String(pause.customerUserId);
    const existing = pauseByUserId.get(key);
    if (!existing) {
      pauseByUserId.set(key, pause);
      continue;
    }

    const existingIsCurrent =
      existing.startDateKey <= todayDateKey &&
      existing.endDateKey >= todayDateKey;
    const nextIsCurrent =
      pause.startDateKey <= todayDateKey && pause.endDateKey >= todayDateKey;

    if (!existingIsCurrent && nextIsCurrent) {
      pauseByUserId.set(key, pause);
    }
  }

  const items = customers.map((customer) => ({
    ...(function pauseMeta() {
      const pause = pauseByUserId.get(String(customer._id));
      const isPausedToday =
        pause &&
        pause.startDateKey <= todayDateKey &&
        pause.endDateKey >= todayDateKey;

      return {
        pauseStatus: isPausedToday ? "paused" : "active",
        isPausedToday,
        pauseStartDateKey: pause?.startDateKey || null,
        pauseEndDateKey: pause?.endDateKey || null,
      };
    })(),
    customerUserId: customer._id,
    customerFirebaseUid: customer.firebaseUid,
    name: customer.name || null,
    phone: customer.mobileNumber || null,
    email: customer.email || null,
    displayAddress:
      profileByUserId.get(String(customer._id))?.displayAddress || null,
    defaultQuantityLitres:
      Number(profileByUserId.get(String(customer._id))?.defaultQuantityLitres) >
      0
        ? Number(
            profileByUserId.get(String(customer._id))?.defaultQuantityLitres,
          )
        : null,
    linkedAt: customer.activeSellerLinkedAt || null,
  }));

  return {
    items,
    pagination: buildPaginationMeta({
      page: pagination.page,
      limit: pagination.limit,
      totalItems: totalCount,
      returnedItems: items.length,
    }),
  };
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

function normalizeRupees(value) {
  return Number((Number(value) || 0).toFixed(2));
}

async function getCustomerOrganizationDueSummary(customerUser) {
  if (!customerUser.activeSellerUserId) {
    throw new AppError(
      400,
      "NOT_LINKED_TO_ORGANIZATION",
      "You are not linked to any seller organization.",
    );
  }

  const organizationPromise = getCustomerOrganization(customerUser);
  const paidAggregatePromise = PaymentTransactionModel.aggregate([
    {
      $match: {
        userId: customerUser._id,
        source: "customer_monthly_due",
        status: { $in: SUCCESS_PAYMENT_STATUSES },
      },
    },
    {
      $group: {
        _id: null,
        paidRupees: { $sum: "$amountInRupees" },
      },
    },
  ]);

  const organization = await organizationPromise;
  const sellerFirebaseUid = String(
    organization?.sellerFirebaseUid || "",
  ).trim();

  const logsAggregatePromise = sellerFirebaseUid
    ? DeliveryLogModel.aggregate([
        {
          $match: {
            customerId: customerUser._id,
            sellerFirebaseUid,
          },
        },
        {
          $group: {
            _id: null,
            totalRupees: { $sum: { $ifNull: ["$totalPriceRupees", 0] } },
          },
        },
      ])
    : Promise.resolve([]);

  const [logsAggregate, paidAggregate] = await Promise.all([
    logsAggregatePromise,
    paidAggregatePromise,
  ]);

  const totalRupees = normalizeRupees(logsAggregate?.[0]?.totalRupees || 0);
  const paidRupees = normalizeRupees(paidAggregate?.[0]?.paidRupees || 0);
  const pendingRupees = normalizeRupees(Math.max(0, totalRupees - paidRupees));

  return {
    totalRupees,
    paidRupees,
    pendingRupees,
    organization,
  };
}

async function getLeaveCustomerOrganizationPreview(customerUser) {
  const dueSummary = await getCustomerOrganizationDueSummary(customerUser);
  return {
    ...dueSummary,
    canLeave: dueSummary.pendingRupees <= 0,
  };
}

async function leaveCustomerOrganization(customerUser) {
  const { pendingRupees, organization: beforeOrganization } =
    await getCustomerOrganizationDueSummary(customerUser);

  if (pendingRupees > 0) {
    throw new AppError(
      409,
      "PENDING_DUES_EXIST",
      `Please clear pending dues of ₹${pendingRupees.toFixed(2)} before leaving your organization.`,
    );
  }

  const customer = await UserModel.findById(customerUser._id);
  if (!customer) {
    throw new AppError(404, "CUSTOMER_NOT_FOUND", "Customer not found.");
  }

  customer.activeSellerUserId = null;
  customer.activeSellerLinkedAt = null;
  await customer.save();

  return {
    left: true,
    pendingRupees,
    previousOrganization: beforeOrganization,
  };
}

module.exports = {
  createJoinRequest,
  listCustomerJoinRequests,
  listSellerJoinRequests,
  reviewJoinRequest,
  listSellerCustomers,
  getCustomerOrganization,
  getLeaveCustomerOrganizationPreview,
  leaveCustomerOrganization,
};
