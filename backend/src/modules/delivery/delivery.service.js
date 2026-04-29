const mongoose = require("mongoose");

const { AppError } = require("../../common/errors/AppError");
const { UserModel } = require("../user/user.model");
const { CustomerProfileModel } = require("../customer/customerProfile.model");
const { SellerProfileModel } = require("../seller/sellerProfile.model");
const { DeliveryPauseModel } = require("../deliveryPause/deliveryPause.model");
const { DeliveryLogModel } = require("./deliveryLog.model");
const { DeliveryAuditModel } = require("./deliveryAudit.model");
const {
  DeliveryDisputeModel,
  deliveryDisputeTypeEnum,
} = require("./deliveryDispute.model");
const {
  DeliveryCorrectionRequestModel,
} = require("./deliveryCorrectionRequest.model");
const { GlobalSettingsModel } = require("./globalSettings.model");
const { PaymentTransactionModel } = require("../payment/payment.model");
const {
  parsePaginationParams,
  buildPaginationMeta,
} = require("../../common/utils/pagination");
const { env } = require("../../config/env");
const {
  getTodayDateKey,
  getCurrentDeliverySlot,
  asRupees,
} = require("./delivery.utils");

const CUSTOMER_MONTHLY_DUE_SOURCE = "customer_monthly_due";
const SUCCESS_PAYMENT_STATUSES = ["verified", "captured", "paid", "authorized"];
const ROAD_ROUTE_TIMEOUT_MS = 1200;
const ROAD_ROUTE_CACHE_TTL_MS = 5 * 60 * 1000;
const ROAD_ROUTE_MAX_CONCURRENCY = 6;
const roadRouteDistanceCache = new Map();

function buildRoadRouteCacheKey({ fromLat, fromLng, toLat, toLng }) {
  return [
    Number(fromLat).toFixed(4),
    Number(fromLng).toFixed(4),
    Number(toLat).toFixed(4),
    Number(toLng).toFixed(4),
  ].join(":");
}

function getCachedRoadRouteDistanceKm(cacheKey) {
  const cached = roadRouteDistanceCache.get(cacheKey);
  if (!cached) {
    return null;
  }

  if (cached.expiresAt <= Date.now()) {
    roadRouteDistanceCache.delete(cacheKey);
    return null;
  }

  return cached.distanceKm;
}

function setCachedRoadRouteDistanceKm(cacheKey, distanceKm) {
  roadRouteDistanceCache.set(cacheKey, {
    distanceKm,
    expiresAt: Date.now() + ROAD_ROUTE_CACHE_TTL_MS,
  });
}

async function mapWithConcurrency(items, limit, mapper) {
  if (!Array.isArray(items) || items.length === 0) {
    return [];
  }

  const safeLimit = Math.max(1, Number(limit) || 1);
  const results = new Array(items.length);
  let nextIndex = 0;

  async function worker() {
    while (nextIndex < items.length) {
      const index = nextIndex;
      nextIndex += 1;
      results[index] = await mapper(items[index], index);
    }
  }

  const workers = Array.from(
    { length: Math.min(safeLimit, items.length) },
    () => worker(),
  );

  await Promise.all(workers);
  return results;
}

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
  const cacheKey = buildRoadRouteCacheKey({ fromLat, fromLng, toLat, toLng });
  const cachedDistanceKm = getCachedRoadRouteDistanceKm(cacheKey);
  if (cachedDistanceKm !== null) {
    return cachedDistanceKm;
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), ROAD_ROUTE_TIMEOUT_MS);

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

    const distanceKm = distanceMeters / 1000;
    setCachedRoadRouteDistanceKm(cacheKey, distanceKm);
    return distanceKm;
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

function slotFieldName(slot) {
  return slot === "evening" ? "eveningQuantityLitres" : "morningQuantityLitres";
}

function normalizeStoredSlotQuantity(value) {
  const quantity = Number(value);
  if (!Number.isFinite(quantity) || quantity < 0) {
    return 0;
  }

  return Math.round(quantity * 1000) / 1000;
}

function readSlotQuantities(log) {
  const morningQuantityLitres = normalizeStoredSlotQuantity(
    log?.morningQuantityLitres,
  );
  const eveningQuantityLitres = normalizeStoredSlotQuantity(
    log?.eveningQuantityLitres,
  );

  if (morningQuantityLitres === 0 && eveningQuantityLitres === 0) {
    const legacyQuantity = normalizeStoredSlotQuantity(log?.quantityLitres);
    if (legacyQuantity > 0) {
      return {
        morningQuantityLitres: legacyQuantity,
        eveningQuantityLitres: 0,
      };
    }
  }

  return {
    morningQuantityLitres,
    eveningQuantityLitres,
  };
}

function readSlotQuantity(log, slot) {
  const slotKey = slotFieldName(slot);
  return readSlotQuantities(log)[slotKey];
}

function getUniqueDateCount(logs) {
  return new Set(logs.map((log) => String(log?.dateKey || ""))).size;
}

function normalizeOptionalText(value, maxLength = 500) {
  const normalized = String(value || "").trim();
  if (!normalized) {
    return null;
  }

  return normalized.slice(0, maxLength);
}

function serializeLogSnapshot(log) {
  if (!log) {
    return null;
  }

  return {
    deliveryLogId: String(log._id || ""),
    dateKey: String(log.dateKey || ""),
    deliverySlot: String(log.deliverySlot || "morning"),
    morningQuantityLitres: normalizeStoredSlotQuantity(
      log.morningQuantityLitres,
    ),
    eveningQuantityLitres: normalizeStoredSlotQuantity(
      log.eveningQuantityLitres,
    ),
    quantityLitres: normalizeStoredSlotQuantity(log.quantityLitres),
    totalPriceRupees: readTotalPriceRupees(log),
    delivered: Boolean(log.delivered),
    adjustedManually: Boolean(log.adjustedManually),
  };
}

