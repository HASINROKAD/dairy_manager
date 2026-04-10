const { AppError } = require("../../common/errors/AppError");
const { env } = require("../../config/env");
const { UserModel, USER_ROLES } = require("./user.model");

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
  return user;
}

module.exports = { completeOnboarding, updateRole };
