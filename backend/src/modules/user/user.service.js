const { AppError } = require("../../common/errors/AppError");
const { env } = require("../../config/env");
const { initializeFirebase } = require("../../config/firebase");
const { UserModel, USER_ROLES } = require("./user.model");
const { SellerProfileModel } = require("../seller/sellerProfile.model");
const { CustomerProfileModel } = require("../customer/customerProfile.model");

async function syncFirebaseRoleClaim(firebaseUid, role) {
  const admin = initializeFirebase();
  await admin.auth().setCustomUserClaims(firebaseUid, { role });
}

function validateOnboarding(payload) {
  const errors = [];

  if (!payload.name || payload.name.trim().length < 2) {
    errors.push("name must be at least 2 characters.");
  }

  const phoneRegex = /^\+[1-9]\d{7,14}$/;
  if (!payload.mobileNumber || !phoneRegex.test(payload.mobileNumber.trim())) {
    errors.push("mobileNumber must be in E.164 format.");
  }

  if (!USER_ROLES.includes(payload.role)) {
    errors.push("role must be either seller or customer.");
  }

  if (errors.length) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      "Invalid onboarding payload.",
      errors,
    );
  }
}

async function completeOnboarding(userId, payload) {
  validateOnboarding(payload);

  const user = await UserModel.findById(userId);
  if (!user) {
    throw new AppError(404, "USER_NOT_FOUND", "User not found.");
  }

  if (user.role && user.role !== payload.role && !env.allowRoleSwitch) {
    throw new AppError(
      409,
      "ROLE_LOCKED",
      "Role is already set and role switching is disabled.",
    );
  }

  user.name = payload.name.trim();
  user.mobileNumber = payload.mobileNumber.trim();
  user.role = payload.role;
  user.profileCompleted = true;

  await user.save();
  await syncFirebaseRoleClaim(user.firebaseUid, user.role);
  return user;
}

async function updateRole(userId, role) {
  if (!USER_ROLES.includes(role)) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      "role must be seller or customer.",
    );
  }

  const user = await UserModel.findById(userId);
  if (!user) {
    throw new AppError(404, "USER_NOT_FOUND", "User not found.");
  }

  if (user.role && user.role !== role && !env.allowRoleSwitch) {
    throw new AppError(409, "ROLE_LOCKED", "Role switch is disabled.");
  }

  user.role = role;
  await user.save();
  await syncFirebaseRoleClaim(user.firebaseUid, user.role);
  return user;
}

function validateProfileUpdatePayload(payload) {
  const errors = [];

  if (!payload.name || payload.name.trim().length < 2) {
    errors.push("name must be at least 2 characters.");
  }

  const phoneRegex = /^\+[1-9]\d{7,14}$/;
  if (!payload.mobileNumber || !phoneRegex.test(payload.mobileNumber.trim())) {
    errors.push("mobileNumber must be in E.164 format.");
  }

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
      "Invalid profile update payload.",
      errors,
    );
  }

  return { latitude, longitude };
}

function getProfileModelByRole(role) {
  if (role === "seller") {
    return SellerProfileModel;
  }

  if (role === "customer") {
    return CustomerProfileModel;
  }

  throw new AppError(
    400,
    "ROLE_REQUIRED",
    "User role must be seller or customer before updating profile.",
  );
}

async function updateProfile(userId, payload) {
  const { latitude, longitude } = validateProfileUpdatePayload(payload);

  const user = await UserModel.findById(userId);
  if (!user) {
    throw new AppError(404, "USER_NOT_FOUND", "User not found.");
  }

  if (!user.role || !USER_ROLES.includes(user.role)) {
    throw new AppError(
      400,
      "ROLE_REQUIRED",
      "User role must be seller or customer before updating profile.",
    );
  }

  const ProfileModel = getProfileModelByRole(user.role);
  const updateData = {
    displayAddress: payload.displayAddress.trim(),
    geo: {
      type: "Point",
      coordinates: [longitude, latitude],
    },
    locationSource: "typed",
    geocodeProvider: "osm",
  };

  if (user.role === "seller") {
    updateData.shopName = payload.shopName ? payload.shopName.trim() : "";
  }

  const profile = await ProfileModel.findOneAndUpdate(
    { userId: user._id },
    { $set: updateData },
    { upsert: true, new: true, setDefaultsOnInsert: true },
  );

  user.name = payload.name.trim();
  user.mobileNumber = payload.mobileNumber.trim();
  user.profileCompleted = true;
  await user.save();

  return {
    user,
    location: {
      role: user.role,
      displayAddress: profile.displayAddress,
      latitude: profile.geo?.coordinates?.[1] ?? latitude,
      longitude: profile.geo?.coordinates?.[0] ?? longitude,
      shopName: profile.shopName || null,
    },
  };
}

module.exports = { completeOnboarding, updateRole, updateProfile };