async function createDeliveryAuditEntry({
  action,
  actorFirebaseUid,
  actorRole,
  log,
  reason,
  before,
  after,
  metadata,
}) {
  if (!action || !actorFirebaseUid || !actorRole) {
    return;
  }

  await DeliveryAuditModel.create({
    deliveryLogId: log?._id || null,
    customerId: log?.customerId || null,
    customerFirebaseUid: log?.customerFirebaseUid || null,
    sellerFirebaseUid: log?.sellerFirebaseUid || null,
    dateKey: log?.dateKey || null,
    deliverySlot: log?.deliverySlot || null,
    action,
    actorFirebaseUid,
    actorRole,
    reason: normalizeOptionalText(reason),
    before: before || null,
    after: after || null,
    metadata: metadata || null,
  });
}

async function ensureCustomerNotPausedForDate({
  sellerUserId,
  customerUserId,
  dateKey,
}) {
  const activePause = await DeliveryPauseModel.findOne({
    sellerUserId,
    customerUserId,
    status: "active",
    startDateKey: { $lte: dateKey },
    endDateKey: { $gte: dateKey },
  })
    .select("_id")
    .lean();

  if (activePause) {
    throw new AppError(
      400,
      "DELIVERY_PAUSED",
      "Delivery is paused for this customer on the selected date.",
    );
  }
}

function getCurrentMonthKey() {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
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

function normalizeRupees(value) {
  return Number((Number(value) || 0).toFixed(2));
}

function readBasePricePerLitreRupees(source) {
  const rupees = Number(source?.basePricePerLitreRupees);
  if (Number.isFinite(rupees)) {
    return normalizeRupees(rupees);
  }

  return 60;
}

function readTotalPriceRupees(source) {
  const rupees = Number(source?.totalPriceRupees);
  if (Number.isFinite(rupees)) {
    return normalizeRupees(rupees);
  }

  return 0;
}

function getSellerSettingsKey(sellerUserId) {
  return `seller:${String(sellerUserId)}`;
}

async function getBasePricePerLitreRupees({ sellerUserId, session = null }) {
  if (!sellerUserId) {
    throw new AppError(400, "VALIDATION_ERROR", "sellerUserId is required.");
  }

  const settings = await GlobalSettingsModel.findOneAndUpdate(
    { key: getSellerSettingsKey(sellerUserId) },
    { $setOnInsert: { basePricePerLitreRupees: 60 } },
    { new: true, upsert: true, setDefaultsOnInsert: true, session },
  );

  return readBasePricePerLitreRupees(settings);
}

async function getSellerUserByFirebaseUid(sellerFirebaseUid) {
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

  return sellerUser;
}

async function getMilkSettingsForSeller(sellerFirebaseUid) {
  const sellerUser = await getSellerUserByFirebaseUid(sellerFirebaseUid);
  const basePricePerLitreRupees = await getBasePricePerLitreRupees({
    sellerUserId: sellerUser._id,
  });

  const customers = await UserModel.find({
    role: "customer",
    isActive: true,
    activeSellerUserId: sellerUser._id,
  })
    .select("_id firebaseUid name mobileNumber email")
    .sort({ activeSellerLinkedAt: -1, createdAt: -1 })
    .lean();

  const customerIds = customers.map((customer) => customer._id);
  const profiles = await CustomerProfileModel.find({
    userId: { $in: customerIds },
  })
    .select("userId defaultQuantityLitres displayAddress")
    .lean();

  const profileByUserId = new Map(
    profiles.map((profile) => [String(profile.userId), profile]),
  );

  return {
    basePricePerLitreRupees,
    customers: customers.map((customer) => {
      const profile = profileByUserId.get(String(customer._id));
      const defaultQuantityLitres =
        profile?.defaultQuantityLitres && profile.defaultQuantityLitres > 0
          ? Number(profile.defaultQuantityLitres)
          : 1;

      return {
        customerUserId: customer._id,
        customerFirebaseUid: customer.firebaseUid,
        name: customer.name || null,
        phone: customer.mobileNumber || null,
        email: customer.email || null,
        displayAddress: profile?.displayAddress || null,
        defaultQuantityLitres,
      };
    }),
  };
}

async function updateMilkBasePriceForSeller({
  sellerFirebaseUid,
  basePricePerLitreRupees,
}) {
  const sellerUser = await getSellerUserByFirebaseUid(sellerFirebaseUid);

  const parsed = Number(basePricePerLitreRupees);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      "basePricePerLitreRupees must be a positive number.",
    );
  }

  const normalizedPrice = normalizeRupees(parsed);
  const settings = await GlobalSettingsModel.findOneAndUpdate(
    { key: getSellerSettingsKey(sellerUser._id) },
    { $set: { basePricePerLitreRupees: normalizedPrice } },
    { new: true, upsert: true, setDefaultsOnInsert: true },
  );

  return {
    basePricePerLitreRupees: readBasePricePerLitreRupees(settings),
  };
}

async function updateCustomerDefaultQuantityForSeller({
  sellerFirebaseUid,
  customerUserId,
  defaultQuantityLitres,
}) {
  if (!mongoose.Types.ObjectId.isValid(String(customerUserId || ""))) {
    throw new AppError(400, "VALIDATION_ERROR", "Invalid customer user id.");
  }

  const sellerUser = await getSellerUserByFirebaseUid(sellerFirebaseUid);
  const quantity = normalizeQuantity(defaultQuantityLitres);

  const customerUser = await UserModel.findOne({
    _id: customerUserId,
    role: "customer",
    isActive: true,
    activeSellerUserId: sellerUser._id,
  }).select("_id name firebaseUid");

  if (!customerUser) {
    throw new AppError(
      404,
      "CUSTOMER_NOT_FOUND",
      "Customer not found in your organization.",
    );
  }

  const profile = await CustomerProfileModel.findOneAndUpdate(
    { userId: customerUser._id },
    { $set: { defaultQuantityLitres: quantity } },
    { upsert: true, new: true, setDefaultsOnInsert: true },
  ).lean();

  return {
    customerUserId: customerUser._id,
    customerFirebaseUid: customerUser.firebaseUid,
    customerName: customerUser.name || "Customer",
    defaultQuantityLitres:
      Number(profile?.defaultQuantityLitres) > 0
        ? Number(profile.defaultQuantityLitres)
        : quantity,
  };
}

