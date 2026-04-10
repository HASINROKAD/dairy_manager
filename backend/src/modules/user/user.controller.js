const { asyncHandler } = require("../../common/utils/asyncHandler");
const { toPublicUser } = require("./user.mapper");
const {
  completeOnboarding,
  updateRole,
  updateProfile,
} = require("./user.service");

const getMe = asyncHandler(async (req, res) => {
  res.status(200).json({
    success: true,
    data: toPublicUser(req.user),
  });
});

const patchOnboarding = asyncHandler(async (req, res) => {
  const updated = await completeOnboarding(req.user._id, req.body);

  res.status(200).json({
    success: true,
    data: toPublicUser(updated),
  });
});

const patchRole = asyncHandler(async (req, res) => {
  const updated = await updateRole(req.user._id, req.body.role);

  res.status(200).json({
    success: true,
    data: toPublicUser(updated),
  });
});

const patchProfileUpdate = asyncHandler(async (req, res) => {
  const updated = await updateProfile(req.user._id, req.body);

  res.status(200).json({
    success: true,
    data: {
      user: toPublicUser(updated.user),
      location: updated.location,
    },
  });
});

module.exports = { getMe, patchOnboarding, patchRole, patchProfileUpdate };
