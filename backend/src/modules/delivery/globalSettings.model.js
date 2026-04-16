const mongoose = require("mongoose");

const globalSettingsSchema = new mongoose.Schema(
  {
    key: { type: String, required: true, unique: true, default: "global" },
    basePricePerLitreRupees: {
      type: Number,
      required: true,
      min: 0,
      default: 60,
    },
  },
  {
    timestamps: true,
    versionKey: false,
  },
);

const GlobalSettingsModel = mongoose.model(
  "GlobalSettings",
  globalSettingsSchema,
);

module.exports = { GlobalSettingsModel };