async function getDailySheetForSeller(sellerFirebaseUid) {
  const dateKey = getTodayDateKey();
  const currentSlot = getCurrentDeliverySlot();

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
    .select("_id firebaseUid name email mobileNumber activeSellerLinkedAt")
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

  const [profiles, logs, basePricePerLitreRupees, sellerProfile] =
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
      getBasePricePerLitreRupees({ sellerUserId: sellerUser._id }),
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

  const sheet = await mapWithConcurrency(
    activeCustomers,
    ROAD_ROUTE_MAX_CONCURRENCY,
    async (customer) => {
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
      const currentSlotQuantity = log ? readSlotQuantity(log, currentSlot) : 0;
      const hasCurrentSlotDelivery = currentSlotQuantity > 0;

      let routeMeta;
      if (sellerPoint && customerPoint) {
        const straightLineKm = distanceKmBetweenPoints({
          fromLat: sellerPoint.lat,
          fromLng: sellerPoint.lng,
          toLat: customerPoint.lat,
          toLng: customerPoint.lng,
        });

        if (!env.roadRouteEnabled) {
          routeMeta = {
            routeDistanceKm: null,
            routeDistanceMeters: null,
            routeDistanceLabel: "Distance unavailable",
            routeBucket: "unknown",
            routeDistanceReason:
              "Road-route service disabled for faster sheet loading.",
          };
        } else {
          try {
            const roadDistanceKm = await fetchRoadRouteDistanceKm({
              fromLat: sellerPoint.lat,
              fromLng: sellerPoint.lng,
              toLat: customerPoint.lat,
              toLng: customerPoint.lng,
            });

            routeMeta = buildRouteDistanceMeta(roadDistanceKm);
          } catch (error) {
            routeMeta = {
              routeDistanceKm: null,
              routeDistanceMeters: null,
              routeDistanceLabel: "Distance unavailable",
              routeBucket: "unknown",
              routeDistanceReason: `Could not calculate actual road-route (${sanitizeRouteErrorMessage(
                error,
              )}).`,
            };
          }
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
        organizationJoinedAt: customer.activeSellerLinkedAt || null,
        defaultQuantityLitres,
        delivered: hasCurrentSlotDelivery,
        quantityLitres: hasCurrentSlotDelivery
          ? currentSlotQuantity
          : defaultQuantityLitres,
        deliverySlot: currentSlot,
        basePricePerLitreRupees: log
          ? readBasePricePerLitreRupees(log)
          : basePricePerLitreRupees,
        totalPriceRupees: asRupees(
          log ? readBasePricePerLitreRupees(log) : basePricePerLitreRupees,
          hasCurrentSlotDelivery ? currentSlotQuantity : defaultQuantityLitres,
        ),
        routeClusterKey,
        routeClusterLabel,
        ...routeMeta,
        logId: log?._id || null,
        dateKey,
      };
    },
  );

  const clusterOrderMap = getClusterOrderMap(sheet);

  sheet.sort((a, b) => {
    if (Boolean(a.delivered) !== Boolean(b.delivered)) {
      return a.delivered ? 1 : -1;
    }

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
    deliverySlot: currentSlot,
    basePricePerLitreRupees,
    pausedCustomersCount: pausedCustomerIdSet.size,
  };
}

async function deliverCustomerForSeller({
  sellerFirebaseUid,
  customerId,
  quantityLitres,
}) {
  if (!mongoose.Types.ObjectId.isValid(String(customerId || ""))) {
    throw new AppError(400, "VALIDATION_ERROR", "Invalid customer id.");
  }

  const dateKey = getTodayDateKey();
  const deliverySlot = getCurrentDeliverySlot();
  const quantity = normalizeQuantity(quantityLitres);

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

  const customerUser = await UserModel.findOne({
    _id: customerId,
    role: "customer",
    isActive: true,
    activeSellerUserId: sellerUser._id,
  })
    .select("_id firebaseUid")
    .lean();

  if (!customerUser) {
    throw new AppError(
      404,
      "CUSTOMER_NOT_FOUND",
      "Customer not found in your organization.",
    );
  }

  await ensureCustomerNotPausedForDate({
    sellerUserId: sellerUser._id,
    customerUserId: customerUser._id,
    dateKey,
  });

  const basePricePerLitreRupees = await getBasePricePerLitreRupees({
    sellerUserId: sellerUser._id,
  });
  const existingLog = await DeliveryLogModel.findOne({
    customerId: customerUser._id,
    sellerFirebaseUid,
    dateKey,
  }).lean();
  const beforeSnapshot = serializeLogSnapshot(existingLog);

  const existingQuantities = readSlotQuantities(existingLog);
  const nextMorningQuantityLitres =
    deliverySlot === "morning"
      ? quantity
      : existingQuantities.morningQuantityLitres;
  const nextEveningQuantityLitres =
    deliverySlot === "evening"
      ? quantity
      : existingQuantities.eveningQuantityLitres;
  const totalQuantityLitres = Number(
    (nextMorningQuantityLitres + nextEveningQuantityLitres).toFixed(3),
  );
  const totalPriceRupees = asRupees(
    basePricePerLitreRupees,
    totalQuantityLitres,
  );

  const updatedLog = await DeliveryLogModel.findOneAndUpdate(
    {
      customerId: customerUser._id,
      sellerFirebaseUid,
      dateKey,
    },
    {
      $set: {
        customerFirebaseUid: customerUser.firebaseUid,
        morningQuantityLitres: nextMorningQuantityLitres,
        eveningQuantityLitres: nextEveningQuantityLitres,
        deliverySlot,
        quantityLitres: totalQuantityLitres,
        basePricePerLitreRupees,
        totalPriceRupees,
        delivered: totalQuantityLitres > 0,
        adjustedManually: true,
      },
    },
    { new: true, upsert: true, setDefaultsOnInsert: true },
  ).lean();

  await createDeliveryAuditEntry({
    action: existingLog ? "log_slot_updated" : "log_created",
    actorFirebaseUid: sellerFirebaseUid,
    actorRole: "seller",
    log: updatedLog,
    before: beforeSnapshot,
    after: serializeLogSnapshot(updatedLog),
    metadata: {
      source: "deliver_customer",
      deliverySlot,
    },
  });

  return {
    dateKey,
    deliverySlot,
    log: updatedLog,
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
  const deliverySlot = getCurrentDeliverySlot();
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
    _id: { $in: customerIds },
    role: "customer",
    isActive: true,
    activeSellerUserId: sellerUser._id,
  })
    .select("_id firebaseUid")
    .lean();

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
    .lean();

  const profileByUserId = new Map(
    profileDocs.map((profile) => [profile.userId.toString(), profile]),
  );

  await Promise.all(
    customers.map((customer) =>
      ensureCustomerNotPausedForDate({
        sellerUserId: sellerUser._id,
        customerUserId: customer._id,
        dateKey,
      }),
    ),
  );

  const existingLogs = await DeliveryLogModel.find({
    customerId: { $in: customers.map((customer) => customer._id) },
    sellerFirebaseUid,
    dateKey,
  }).lean();
  const existingLogByCustomerId = new Map(
    existingLogs.map((log) => [String(log.customerId), log]),
  );
  const beforeSnapshotByCustomerId = new Map(
    existingLogs.map((log) => [
      String(log.customerId),
      serializeLogSnapshot(log),
    ]),
  );

  const basePricePerLitreRupees = await getBasePricePerLitreRupees({
    sellerUserId: sellerUser._id,
  });
  const operations = customers.map((customer) => {
    const profile = profileByUserId.get(String(customer._id));
    const defaultQuantityLitres =
      profile?.defaultQuantityLitres && profile.defaultQuantityLitres > 0
        ? profile.defaultQuantityLitres
        : 1;
    const slotQuantity = normalizeQuantity(defaultQuantityLitres);
    const existingLog = existingLogByCustomerId.get(String(customer._id));
    const existingQuantities = readSlotQuantities(existingLog);

    const nextMorningQuantityLitres =
      deliverySlot === "morning"
        ? slotQuantity
        : existingQuantities.morningQuantityLitres;
    const nextEveningQuantityLitres =
      deliverySlot === "evening"
        ? slotQuantity
        : existingQuantities.eveningQuantityLitres;
    const totalQuantityLitres = Number(
      (nextMorningQuantityLitres + nextEveningQuantityLitres).toFixed(3),
    );

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
            morningQuantityLitres: nextMorningQuantityLitres,
            eveningQuantityLitres: nextEveningQuantityLitres,
            deliverySlot,
            delivered: totalQuantityLitres > 0,
            quantityLitres: totalQuantityLitres,
            basePricePerLitreRupees,
            totalPriceRupees: asRupees(
              basePricePerLitreRupees,
              totalQuantityLitres,
            ),
            adjustedManually: false,
          },
        },
        upsert: true,
      },
    };
  });

  await DeliveryLogModel.bulkWrite(operations);

  const updatedLogs = await DeliveryLogModel.find({
    customerId: { $in: customers.map((customer) => customer._id) },
    sellerFirebaseUid,
    dateKey,
  }).lean();

  await Promise.all(
    updatedLogs.map((log) => {
      const customerId = String(log.customerId || "");
      const before = beforeSnapshotByCustomerId.get(customerId) || null;

      return createDeliveryAuditEntry({
        action: before ? "log_slot_updated" : "log_created",
        actorFirebaseUid: sellerFirebaseUid,
        actorRole: "seller",
        log,
        before,
        after: serializeLogSnapshot(log),
        metadata: {
          source: "bulk_deliver",
          deliverySlot,
        },
      });
    }),
  );

  return {
    updatedCount: updatedLogs.length,
    logs: updatedLogs,
    dateKey,
    deliverySlot,
  };
}

