const mongoose = require("mongoose");

const { AppError } = require("../../common/errors/AppError");
const { UserModel } = require("../user/user.model");
const { CustomerProfileModel } = require("../customer/customerProfile.model");
const { SellerProfileModel } = require("../seller/sellerProfile.model");
const { DeliveryLogModel } = require("./deliveryLog.model");
const { GlobalSettingsModel } = require("./globalSettings.model");
const { getTodayDateKey, asPaise } = require("./delivery.utils");

function toRadians(value) {
  return (value * Math.PI) / 180;
}

function toValidNumber(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function getValidGeoPoint(geo) {
  const lng = toValidNumber(geo?.coordinates?.[0]);
  const lat = toValidNumber(geo?.coordinates?.[1]);

  if (lng === null || lat === null) {
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

function buildRouteDistanceMeta(distanceKm) {
  const km = Math.max(0, Number(distanceKm.toFixed(3)));
  const meters = Math.round(km * 1000);

  if (meters <= 100) {
    return {
      routeDistanceKm: km,
      routeDistanceMeters: meters,
      routeDistanceLabel: meters === 0 ? "At same location" : "Very close",
      routeBucket: "very_close",
    };
  }

  if (meters <= 500) {
    return {
      routeDistanceKm: km,
      routeDistanceMeters: meters,
      routeDistanceLabel: "Nearby",
      routeBucket: "nearby",
    };
  }

  if (km < 1) {
    return {
      routeDistanceKm: km,
      routeDistanceMeters: meters,
      routeDistanceLabel: "Short route",
      routeBucket: "short",
    };
  }

  if (km <= 5) {
    return {
      routeDistanceKm: km,
      routeDistanceMeters: meters,
      routeDistanceLabel: "Medium route",
      routeBucket: "medium",
    };
  }

  return {
    routeDistanceKm: km,
    routeDistanceMeters: meters,
    routeDistanceLabel: "Long route",
    routeBucket: "long",
  };
}

function normalizeQuantity(quantityLitres) {
  const quantity = Number(quantityLitres);
  if (Number.isNaN(quantity) || quantity <= 0) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      "quantity must be a positive number in litres.",
    );
  }

  return Math.round(quantity * 1000) / 1000;
}

async function getBasePricePerLitrePaise(session = null) {
  const settings = await GlobalSettingsModel.findOneAndUpdate(
    { key: "global" },
    { $setOnInsert: { basePricePerLitrePaise: 6000 } },
    { new: true, upsert: true, setDefaultsOnInsert: true, session },
  );

  return settings.basePricePerLitrePaise;
}

async function getDailySheetForSeller(sellerFirebaseUid) {
  const dateKey = getTodayDateKey();

  const sellerUser = await UserModel.findOne({
    firebaseUid: sellerFirebaseUid,
    role: "seller",
    isActive: true,
  })
    .select("_id")
    .lean();

  if (!sellerUser) {
    throw new AppError(404, "SELLER_NOT_FOUND", "Seller profile not found.");
  }

  const customers = await UserModel.find({
    role: "customer",
    isActive: true,
    activeSellerUserId: sellerUser._id,
  })
    .select("_id firebaseUid name email mobileNumber")
    .lean();

  const customerIds = customers.map((customer) => customer._id);

  const [profiles, logs, basePricePerLitrePaise, sellerProfile] =
    await Promise.all([
      CustomerProfileModel.find({ userId: { $in: customerIds } })
        .select("userId defaultQuantityLitres displayAddress geo")
        .lean(),
      DeliveryLogModel.find({
        sellerFirebaseUid,
        dateKey,
        customerId: { $in: customerIds },
      }).lean(),
      getBasePricePerLitrePaise(),
      SellerProfileModel.findOne({ userId: sellerUser._id })
        .select("geo")
        .lean(),
    ]);

  const sellerPoint = getValidGeoPoint(sellerProfile?.geo);

  const profileByUserId = new Map(
    profiles.map((profile) => [profile.userId.toString(), profile]),
  );

  const logByCustomerId = new Map(
    logs.map((log) => [log.customerId.toString(), log]),
  );

  const sheet = customers.map((customer) => {
    const profile = profileByUserId.get(customer._id.toString());
    const log = logByCustomerId.get(customer._id.toString());
    const customerPoint = getValidGeoPoint(profile?.geo);

    const defaultQuantityLitres =
      profile?.defaultQuantityLitres && profile.defaultQuantityLitres > 0
        ? profile.defaultQuantityLitres
        : 1;

    const routeMeta =
      sellerPoint && customerPoint
        ? buildRouteDistanceMeta(
            distanceKmBetweenPoints({
              fromLat: sellerPoint.lat,
              fromLng: sellerPoint.lng,
              toLat: customerPoint.lat,
              toLng: customerPoint.lng,
            }),
          )
        : {
            routeDistanceKm: null,
            routeDistanceMeters: null,
            routeDistanceLabel: "Distance unavailable",
            routeBucket: "unknown",
            routeDistanceReason: !sellerPoint
              ? "Seller location missing"
              : "Customer location missing",
          };

    return {
      customerId: customer._id,
      customerFirebaseUid: customer.firebaseUid,
      customerName: customer.name || "Customer",
      customerDisplayAddress: profile?.displayAddress || "",
      mobileNumber: customer.mobileNumber || "",
      email: customer.email || "",
      defaultQuantityLitres,
      delivered: log?.delivered ?? false,
      quantityLitres: log?.quantityLitres ?? defaultQuantityLitres,
      basePricePerLitrePaise:
        log?.basePricePerLitrePaise ?? basePricePerLitrePaise,
      totalPricePaise:
        log?.totalPricePaise ??
        asPaise(basePricePerLitrePaise, defaultQuantityLitres),
      ...routeMeta,
      logId: log?._id || null,
      dateKey,
    };
  });

  sheet.sort((a, b) => {
    if (a.routeDistanceKm == null && b.routeDistanceKm == null) {
      return a.customerName.localeCompare(b.customerName);
    }

    if (a.routeDistanceKm == null) {
      return 1;
    }

    if (b.routeDistanceKm == null) {
      return -1;
    }

    return a.routeDistanceKm - b.routeDistanceKm;
  });

  return { sheet, dateKey, basePricePerLitrePaise };
}

async function bulkDeliverForSeller({ sellerFirebaseUid, customerIds }) {
  if (!Array.isArray(customerIds) || !customerIds.length) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      "customerIds must be a non-empty array.",
    );
  }

  const dateKey = getTodayDateKey();
  const sellerUser = await UserModel.findOne({
    firebaseUid: sellerFirebaseUid,
    role: "seller",
    isActive: true,
  })
    .select("_id")
    .lean();

  if (!sellerUser) {
    throw new AppError(404, "SELLER_NOT_FOUND", "Seller profile not found.");
  }

  const session = await mongoose.startSession();

  try {
    let result;
    await session.withTransaction(async () => {
      const customers = await UserModel.find({
        _id: { $in: customerIds },
        role: "customer",
        isActive: true,
        activeSellerUserId: sellerUser._id,
      })
        .select("_id firebaseUid")
        .session(session);

      if (customers.length !== customerIds.length) {
        throw new AppError(
          400,
          "VALIDATION_ERROR",
          "Some customerIds are invalid, inactive, or not linked to this seller.",
        );
      }

      const profileDocs = await CustomerProfileModel.find({
        userId: { $in: customers.map((customer) => customer._id) },
      })
        .select("userId defaultQuantityLitres")
        .session(session);

      const profileByUserId = new Map(
        profileDocs.map((profile) => [profile.userId.toString(), profile]),
      );

      const basePricePerLitrePaise = await getBasePricePerLitrePaise(session);
      const operations = customers.map((customer) => {
        const profile = profileByUserId.get(customer._id.toString());
        const defaultQuantityLitres =
          profile?.defaultQuantityLitres && profile.defaultQuantityLitres > 0
            ? profile.defaultQuantityLitres
            : 1;

        const quantityLitres = normalizeQuantity(defaultQuantityLitres);

        return {
          updateOne: {
            filter: {
              customerId: customer._id,
              sellerFirebaseUid,
              dateKey,
            },
            update: {
              $set: {
                customerFirebaseUid: customer.firebaseUid,
                delivered: true,
                quantityLitres,
                basePricePerLitrePaise,
                totalPricePaise: asPaise(
                  basePricePerLitrePaise,
                  quantityLitres,
                ),
                adjustedManually: false,
              },
            },
            upsert: true,
          },
        };
      });

      await DeliveryLogModel.bulkWrite(operations, { session });

      const updatedLogs = await DeliveryLogModel.find({
        customerId: { $in: customers.map((customer) => customer._id) },
        sellerFirebaseUid,
        dateKey,
      }).session(session);

      result = {
        updatedCount: updatedLogs.length,
        logs: updatedLogs,
        dateKey,
      };
    });

    return result;
  } finally {
    await session.endSession();
  }
}

