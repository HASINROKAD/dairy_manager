const { asyncHandler } = require("../../common/utils/asyncHandler");
const {
  resolveAddressCandidates,
  saveLocationForUser,
  getSavedLocationForUser,
} = require("./location.service");

const resolveAddress = asyncHandler(async (req, res) => {
  const candidates = await resolveAddressCandidates(req.body.query || "");

  res.status(200).json({
    success: true,
    data: candidates,
  });
});

const putMyLocation = asyncHandler(async (req, res) => {
  const profile = await saveLocationForUser(req.user, req.body);

  const coordinates = profile.geo.coordinates;

  res.status(200).json({
    success: true,
    data: {
      role: req.user.role,
      displayAddress: profile.displayAddress,
      coordinates,
      updatedAt: profile.updatedAt,
    },
  });
});

const getMyLocation = asyncHandler(async (req, res) => {
  const location = await getSavedLocationForUser(req.user);

  res.status(200).json({
    success: true,
    data: location,
  });
});

module.exports = { resolveAddress, putMyLocation, getMyLocation };