async function adjustLogForSeller({
  sellerFirebaseUid,
  logId,
  quantityLitres,
}) {
  const dateKey = getTodayDateKey();
  const deliverySlot = getCurrentDeliverySlot();
  const quantity = normalizeQuantity(quantityLitres);
  const sellerUser = await getSellerUserByFirebaseUid(sellerFirebaseUid);
  const basePricePerLitreRupees = await getBasePricePerLitreRupees({
    sellerUserId: sellerUser._id,
  });

  const log = await DeliveryLogModel.findOne({
    _id: logId,
    sellerFirebaseUid,
  });

  if (!log) {
    throw new AppError(404, "LOG_NOT_FOUND", "Delivery log not found.");
  }
  const beforeSnapshot = serializeLogSnapshot(log.toObject());

  if (String(log.dateKey) !== dateKey) {
    throw new AppError(
      403,
      "LOG_LOCKED",
      "Only today's delivery log can be adjusted.",
    );
  }

  const existingQuantities = readSlotQuantities(log);
  const nextMorningQuantityLitres =
    deliverySlot === "morning"
      ? quantity
      : existingQuantities.morningQuantityLitres;
  const nextEveningQuantityLitres =
    deliverySlot === "evening"
      ? quantity
      : existingQuantities.eveningQuantityLitres;
  const totalQuantityLitres = Number(
    (nextMorningQuantityLitres + nextEveningQuantityLitres).toFixed(3),
  );

  log.morningQuantityLitres = nextMorningQuantityLitres;
  log.eveningQuantityLitres = nextEveningQuantityLitres;
  log.deliverySlot = deliverySlot;
  log.quantityLitres = totalQuantityLitres;
  log.basePricePerLitreRupees = basePricePerLitreRupees;
  log.totalPriceRupees = asRupees(basePricePerLitreRupees, totalQuantityLitres);
  log.adjustedManually = true;
  log.delivered = totalQuantityLitres > 0;

  await log.save();

  await createDeliveryAuditEntry({
    action: "log_adjusted_same_day",
    actorFirebaseUid: sellerFirebaseUid,
    actorRole: "seller",
    log,
    before: beforeSnapshot,
    after: serializeLogSnapshot(log.toObject()),
    metadata: {
      source: "adjust_log",
      deliverySlot,
    },
  });

  return log;
}

