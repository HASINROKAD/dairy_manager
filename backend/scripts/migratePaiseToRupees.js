const mongoose = require("mongoose");

const { connectDb } = require("../src/config/db");
const {
  DeliveryLogModel,
} = require("../src/modules/delivery/deliveryLog.model");
const {
  GlobalSettingsModel,
} = require("../src/modules/delivery/globalSettings.model");

function parseOptions(argv) {
  const flags = new Set(argv.slice(2));
  return {
    dryRun: flags.has("--dry-run"),
    dropLegacy: flags.has("--drop-legacy"),
  };
}

async function getPreMigrationStats() {
  const [
    deliveryMissingRupees,
    deliveryWithLegacyPaise,
    settingsMissingRupees,
    settingsWithLegacyPaise,
  ] = await Promise.all([
    DeliveryLogModel.countDocuments({
      $or: [
        { basePricePerLitreRupees: { $exists: false } },
        { basePricePerLitreRupees: null },
        { totalPriceRupees: { $exists: false } },
        { totalPriceRupees: null },
      ],
    }),
    DeliveryLogModel.countDocuments({
      $or: [
        { basePricePerLitrePaise: { $exists: true } },
        { totalPricePaise: { $exists: true } },
      ],
    }),
    GlobalSettingsModel.countDocuments({
      $or: [
        { basePricePerLitreRupees: { $exists: false } },
        { basePricePerLitreRupees: null },
      ],
    }),
    GlobalSettingsModel.countDocuments({
      basePricePerLitrePaise: { $exists: true },
    }),
  ]);

  return {
    deliveryMissingRupees,
    deliveryWithLegacyPaise,
    settingsMissingRupees,
    settingsWithLegacyPaise,
  };
}

async function migrateToRupees() {
  return Promise.all([
    DeliveryLogModel.collection.updateMany({}, [
      {
        $set: {
          basePricePerLitreRupees: {
            $round: [
              {
                $ifNull: [
                  "$basePricePerLitreRupees",
                  {
                    $divide: [
                      { $ifNull: ["$basePricePerLitrePaise", 6000] },
                      100,
                    ],
                  },
                ],
              },
              2,
            ],
          },
          totalPriceRupees: {
            $round: [
              {
                $ifNull: [
                  "$totalPriceRupees",
                  {
                    $divide: [{ $ifNull: ["$totalPricePaise", 0] }, 100],
                  },
                ],
              },
              2,
            ],
          },
        },
      },
    ]),
    GlobalSettingsModel.collection.updateMany({}, [
      {
        $set: {
          basePricePerLitreRupees: {
            $round: [
              {
                $ifNull: [
                  "$basePricePerLitreRupees",
                  {
                    $divide: [
                      { $ifNull: ["$basePricePerLitrePaise", 6000] },
                      100,
                    ],
                  },
                ],
              },
              2,
            ],
          },
        },
      },
    ]),
  ]);
}

async function dropLegacyPaiseFields() {
  return Promise.all([
    DeliveryLogModel.collection.updateMany(
      {},
      { $unset: { basePricePerLitrePaise: "", totalPricePaise: "" } },
    ),
    GlobalSettingsModel.collection.updateMany(
      {},
      { $unset: { basePricePerLitrePaise: "" } },
    ),
  ]);
}

async function run() {
  const { dryRun, dropLegacy } = parseOptions(process.argv);

  await connectDb();
  console.log("Starting paise -> rupees migration...");

  const before = await getPreMigrationStats();
  console.log("Pre-migration stats:", before);

  if (dryRun) {
    console.log("Dry run only. No documents were modified.");
    return;
  }

  const [deliveryResult, settingsResult] = await migrateToRupees();
  console.log("Rupees migration applied:", {
    deliveryMatched: deliveryResult.matchedCount,
    deliveryModified: deliveryResult.modifiedCount,
    settingsMatched: settingsResult.matchedCount,
    settingsModified: settingsResult.modifiedCount,
  });

  if (dropLegacy) {
    const [deliveryDropResult, settingsDropResult] =
      await dropLegacyPaiseFields();
    console.log("Legacy paise fields removed:", {
      deliveryMatched: deliveryDropResult.matchedCount,
      deliveryModified: deliveryDropResult.modifiedCount,
      settingsMatched: settingsDropResult.matchedCount,
      settingsModified: settingsDropResult.modifiedCount,
    });
  } else {
    console.log(
      "Legacy paise fields retained. Re-run with --drop-legacy after verification.",
    );
  }

  const after = await getPreMigrationStats();
  console.log("Post-migration stats:", after);
}

run()
  .then(async () => {
    await mongoose.disconnect();
    console.log("Migration finished.");
    process.exit(0);
  })
  .catch(async (error) => {
    console.error("Migration failed:", error);
    await mongoose.disconnect();
    process.exit(1);
  });
