const mongoose = require("mongoose");

const { AppError } = require("../../common/errors/AppError");
const { UserModel } = require("../user/user.model");
const { CustomerProfileModel } = require("../customer/customerProfile.model");
const { SellerProfileModel } = require("../seller/sellerProfile.model");
const { DeliveryPauseModel } = require("../deliveryPause/deliveryPause.model");
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

function sanitizeRouteErrorMessage(error) {
  const raw = String(error?.message || "Route service error").trim();
  if (!raw) {
    return "Route service error";
  }

  return raw.length > 80 ? `${raw.slice(0, 77)}...` : raw;
}

async function fetchRoadRouteDistanceKm({ fromLat, fromLng, toLat, toLng }) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 3500);

  try {
    const url = `https://router.project-osrm.org/route/v1/driving/${fromLng},${fromLat};${toLng},${toLat}?overview=false`;
    const response = await fetch(url, {
      signal: controller.signal,
      headers: {
        Accept: "application/json",
      },
    });

    if (!response.ok) {
      throw new Error(`Road route service returned HTTP ${response.status}`);
    }

    const payload = await response.json();
    if (payload?.code !== "Ok") {
      throw new Error("Road route service did not return a valid route");
    }

    const distanceMeters = Number(payload?.routes?.[0]?.distance);
    if (!Number.isFinite(distanceMeters) || distanceMeters < 0) {
      throw new Error("Road route distance data was invalid");
    }

    return distanceMeters / 1000;
  } catch (error) {
    if (error?.name === "AbortError") {
      throw new Error("Road route service timed out");
    }

    throw error;
  } finally {
    clearTimeout(timeout);
  }
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

function normalizeAreaText(value) {
  const normalized = String(value || "")
    .trim()
    .toLowerCase();
  if (!normalized) {
    return "";
  }

  return normalized.replace(/\s+/g, " ");
}

function extractRouteAreaLabel(profile) {
  const city = String(profile?.addressComponents?.city || "").trim();
  const state = String(profile?.addressComponents?.state || "").trim();
  const addressLine = String(profile?.displayAddress || "").trim();

  if (city && state) {
    return `${city}, ${state}`;
  }

  if (city) {
    return city;
  }

  if (state) {
    return state;
  }

  if (addressLine) {
    return (
      addressLine
        .split(",")
        .map((item) => item.trim())
        .filter(Boolean)[0] || ""
    );
  }

  return "";
}

function buildGeoClusterKey(point) {
  if (!point) {
    return "unknown";
  }

  const latBucket = Math.round(point.lat * 100) / 100;
  const lngBucket = Math.round(point.lng * 100) / 100;
  return `geo:${latBucket.toFixed(2)},${lngBucket.toFixed(2)}`;
}