async function getLedgerForCustomer(customerFirebaseUid) {
  const logs = await DeliveryLogModel.find({ customerFirebaseUid })
    .sort({ dateKey: -1, createdAt: -1 })
    .lean();

  const totalRupees = logs.reduce(
    (sum, log) => sum + readTotalPriceRupees(log),
    0,
  );

  return {
    logs,
    summary: {
      count: getUniqueDateCount(logs),
      totalRupees: normalizeRupees(totalRupees),
    },
  };
}

async function getMonthlySummaryForCustomer(customerFirebaseUid, month) {
  const monthKey = normalizeMonthKey(month);
  const customerUser = await UserModel.findOne({
    firebaseUid: customerFirebaseUid,
    role: "customer",
    isActive: true,
  })
    .select("_id")
    .lean();

  const logs = await DeliveryLogModel.find({
    customerFirebaseUid,
    dateKey: { $regex: `^${monthKey}-` },
  })
    .sort({ dateKey: -1, createdAt: -1 })
    .lean();

  let paidRupees = 0;
  if (customerUser?._id) {
    const paidAggregate = await PaymentTransactionModel.aggregate([
      {
        $match: {
          userId: customerUser._id,
          source: CUSTOMER_MONTHLY_DUE_SOURCE,
          status: { $in: SUCCESS_PAYMENT_STATUSES },
          "notes.month": monthKey,
        },
      },
      {
        $group: {
          _id: null,
          paidRupees: { $sum: "$amountInRupees" },
        },
      },
    ]);

    paidRupees = normalizeRupees(paidAggregate?.[0]?.paidRupees || 0);
  }

  const totalRupees = logs.reduce(
    (sum, log) => sum + readTotalPriceRupees(log),
    0,
  );
  const adjustedCount = logs.filter((log) =>
    Boolean(log.adjustedManually),
  ).length;
  const normalizedTotalRupees = normalizeRupees(totalRupees);
  const normalizedPendingRupees = normalizeRupees(
    Math.max(0, normalizedTotalRupees - paidRupees),
  );

  return {
    month: monthKey,
    logs,
    summary: {
      deliveredDays: getUniqueDateCount(logs),
      adjustedDays: getUniqueDateCount(
        logs.filter((log) => Boolean(log.adjustedManually)),
      ),
      totalRupees: normalizedTotalRupees,
      paidRupees,
      pendingRupees: normalizedPendingRupees,
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

  const totalRupees = logs.reduce(
    (sum, log) => sum + readTotalPriceRupees(log),
    0,
  );

  const totalQuantityLitres = logs.reduce((sum, log) => {
    const quantity = Number(log.quantityLitres || 0);
    return sum + (Number.isFinite(quantity) ? quantity : 0);
  }, 0);

  const customerObjectIds = logs
    .map((log) => log.customerId)
    .filter((value) => mongoose.Types.ObjectId.isValid(String(value || "")))
    .map((value) => String(value));
  const customerFirebaseUids = logs
    .map((log) => String(log.customerFirebaseUid || "").trim())
    .filter(Boolean);

  const userQueryParts = [];
  if (customerObjectIds.length) {
    userQueryParts.push({
      _id: {
        $in: customerObjectIds.map((id) => new mongoose.Types.ObjectId(id)),
      },
    });
  }
  if (customerFirebaseUids.length) {
    userQueryParts.push({ firebaseUid: { $in: customerFirebaseUids } });
  }

  const users = userQueryParts.length
    ? await UserModel.find({ $or: userQueryParts })
        .select("_id firebaseUid name")
        .lean()
    : [];

  const customerUserIds = users
    .map((user) => user?._id)
    .filter((id) => mongoose.Types.ObjectId.isValid(String(id || "")));

  const paidByCustomerUserId = new Map();
  if (customerUserIds.length) {
    const paymentAggregate = await PaymentTransactionModel.aggregate([
      {
        $match: {
          userId: { $in: customerUserIds },
          source: CUSTOMER_MONTHLY_DUE_SOURCE,
          status: { $in: SUCCESS_PAYMENT_STATUSES },
          "notes.month": monthKey,
        },
      },
      {
        $group: {
          _id: "$userId",
          paidRupees: { $sum: "$amountInRupees" },
        },
      },
    ]);

    for (const item of paymentAggregate) {
      paidByCustomerUserId.set(
        String(item?._id),
        normalizeRupees(item?.paidRupees || 0),
      );
    }
  }

  const userById = new Map(users.map((user) => [String(user._id), user]));
  const userByFirebaseUid = new Map(
    users.map((user) => [String(user.firebaseUid || ""), user]),
  );

  const byCustomerMap = new Map();
  for (const log of logs) {
    const key = String(log.customerFirebaseUid || log.customerId || "unknown");
    const customerIdKey = String(log.customerId || "");
    const customerFirebaseUidKey = String(log.customerFirebaseUid || "");
    const customerUser =
      userById.get(customerIdKey) ||
      userByFirebaseUid.get(customerFirebaseUidKey);
    const quantityLitres = Number(log.quantityLitres || 0);
    const normalizedQuantityLitres = Number.isFinite(quantityLitres)
      ? quantityLitres
      : 0;

    const current = byCustomerMap.get(key) || {
      customerUserId: customerIdKey || null,
      customerName: customerUser?.name || "Customer",
      deliveredDays: 0,
      totalQuantityLitres: 0,
      averageQuantityLitres: 0,
      totalRupees: 0,
      paidRupees: 0,
      pendingRupees: 0,
      milkCard: [],
    };

    current.customerName =
      customerUser?.name || current.customerName || "Customer";
    current.deliveredDays += 1;
    current.totalQuantityLitres = normalizeRupees(
      current.totalQuantityLitres + normalizedQuantityLitres,
    );
    const logTotalRupees = readTotalPriceRupees(log);
    current.totalRupees = normalizeRupees(current.totalRupees + logTotalRupees);
    const paidFromTransaction = normalizeRupees(
      paidByCustomerUserId.get(String(customerUser?._id || customerIdKey)) || 0,
    );
    current.paidRupees = paidFromTransaction;
    current.pendingRupees = normalizeRupees(
      Math.max(0, current.totalRupees - current.paidRupees),
    );
    current.averageQuantityLitres =
      current.deliveredDays > 0
        ? normalizeRupees(current.totalQuantityLitres / current.deliveredDays)
        : 0;
    current.milkCard.push({
      dateKey: log.dateKey,
      quantityLitres: normalizeRupees(normalizedQuantityLitres),
      totalRupees: normalizeRupees(logTotalRupees),
      delivered: Boolean(log.delivered),
      adjustedManually: Boolean(log.adjustedManually),
    });
    byCustomerMap.set(key, current);
  }

  const customers = Array.from(byCustomerMap.values()).sort(
    (a, b) => b.totalRupees - a.totalRupees,
  );
  const paidRupees = normalizeRupees(
    customers.reduce((sum, item) => sum + Number(item.paidRupees || 0), 0),
  );
  const pendingRupees = normalizeRupees(
    customers.reduce((sum, item) => sum + Number(item.pendingRupees || 0), 0),
  );

  return {
    month: monthKey,
    summary: {
      deliveredLogs: logs.length,
      totalQuantityLitres: normalizeRupees(totalQuantityLitres),
      totalRupees: normalizeRupees(totalRupees),
      paidRupees,
      pendingRupees,
    },
    customers,
  };
}

async function getLedgerLogsForSeller(sellerFirebaseUid, month) {
  const monthKey = normalizeMonthKey(month);

  const logs = await DeliveryLogModel.find({
    sellerFirebaseUid,
    dateKey: { $regex: `^${monthKey}-` },
  })
    .sort({ dateKey: -1, createdAt: -1 })
    .lean();

  const customerObjectIds = logs
    .map((log) => log.customerId)
    .filter((value) => mongoose.Types.ObjectId.isValid(String(value || "")))
    .map((value) => String(value));
  const customerFirebaseUids = logs
    .map((log) => String(log.customerFirebaseUid || "").trim())
    .filter(Boolean);

  const userQueryParts = [];
  if (customerObjectIds.length) {
    userQueryParts.push({
      _id: {
        $in: customerObjectIds.map((id) => new mongoose.Types.ObjectId(id)),
      },
    });
  }
  if (customerFirebaseUids.length) {
    userQueryParts.push({ firebaseUid: { $in: customerFirebaseUids } });
  }

  const users = userQueryParts.length
    ? await UserModel.find({ $or: userQueryParts })
        .select("_id firebaseUid name")
        .lean()
    : [];

  const userById = new Map(users.map((user) => [String(user._id), user]));
  const userByFirebaseUid = new Map(
    users.map((user) => [String(user.firebaseUid || ""), user]),
  );

  const enrichedLogs = logs.map((log) => {
    const customerIdKey = String(log.customerId || "");
    const customerFirebaseUidKey = String(log.customerFirebaseUid || "");
    const user =
      userById.get(customerIdKey) ||
      userByFirebaseUid.get(customerFirebaseUidKey);

    return {
      ...log,
      customerName: user?.name || "Customer",
    };
  });

  return {
    month: monthKey,
    logs: enrichedLogs,
    count: enrichedLogs.length,
  };
}

async function getCustomerByFirebaseUid(customerFirebaseUid) {
  const customerUser = await UserModel.findOne({
    firebaseUid: customerFirebaseUid,
    role: "customer",
    isActive: true,
  })
    .select("_id firebaseUid")
    .lean();

  if (!customerUser) {
    throw new AppError(
      404,
      "CUSTOMER_NOT_FOUND",
      "Customer profile not found.",
    );
  }

  return customerUser;
}

function normalizeDisputeType(disputeType) {
  const normalized = String(disputeType || "")
    .trim()
    .toLowerCase();
  if (!normalized) {
    return "other";
  }

  if (!deliveryDisputeTypeEnum.includes(normalized)) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      `disputeType must be one of: ${deliveryDisputeTypeEnum.join(", ")}.`,
    );
  }

  return normalized;
}

