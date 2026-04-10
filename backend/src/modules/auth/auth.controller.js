const { asyncHandler } = require("../../common/utils/asyncHandler");
const { syncUserFromFirebase } = require("./auth.service");

const syncAuth = asyncHandler(async (req, res) => {
  const { user, createdNow, roleClaimUpdated } = await syncUserFromFirebase(
    req.auth,
  );

  res.status(200).json({
    success: true,
    data: {
      userId: user._id,
      firebaseUid: user.firebaseUid,
      phone: user.mobileNumber || null,
      role: user.role,
      profileCompleted: user.profileCompleted,
      createdNow,
      roleClaimUpdated,
      tokenRefreshRequired: roleClaimUpdated,
    },
  });
});

module.exports = { syncAuth };
