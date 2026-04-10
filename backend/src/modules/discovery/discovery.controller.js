const { asyncHandler } = require("../../common/utils/asyncHandler");
const { findNearbySellers } = require("./discovery.service");

const getNearbySellers = asyncHandler(async (req, res) => {
  const data = await findNearbySellers({
    latitude: req.query.lat,
    longitude: req.query.lng,
    radiusKm: req.query.radiusKm,
  });

  res.status(200).json({
    success: true,
    data,
  });
});

module.exports = { getNearbySellers };