async function openDisputeForCustomer({
  customerFirebaseUid,
  logId,
  disputeType,
  message,
}) {
  if (!mongoose.Types.ObjectId.isValid(String(logId || ""))) {
    throw new AppError(400, "VALIDATION_ERROR", "Invalid log id.");
  }

  const normalizedMessage = normalizeOptionalText(message);
  if (!normalizedMessage) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      "message is required for raising a dispute.",
    );
  }

  const customerUser = await getCustomerByFirebaseUid(customerFirebaseUid);
  const log = await DeliveryLogModel.findOne({
    _id: logId,
    customerFirebaseUid,
  }).lean();

  if (!log) {
    throw new AppError(404, "LOG_NOT_FOUND", "Delivery log not found.");
  }

  const dispute = await DeliveryDisputeModel.create({
    deliveryLogId: log._id,
    customerId: customerUser._id,
    customerFirebaseUid,
    sellerFirebaseUid: log.sellerFirebaseUid,
    dateKey: log.dateKey,
    disputeType: normalizeDisputeType(disputeType),
    message: normalizedMessage,
  });

  await createDeliveryAuditEntry({
    action: "dispute_opened",
    actorFirebaseUid: customerFirebaseUid,
    actorRole: "customer",
    log,
    reason: normalizedMessage,
    metadata: {
      disputeId: String(dispute._id),
      disputeType: dispute.disputeType,
    },
  });

  return dispute.toObject();
}

async function listDisputesForCustomer({
  customerFirebaseUid,
  status,
  page,
  limit,
}) {
  const query = { customerFirebaseUid };
  const normalizedStatus = String(status || "")
    .trim()
    .toLowerCase();

  if (normalizedStatus) {
    query.status = normalizedStatus;
  }

  const pagination = parsePaginationParams({
    page,
    limit,
    defaultLimit: 20,
    maxLimit: 100,
  });

  const [disputes, totalCount] = await Promise.all([
    DeliveryDisputeModel.find(query)
      .select(
        "_id deliveryLogId dateKey disputeType message status resolutionNote resolvedAt createdAt updatedAt",
      )
      .sort({ createdAt: -1 })
      .skip(pagination.skip)
      .limit(pagination.limit)
      .lean(),
    DeliveryDisputeModel.countDocuments(query),
  ]);

  return {
    disputes,
    count: disputes.length,
    totalCount,
    pagination: buildPaginationMeta({
      page: pagination.page,
      limit: pagination.limit,
      totalItems: totalCount,
      returnedItems: disputes.length,
    }),
  };
}

