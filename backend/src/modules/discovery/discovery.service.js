const { AppError } = require("../../common/errors/AppError");
const { GlobalSettingsModel } = require("../delivery/globalSettings.model");
const { SellerProfileModel } = require("../seller/sellerProfile.model");
const { UserModel } = require("../user/user.model");

const NEARBY_SELLERS_CACHE_TTL_MS = 20000;
const nearbySellersCache = new Map();

function buildNearbySellersCacheKey({ lat, lng, radius }) {
  return `${lat.toFixed(4)}:${lng.toFixed(4)}:${radius.toFixed(2)}`;
}

function getCachedNearbySellers(cacheKey) {
  const cached = nearbySellersCache.get(cacheKey);
  if (!cached) {
    return null;
  }

  if (cached.expiresAt <= Date.now()) {
    nearbySellersCache.delete(cacheKey);
    return null;
  }

  return cached.data.map((item) => ({ ...item }));
}

function setCachedNearbySellers(cacheKey, sellers) {
  nearbySellersCache.set(cacheKey, {
    data: sellers.map((item) => ({ ...item })),
    expiresAt: Date.now() + NEARBY_SELLERS_CACHE_TTL_MS,
  });
}

async function findNearbySellers({ latitude, longitude, radiusKm }) {
  const lat = Number(latitude);
  const lng = Number(longitude);
  const radius = Number(radiusKm || 5);

  if (Number.isNaN(lat) || Number.isNaN(lng)) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      "lat and lng are required numeric values.",
    );
  }

  if (radius <= 0 || radius > 10) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      "radiusKm must be > 0 and <= 10.",
    );
  }

  const cacheKey = buildNearbySellersCacheKey({ lat, lng, radius });
  const cached = getCachedNearbySellers(cacheKey);
  if (cached) {
    return cached;
  }

  const radiusMeters = radius * 1000;
  const sellers = await SellerProfileModel.aggregate([
    {
      $geoNear: {
        near: { type: "Point", coordinates: [lng, lat] },
        distanceField: "distanceMeters",
        maxDistance: radiusMeters,
        spherical: true,
      },
    },
    {
      $lookup: {
        from: UserModel.collection.name,
        localField: "userId",
        foreignField: "_id",
        as: "user",
      },
    },
    { $unwind: "$user" },
    {
      $match: {
        "user.role": "seller",
        "user.profileCompleted": true,
        "user.isActive": true,
      },
    },
    {
      $project: {
        _id: 0,
        sellerUserId: "$user._id",
        name: "$user.name",
        shopName: { $ifNull: ["$shopName", ""] },
        displayAddress: "$displayAddress",
        isServiceAvailable: { $ifNull: ["$isServiceAvailable", true] },
        distanceKm: { $round: [{ $divide: ["$distanceMeters", 1000] }, 2] },
      },
    },
  ]);

  if (sellers.length === 0) {
    setCachedNearbySellers(cacheKey, []);
    return [];
  }

  const priceSettings = await GlobalSettingsModel.find({
    key: {
      $in: sellers.map((seller) => `seller:${String(seller.sellerUserId)}`),
    },
  })
    .select("key basePricePerLitreRupees")
    .lean();

  const priceByKey = new Map(
    priceSettings.map((item) => [
      String(item.key),
      Number.isFinite(Number(item.basePricePerLitreRupees))
        ? Number(Number(item.basePricePerLitreRupees).toFixed(2))
        : 60,
    ]),
  );

  const result = sellers.map((seller) => {
    const key = `seller:${String(seller.sellerUserId)}`;
    return {
      ...seller,
      basePricePerLitreRupees: priceByKey.get(key) ?? 60,
    };
  });

  setCachedNearbySellers(cacheKey, result);
  return result;
}

module.exports = { findNearbySellers };