async function adjustLogForSeller({
  sellerFirebaseUid,
  logId,
  quantityLitres,
}) {
  const quantity = normalizeQuantity(quantityLitres);
  const basePricePerLitrePaise = await getBasePricePerLitrePaise();

  const log = await DeliveryLogModel.findOne({
    _id: logId,
    sellerFirebaseUid,
  });

  if (!log) {
    throw new AppError(404, "LOG_NOT_FOUND", "Delivery log not found.");
  }

  log.quantityLitres = quantity;
  log.basePricePerLitrePaise = basePricePerLitrePaise;
  log.totalPricePaise = asPaise(basePricePerLitrePaise, quantity);
  log.adjustedManually = true;
  log.delivered = true;

  await log.save();
  return log;
}

async function getLedgerForCustomer(customerFirebaseUid) {
  const logs = await DeliveryLogModel.find({ customerFirebaseUid })
    .sort({ dateKey: -1, createdAt: -1 })
    .lean();

  const totalPaise = logs.reduce(
    (sum, log) => sum + Number(log.totalPricePaise || 0),
    0,
  );

  return {
    logs,
    summary: {
      count: logs.length,
      totalPaise,
    },
  };
}

module.exports = {
  getDailySheetForSeller,
  bulkDeliverForSeller,
  adjustLogForSeller,
  getLedgerForCustomer,
};