async function listDisputesForSeller({
  sellerFirebaseUid,
  status,
  page,
  limit,
}) {
  const query = { sellerFirebaseUid };
  const normalizedStatus = String(status || "")
    .trim()
    .toLowerCase();

  if (normalizedStatus) {
    query.status = normalizedStatus;
  }

  const pagination = parsePaginationParams({
    page,
    limit,
    defaultLimit: 20,
    maxLimit: 100,
  });

  const [disputes, totalCount] = await Promise.all([
    DeliveryDisputeModel.find(query)
      .select(
        "_id deliveryLogId dateKey disputeType message status resolutionNote resolvedAt createdAt updatedAt",
      )
      .sort({ createdAt: -1 })
      .skip(pagination.skip)
      .limit(pagination.limit)
      .lean(),
    DeliveryDisputeModel.countDocuments(query),
  ]);

  return {
    disputes,
    count: disputes.length,
    totalCount,
    pagination: buildPaginationMeta({
      page: pagination.page,
      limit: pagination.limit,
      totalItems: totalCount,
      returnedItems: disputes.length,
    }),
  };
}

async function resolveDisputeForSeller({
  sellerFirebaseUid,
  disputeId,
  status,
  resolutionNote,
}) {
  const normalizedStatus = String(status || "")
    .trim()
    .toLowerCase();
  if (!["resolved", "rejected"].includes(normalizedStatus)) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      "status must be either resolved or rejected.",
    );
  }

  const dispute = await DeliveryDisputeModel.findOne({
    _id: disputeId,
    sellerFirebaseUid,
  });

  if (!dispute) {
    throw new AppError(404, "DISPUTE_NOT_FOUND", "Delivery dispute not found.");
  }

  if (dispute.status !== "open") {
    throw new AppError(
      409,
      "DISPUTE_ALREADY_REVIEWED",
      "This dispute has already been reviewed.",
    );
  }

  dispute.status = normalizedStatus;
  dispute.resolutionNote = normalizeOptionalText(resolutionNote);
  dispute.resolvedByFirebaseUid = sellerFirebaseUid;
  dispute.resolvedAt = new Date();
  await dispute.save();

  const log = await DeliveryLogModel.findById(dispute.deliveryLogId).lean();
  await createDeliveryAuditEntry({
    action:
      normalizedStatus === "resolved" ? "dispute_resolved" : "dispute_rejected",
    actorFirebaseUid: sellerFirebaseUid,
    actorRole: "seller",
    log,
    reason: dispute.resolutionNote,
    metadata: {
      disputeId: String(dispute._id),
      status: normalizedStatus,
    },
  });

  return dispute.toObject();
}

async function requestPastLogCorrectionBySeller({
  sellerFirebaseUid,
  logId,
  requestedSlot,
  requestedQuantityLitres,
  reason,
}) {
  if (!mongoose.Types.ObjectId.isValid(String(logId || ""))) {
    throw new AppError(400, "VALIDATION_ERROR", "Invalid log id.");
  }

  const normalizedReason = normalizeOptionalText(reason);
  if (!normalizedReason) {
    throw new AppError(400, "VALIDATION_ERROR", "reason is required.");
  }

  const slot = String(requestedSlot || "")
    .trim()
    .toLowerCase();
  if (!["morning", "evening"].includes(slot)) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      "requestedSlot must be morning or evening.",
    );
  }

  const quantity = normalizeQuantity(requestedQuantityLitres);
  const todayDateKey = getTodayDateKey();

  const log = await DeliveryLogModel.findOne({
    _id: logId,
    sellerFirebaseUid,
  }).lean();

  if (!log) {
    throw new AppError(404, "LOG_NOT_FOUND", "Delivery log not found.");
  }

  if (String(log.dateKey) === todayDateKey) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      "Use adjust-log for today's records. Correction request is only for locked dates.",
    );
  }

  const existingPending = await DeliveryCorrectionRequestModel.findOne({
    deliveryLogId: log._id,
    status: "pending",
  })
    .select("_id")
    .lean();

  if (existingPending) {
    throw new AppError(
      409,
      "CORRECTION_ALREADY_PENDING",
      "A pending correction request already exists for this entry.",
    );
  }

  const request = await DeliveryCorrectionRequestModel.create({
    deliveryLogId: log._id,
    customerId: log.customerId,
    customerFirebaseUid: log.customerFirebaseUid,
    sellerFirebaseUid,
    dateKey: log.dateKey,
    requestedSlot: slot,
    requestedQuantityLitres: quantity,
    reason: normalizedReason,
  });

  await createDeliveryAuditEntry({
    action: "correction_requested",
    actorFirebaseUid: sellerFirebaseUid,
    actorRole: "seller",
    log,
    reason: normalizedReason,
    metadata: {
      correctionRequestId: String(request._id),
      requestedSlot: slot,
      requestedQuantityLitres: quantity,
    },
  });

  return request.toObject();
}

async function listCorrectionRequestsForSeller(sellerFirebaseUid, status) {
  const query = { sellerFirebaseUid };
  const normalizedStatus = String(status || "")
    .trim()
    .toLowerCase();

  if (normalizedStatus) {
    query.status = normalizedStatus;
  }

  const requests = await DeliveryCorrectionRequestModel.find(query)
    .sort({ createdAt: -1 })
    .lean();

  return {
    requests,
    count: requests.length,
  };
}

async function listCorrectionRequestsForCustomer(customerFirebaseUid, status) {
  const query = { customerFirebaseUid };
  const normalizedStatus = String(status || "")
    .trim()
    .toLowerCase();

  if (normalizedStatus) {
    query.status = normalizedStatus;
  }

  const requests = await DeliveryCorrectionRequestModel.find(query)
    .sort({ createdAt: -1 })
    .lean();

  return {
    requests,
    count: requests.length,
  };
}