function getClusterOrderMap(sheet) {
  const clusterStats = new Map();

  for (const item of sheet) {
    const key = item.routeClusterKey || "unknown";
    const distance = Number.isFinite(item.routeDistanceKm)
      ? item.routeDistanceKm
      : Number.POSITIVE_INFINITY;

    const current = clusterStats.get(key) || {
      key,
      label: item.routeClusterLabel || "Unknown area",
      minDistanceKm: Number.POSITIVE_INFINITY,
      itemsCount: 0,
    };

    current.itemsCount += 1;
    current.minDistanceKm = Math.min(current.minDistanceKm, distance);
    clusterStats.set(key, current);
  }

  const orderedClusters = Array.from(clusterStats.values()).sort((a, b) => {
    if (a.minDistanceKm !== b.minDistanceKm) {
      return a.minDistanceKm - b.minDistanceKm;
    }

    return a.label.localeCompare(b.label);
  });

  return new Map(orderedClusters.map((cluster, index) => [cluster.key, index]));
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

function getCurrentMonthKey() {
  const now = new Date();
  return `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, "0")}`;
}

function normalizeMonthKey(month) {
  if (!month || String(month).trim() === "") {
    return getCurrentMonthKey();
  }

  const normalized = String(month).trim();
  if (!/^\d{4}-\d{2}$/.test(normalized)) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      "month must be in YYYY-MM format.",
    );
  }

  const monthValue = Number(normalized.split("-")[1]);
  if (!Number.isInteger(monthValue) || monthValue < 1 || monthValue > 12) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      "month must be in YYYY-MM format.",
    );
  }

  return normalized;
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

  const activePauses = await DeliveryPauseModel.find({
    sellerUserId: sellerUser._id,
    status: "active",
    startDateKey: { $lte: dateKey },
    endDateKey: { $gte: dateKey },
  })
    .select("customerUserId")
    .lean();

  const pausedCustomerIdSet = new Set(
    activePauses.map((pause) => String(pause.customerUserId)),
  );

  const activeCustomers = customers.filter(
    (customer) => !pausedCustomerIdSet.has(String(customer._id)),
  );

  const customerIds = activeCustomers.map((customer) => customer._id);

  const [profiles, logs, basePricePerLitrePaise, sellerProfile] =
    await Promise.all([
      CustomerProfileModel.find({ userId: { $in: customerIds } })
        .select(
          "userId defaultQuantityLitres displayAddress addressComponents geo",
        )
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

  const sheet = await Promise.all(
    activeCustomers.map(async (customer) => {
      const profile = profileByUserId.get(customer._id.toString());
      const log = logByCustomerId.get(customer._id.toString());
      const customerPoint = getValidGeoPoint(profile?.geo);
      const routeAreaLabel = extractRouteAreaLabel(profile);
      const normalizedArea = normalizeAreaText(routeAreaLabel);
      const routeClusterKey = normalizedArea
        ? `area:${normalizedArea}`
        : buildGeoClusterKey(customerPoint);
      const routeClusterLabel =
        routeAreaLabel ||
        (routeClusterKey === "unknown" ? "Unknown area" : "Geo cluster");

      const defaultQuantityLitres =
        profile?.defaultQuantityLitres && profile.defaultQuantityLitres > 0
          ? profile.defaultQuantityLitres
          : 1;

      let routeMeta;
      if (sellerPoint && customerPoint) {
        try {
          const roadDistanceKm = await fetchRoadRouteDistanceKm({
            fromLat: sellerPoint.lat,
            fromLng: sellerPoint.lng,
            toLat: customerPoint.lat,
            toLng: customerPoint.lng,
          });

          routeMeta = buildRouteDistanceMeta(roadDistanceKm);
        } catch (error) {
          const straightLineKm = distanceKmBetweenPoints({
            fromLat: sellerPoint.lat,
            fromLng: sellerPoint.lng,
            toLat: customerPoint.lat,
            toLng: customerPoint.lng,
          });

          routeMeta = {
            ...buildRouteDistanceMeta(straightLineKm),
            routeDistanceLabel: "Straight-line estimate",
            routeDistanceReason: `Could not calculate actual road-route (${sanitizeRouteErrorMessage(
              error,
            )}). Showing straight-line distance.`,
          };
        }
      } else {
        routeMeta = {
          routeDistanceKm: null,
          routeDistanceMeters: null,
          routeDistanceLabel: "Distance unavailable",
          routeBucket: "unknown",
          routeDistanceReason: !sellerPoint
            ? "Seller location missing"
            : "Customer location missing",
        };
      }

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
        routeClusterKey,
        routeClusterLabel,
        ...routeMeta,
        logId: log?._id || null,
        dateKey,
      };
    }),
  );

  const clusterOrderMap = getClusterOrderMap(sheet);

  sheet.sort((a, b) => {
    const clusterA =
      clusterOrderMap.get(a.routeClusterKey || "unknown") ?? 999999;
    const clusterB =
      clusterOrderMap.get(b.routeClusterKey || "unknown") ?? 999999;

    if (clusterA !== clusterB) {
      return clusterA - clusterB;
    }

    if (a.routeDistanceKm == null) {
      return 1;
    }

    if (b.routeDistanceKm == null) {
      return -1;
    }

    if (a.routeDistanceKm !== b.routeDistanceKm) {
      return a.routeDistanceKm - b.routeDistanceKm;
    }

    return a.customerName.localeCompare(b.customerName);
  });

  return {
    sheet,
    dateKey,
    basePricePerLitrePaise,
    pausedCustomersCount: pausedCustomerIdSet.size,
  };
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

async function getMonthlySummaryForCustomer(customerFirebaseUid, month) {
  const monthKey = normalizeMonthKey(month);
  const logs = await DeliveryLogModel.find({
    customerFirebaseUid,
    dateKey: { $regex: `^${monthKey}-` },
  })
    .sort({ dateKey: -1, createdAt: -1 })
    .lean();

  const totalPaise = logs.reduce(
    (sum, log) => sum + Number(log.totalPricePaise || 0),
    0,
  );
  const adjustedCount = logs.filter((log) =>
    Boolean(log.adjustedManually),
  ).length;

  return {
    month: monthKey,
    logs,
    summary: {
      deliveredDays: logs.length,
      adjustedDays: adjustedCount,
      totalPaise,
      paidPaise: 0,
      pendingPaise: totalPaise,
    },
  };
}

async function getMonthlySummaryForSeller(sellerFirebaseUid, month) {
  const monthKey = normalizeMonthKey(month);
  const logs = await DeliveryLogModel.find({
    sellerFirebaseUid,
    dateKey: { $regex: `^${monthKey}-` },
  })
    .sort({ dateKey: -1, createdAt: -1 })
    .lean();

  const totalPaise = logs.reduce(
    (sum, log) => sum + Number(log.totalPricePaise || 0),
    0,
  );

  const byCustomerMap = new Map();
  for (const log of logs) {
    const key = String(log.customerFirebaseUid || log.customerId || "unknown");
    const current = byCustomerMap.get(key) || {
      customerFirebaseUid: log.customerFirebaseUid || null,
      customerId: log.customerId || null,
      deliveredDays: 0,
      totalPaise: 0,
      paidPaise: 0,
      pendingPaise: 0,
    };

    current.deliveredDays += 1;
    current.totalPaise += Number(log.totalPricePaise || 0);
    current.pendingPaise += Number(log.totalPricePaise || 0);
    byCustomerMap.set(key, current);
  }

  return {
    month: monthKey,
    summary: {
      deliveredLogs: logs.length,
      totalPaise,
      paidPaise: 0,
      pendingPaise: totalPaise,
    },
    customers: Array.from(byCustomerMap.values()).sort(
      (a, b) => b.totalPaise - a.totalPaise,
    ),
  };
}

module.exports = {
  getDailySheetForSeller,
  bulkDeliverForSeller,
  adjustLogForSeller,
  getLedgerForCustomer,
  getMonthlySummaryForCustomer,
  getMonthlySummaryForSeller,
};
