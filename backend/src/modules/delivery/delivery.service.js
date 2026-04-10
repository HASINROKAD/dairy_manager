const mongoose = require("mongoose");

const { AppError } = require("../../common/errors/AppError");
const { UserModel } = require("../user/user.model");
const { CustomerProfileModel } = require("../customer/customerProfile.model");
const { DeliveryLogModel } = require("./deliveryLog.model");
const { GlobalSettingsModel } = require("./globalSettings.model");
const { getTodayDateKey, asPaise } = require("./delivery.utils");

function normalizeQuantity(quantityLitres) {
  const quantity = Number(quantityLitres);
  if (Number.isNaN(quantity) || quantity <= 0) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      "quantity must be a positive number in litres.",
    );
  }

  return Math.round(quantity * 1000) / 1000;
}

async function getBasePricePerLitrePaise(session = null) {
  const settings = await GlobalSettingsModel.findOneAndUpdate(
    { key: "global" },
    { $setOnInsert: { basePricePerLitrePaise: 6000 } },
    { new: true, upsert: true, setDefaultsOnInsert: true, session },
  );

  return settings.basePricePerLitrePaise;
}

async function getDailySheetForSeller(sellerFirebaseUid) {
  const dateKey = getTodayDateKey();

  const customers = await UserModel.find({ role: "customer", isActive: true })
    .select("_id firebaseUid name email mobileNumber")
    .lean();

  const customerIds = customers.map((customer) => customer._id);

  const [profiles, logs, basePricePerLitrePaise] = await Promise.all([
    CustomerProfileModel.find({ userId: { $in: customerIds } })
      .select("userId defaultQuantityLitres")
      .lean(),
    DeliveryLogModel.find({
      sellerFirebaseUid,
      dateKey,
      customerId: { $in: customerIds },
    }).lean(),
    getBasePricePerLitrePaise(),
  ]);

  const profileByUserId = new Map(
    profiles.map((profile) => [profile.userId.toString(), profile]),
  );

  const logByCustomerId = new Map(
    logs.map((log) => [log.customerId.toString(), log]),
  );

  const sheet = customers.map((customer) => {
    const profile = profileByUserId.get(customer._id.toString());
    const log = logByCustomerId.get(customer._id.toString());

    const defaultQuantityLitres =
      profile?.defaultQuantityLitres && profile.defaultQuantityLitres > 0
        ? profile.defaultQuantityLitres
        : 1;

    return {
      customerId: customer._id,
      customerFirebaseUid: customer.firebaseUid,
      customerName: customer.name || "Customer",
      mobileNumber: customer.mobileNumber || "",
      email: customer.email || "",
      defaultQuantityLitres,
      delivered: log?.delivered ?? false,
      quantityLitres: log?.quantityLitres ?? defaultQuantityLitres,
      basePricePerLitrePaise:
        log?.basePricePerLitrePaise ?? basePricePerLitrePaise,
      totalPricePaise:
        log?.totalPricePaise ??
        asPaise(basePricePerLitrePaise, defaultQuantityLitres),
      logId: log?._id || null,
      dateKey,
    };
  });

  return { sheet, dateKey, basePricePerLitrePaise };
}

async function bulkDeliverForSeller({ sellerFirebaseUid, customerIds }) {
  if (!Array.isArray(customerIds) || !customerIds.length) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      "customerIds must be a non-empty array.",
    );
  }

  const dateKey = getTodayDateKey();
  const session = await mongoose.startSession();

  try {
    let result;
    await session.withTransaction(async () => {
      const customers = await UserModel.find({
        _id: { $in: customerIds },
        role: "customer",
        isActive: true,
      })
        .select("_id firebaseUid")
        .session(session);

      if (customers.length !== customerIds.length) {
        throw new AppError(
          400,
          "VALIDATION_ERROR",
          "Some customerIds are invalid or inactive customers.",
        );
      }

      const profileDocs = await CustomerProfileModel.find({
        userId: { $in: customers.map((customer) => customer._id) },
      })
        .select("userId defaultQuantityLitres")
        .session(session);

      const profileByUserId = new Map(
        profileDocs.map((profile) => [profile.userId.toString(), profile]),
      );

      const basePricePerLitrePaise = await getBasePricePerLitrePaise(session);
      const operations = customers.map((customer) => {
        const profile = profileByUserId.get(customer._id.toString());
        const defaultQuantityLitres =
          profile?.defaultQuantityLitres && profile.defaultQuantityLitres > 0
            ? profile.defaultQuantityLitres
            : 1;

        const quantityLitres = normalizeQuantity(defaultQuantityLitres);

        return {
          updateOne: {
            filter: {
              customerId: customer._id,
              sellerFirebaseUid,
              dateKey,
            },
            update: {
              $set: {
                customerFirebaseUid: customer.firebaseUid,
                delivered: true,
                quantityLitres,
                basePricePerLitrePaise,
                totalPricePaise: asPaise(
                  basePricePerLitrePaise,
                  quantityLitres,
                ),
                adjustedManually: false,
              },
            },
            upsert: true,
          },
        };
      });

      await DeliveryLogModel.bulkWrite(operations, { session });

      const updatedLogs = await DeliveryLogModel.find({
        customerId: { $in: customers.map((customer) => customer._id) },
        sellerFirebaseUid,
        dateKey,
      }).session(session);

      result = {
        updatedCount: updatedLogs.length,
        logs: updatedLogs,
        dateKey,
      };
    });

    return result;
  } finally {
    await session.endSession();
  }
}

async function adjustLogForSeller({
  sellerFirebaseUid,
  logId,
  quantityLitres,
}) {
  const quantity = normalizeQuantity(quantityLitres);
  const basePricePerLitrePaise = await getBasePricePerLitrePaise();

  const log = await DeliveryLogModel.findOne({
    _id: logId,
    sellerFirebaseUid,
  });

  if (!log) {
    throw new AppError(404, "LOG_NOT_FOUND", "Delivery log not found.");
  }

  log.quantityLitres = quantity;
  log.basePricePerLitrePaise = basePricePerLitrePaise;
  log.totalPricePaise = asPaise(basePricePerLitrePaise, quantity);
  log.adjustedManually = true;
  log.delivered = true;

  await log.save();
  return log;
}

async function getLedgerForCustomer(customerFirebaseUid) {
  const logs = await DeliveryLogModel.find({ customerFirebaseUid })
    .sort({ dateKey: -1, createdAt: -1 })
    .lean();

  const totalPaise = logs.reduce(
    (sum, log) => sum + Number(log.totalPricePaise || 0),
    0,
  );

  return {
    logs,
    summary: {
      count: logs.length,
      totalPaise,
    },
  };
}

module.exports = {
  getDailySheetForSeller,
  bulkDeliverForSeller,
  adjustLogForSeller,
  getLedgerForCustomer,
};