async function reviewCorrectionRequestByCustomer({
  customerFirebaseUid,
  requestId,
  approve,
  reviewNote,
}) {
  const request = await DeliveryCorrectionRequestModel.findOne({
    _id: requestId,
    customerFirebaseUid,
  });

  if (!request) {
    throw new AppError(
      404,
      "CORRECTION_REQUEST_NOT_FOUND",
      "Correction request not found.",
    );
  }

  if (request.status !== "pending") {
    throw new AppError(
      409,
      "CORRECTION_ALREADY_REVIEWED",
      "This correction request has already been reviewed.",
    );
  }

  const note = normalizeOptionalText(reviewNote);
  const nextStatus = approve ? "approved" : "rejected";

  const log = await DeliveryLogModel.findById(request.deliveryLogId);
  if (!log) {
    throw new AppError(404, "LOG_NOT_FOUND", "Delivery log not found.");
  }

  request.status = nextStatus;
  request.reviewedByFirebaseUid = customerFirebaseUid;
  request.reviewNote = note;
  request.reviewedAt = new Date();
  await request.save();

  const beforeSnapshot = serializeLogSnapshot(log.toObject());
  if (approve) {
    const slot = request.requestedSlot;
    const quantity = normalizeQuantity(request.requestedQuantityLitres);

    if (slot === "morning") {
      log.morningQuantityLitres = quantity;
    } else {
      log.eveningQuantityLitres = quantity;
    }

    const totalQuantityLitres = Number(
      (
        normalizeStoredSlotQuantity(log.morningQuantityLitres) +
        normalizeStoredSlotQuantity(log.eveningQuantityLitres)
      ).toFixed(3),
    );

    log.deliverySlot = slot;
    log.quantityLitres = totalQuantityLitres;
    log.totalPriceRupees = asRupees(
      readBasePricePerLitreRupees(log),
      totalQuantityLitres,
    );
    log.delivered = totalQuantityLitres > 0;
    log.adjustedManually = true;
    await log.save();

    await createDeliveryAuditEntry({
      action: "correction_approved",
      actorFirebaseUid: customerFirebaseUid,
      actorRole: "customer",
      log,
      reason: note,
      before: beforeSnapshot,
      after: serializeLogSnapshot(log.toObject()),
      metadata: {
        correctionRequestId: String(request._id),
      },
    });
  } else {
    await createDeliveryAuditEntry({
      action: "correction_rejected",
      actorFirebaseUid: customerFirebaseUid,
      actorRole: "customer",
      log,
      reason: note,
      before: beforeSnapshot,
      after: beforeSnapshot,
      metadata: {
        correctionRequestId: String(request._id),
      },
    });
  }

  return {
    request: request.toObject(),
    log: log.toObject(),
  };
}

async function listAuditEntriesForCustomer({
  customerFirebaseUid,
  logId,
  page,
  limit,
}) {
  const query = { customerFirebaseUid };

  if (logId) {
    if (!mongoose.Types.ObjectId.isValid(String(logId))) {
      throw new AppError(400, "VALIDATION_ERROR", "Invalid log id.");
    }
    query.deliveryLogId = logId;
  }

  const pagination = parsePaginationParams({
    page,
    limit,
    defaultLimit: 30,
    maxLimit: 100,
  });

  const [entries, totalCount] = await Promise.all([
    DeliveryAuditModel.find(query)
      .select(
        "_id deliveryLogId dateKey deliverySlot action actorRole reason before after metadata createdAt",
      )
      .sort({ createdAt: -1 })
      .skip(pagination.skip)
      .limit(pagination.limit)
      .lean(),
    DeliveryAuditModel.countDocuments(query),
  ]);

  return {
    entries,
    count: entries.length,
    totalCount,
    pagination: buildPaginationMeta({
      page: pagination.page,
      limit: pagination.limit,
      totalItems: totalCount,
      returnedItems: entries.length,
    }),
  };
}

async function listAuditEntriesForSeller({
  sellerFirebaseUid,
  logId,
  customerFirebaseUid,
  page,
  limit,
}) {
  const query = { sellerFirebaseUid };

  if (customerFirebaseUid) {
    query.customerFirebaseUid = String(customerFirebaseUid).trim();
  }

  if (logId) {
    if (!mongoose.Types.ObjectId.isValid(String(logId))) {
      throw new AppError(400, "VALIDATION_ERROR", "Invalid log id.");
    }
    query.deliveryLogId = logId;
  }

  const pagination = parsePaginationParams({
    page,
    limit,
    defaultLimit: 30,
    maxLimit: 100,
  });

  const [entries, totalCount] = await Promise.all([
    DeliveryAuditModel.find(query)
      .select(
        "_id deliveryLogId customerId customerFirebaseUid sellerFirebaseUid dateKey deliverySlot action actorRole reason before after metadata createdAt",
      )
      .sort({ createdAt: -1 })
      .skip(pagination.skip)
      .limit(pagination.limit)
      .lean(),
    DeliveryAuditModel.countDocuments(query),
  ]);

  return {
    entries,
    count: entries.length,
    totalCount,
    pagination: buildPaginationMeta({
      page: pagination.page,
      limit: pagination.limit,
      totalItems: totalCount,
      returnedItems: entries.length,
    }),
  };
}

module.exports = {
  getDailySheetForSeller,
  deliverCustomerForSeller,
  bulkDeliverForSeller,
  adjustLogForSeller,
  getMilkSettingsForSeller,
  updateMilkBasePriceForSeller,
  updateCustomerDefaultQuantityForSeller,
  getLedgerForCustomer,
  getMonthlySummaryForCustomer,
  getMonthlySummaryForSeller,
  getLedgerLogsForSeller,
  openDisputeForCustomer,
  listDisputesForCustomer,
  listDisputesForSeller,
  resolveDisputeForSeller,
  requestPastLogCorrectionBySeller,
  listCorrectionRequestsForSeller,
  listCorrectionRequestsForCustomer,
  reviewCorrectionRequestByCustomer,
  listAuditEntriesForCustomer,
  listAuditEntriesForSeller,
};
