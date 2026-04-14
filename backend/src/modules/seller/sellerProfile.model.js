const mongoose = require("mongoose");
const {
  pointSchema,
  addressComponentsSchema,
} = require("../shared/location.schema");

const sellerProfileSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      unique: true,
      ref: "User",
    },
    shopName: { type: String, trim: true, default: "" },
    isServiceAvailable: { type: Boolean, default: true },
    displayAddress: { type: String, trim: true, default: "" },
    placeId: { type: String, trim: true, default: "" },
    geo: { type: pointSchema, required: false },
    addressComponents: { type: addressComponentsSchema, required: false },
    locationSource: {
      type: String,
      enum: ["typed", "map_pin", "gps"],
      default: "typed",
    },
    geocodeProvider: {
      type: String,
      enum: ["google_places", "mapbox", "osm"],
      default: "osm",
    },
  },
  {
    timestamps: true,
    versionKey: false,
  },
);

sellerProfileSchema.index({ geo: "2dsphere" });

const SellerProfileModel = mongoose.model("SellerProfile", sellerProfileSchema);

module.exports = { SellerProfileModel };
