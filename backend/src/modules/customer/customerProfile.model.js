const mongoose = require("mongoose");
const {
  pointSchema,
  addressComponentsSchema,
} = require("../shared/location.schema");

const customerProfileSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      unique: true,
      ref: "User",
    },
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

customerProfileSchema.index({ geo: "2dsphere" });

const CustomerProfileModel = mongoose.model(
  "CustomerProfile",
  customerProfileSchema,
);

module.exports = { CustomerProfileModel };
