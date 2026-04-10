const { AppError } = require("../../common/errors/AppError");
const { SellerProfileModel } = require("../seller/sellerProfile.model");
const { UserModel } = require("../user/user.model");

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
        displayAddress: "$displayAddress",
        distanceKm: { $round: [{ $divide: ["$distanceMeters", 1000] }, 2] },
      },
    },
  ]);

  return sellers;
}

module.exports = { findNearbySellers };
