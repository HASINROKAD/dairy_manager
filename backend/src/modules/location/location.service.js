const { AppError } = require("../../common/errors/AppError");
const { env } = require("../../config/env");
const { SellerProfileModel } = require("../seller/sellerProfile.model");
const { CustomerProfileModel } = require("../customer/customerProfile.model");

function validateLocationPayload(payload) {
  const errors = [];

  if (!payload.displayAddress || payload.displayAddress.trim().length < 4) {
    errors.push("displayAddress must be at least 4 characters.");
  }

  const latitude = Number(payload.latitude);
  const longitude = Number(payload.longitude);

  if (Number.isNaN(latitude) || latitude < -90 || latitude > 90) {
    errors.push("latitude must be between -90 and 90.");
  }

  if (Number.isNaN(longitude) || longitude < -180 || longitude > 180) {
    errors.push("longitude must be between -180 and 180.");
  }

  if (errors.length) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      "Invalid location payload.",
      errors,
    );
  }

  return { latitude, longitude };
}

function getModelByRole(role) {
  if (role === "seller") {
    return SellerProfileModel;
  }

  if (role === "customer") {
    return CustomerProfileModel;
  }

  throw new AppError(
    400,
    "ROLE_REQUIRED",
    "User role must be seller or customer before saving location.",
  );
}

async function resolveAddressCandidates(query) {
  if (!query || query.trim().length < 3) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      "query must be at least 3 characters.",
    );
  }

  const encoded = encodeURIComponent(query.trim());
  const url = `https://nominatim.openstreetmap.org/search?q=${encoded}&format=json&addressdetails=1&limit=5`;

  const response = await fetch(url, {
    headers: {
      "User-Agent": env.geocodeUserAgent,
    },
  });

  if (!response.ok) {
    throw new AppError(
      502,
      "GEOCODE_FAILED",
      "Geocoding provider request failed.",
    );
  }

  const results = await response.json();

  return results.map((item) => ({
    placeId: item.place_id?.toString() || "",
    displayAddress: item.display_name || "",
    latitude: Number(item.lat),
    longitude: Number(item.lon),
    source: "osm",
  }));
}

async function saveLocationForUser(user, payload) {
  const { latitude, longitude } = validateLocationPayload(payload);

  const ProfileModel = getModelByRole(user.role);
  const updateData = {
    displayAddress: payload.displayAddress.trim(),
    placeId: payload.placeId || "",
    geo: {
      type: "Point",
      coordinates: [longitude, latitude],
    },
    addressComponents: payload.addressComponents || undefined,
    locationSource: payload.locationSource || "typed",
    geocodeProvider: payload.geocodeProvider || "osm",
  };

  if (user.role === "seller" && payload.shopName) {
    updateData.shopName = payload.shopName.trim();
  }

  if (
    user.role === "seller" &&
    typeof payload.isServiceAvailable === "boolean"
  ) {
    updateData.isServiceAvailable = payload.isServiceAvailable;
  }

  const profile = await ProfileModel.findOneAndUpdate(
    { userId: user._id },
    { $set: updateData },
    { upsert: true, new: true, setDefaultsOnInsert: true },
  );

  return profile;
}

async function getSavedLocationForUser(user) {
  const ProfileModel = getModelByRole(user.role);
  const profile = await ProfileModel.findOne({ userId: user._id })
    .select("displayAddress placeId shopName geo")
    .lean();

  if (!profile || !profile.geo?.coordinates) {
    return null;
  }

  return {
    role: user.role,
    displayAddress: profile.displayAddress,
    latitude: profile.geo.coordinates[1],
    longitude: profile.geo.coordinates[0],
    placeId: profile.placeId || null,
    shopName: profile.shopName || null,
  };
}

module.exports = {
  resolveAddressCandidates,
  saveLocationForUser,
  getSavedLocationForUser,
};
