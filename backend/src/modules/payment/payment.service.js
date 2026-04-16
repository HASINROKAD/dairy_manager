const crypto = require("crypto");
const Razorpay = require("razorpay");

const { AppError } = require("../../common/errors/AppError");
const { env } = require("../../config/env");
const { PaymentTransactionModel } = require("./payment.model");
const { PaymentWebhookEventModel } = require("./paymentWebhookEvent.model");

let razorpayClient = null;

function hasUsableSecret(value) {
  const normalized = String(value || "").trim();
  if (!normalized) {
    return false;
  }

  return !/not\s+found/i.test(normalized);
}

function mapRazorpayStatus(status) {
  const normalized = String(status || "")
    .trim()
    .toLowerCase();
  if (!normalized) {
    return "webhook_received";
  }

  if (normalized === "created") {
    return "created";
  }

  if (normalized === "authorized") {
    return "authorized";
  }

  if (normalized === "captured") {
    return "captured";
  }

  if (normalized === "paid") {
    return "paid";
  }

  if (normalized === "failed") {
    return "failed";
  }

  return "webhook_received";
}

function mapWebhookEventStatus(eventName, paymentStatus, orderStatus) {
  const normalizedEvent = String(eventName || "")
    .trim()
    .toLowerCase();

  if (
    normalizedEvent === "payment.captured" ||
    normalizedEvent === "order.paid"
  ) {
    return "captured";
  }

  if (normalizedEvent === "payment.authorized") {
    return "authorized";
  }

  if (normalizedEvent === "payment.failed") {
    return "failed";
  }

  return mapRazorpayStatus(paymentStatus || orderStatus);
}

function getRazorpayClient() {
  if (
    !hasUsableSecret(env.razorpayKeyId) ||
    !hasUsableSecret(env.razorpayKeySecret)
  ) {
    throw new AppError(
      500,
      "PAYMENT_GATEWAY_NOT_CONFIGURED",
      "Razorpay is not configured on the server.",
    );
  }

  if (!razorpayClient) {
    razorpayClient = new Razorpay({
      key_id: env.razorpayKeyId,
      key_secret: env.razorpayKeySecret,
    });
  }

  return razorpayClient;
}

function asPositiveNumber(value, fieldName) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      `${fieldName} must be a positive number.`,
    );
  }

  return parsed;
}

function normalizeReceipt(receipt) {
  const fallback = `dm_${Date.now()}`;
  const raw = String(receipt || fallback)
    .trim()
    .replace(/[^a-zA-Z0-9_-]/g, "");

  return raw.slice(0, 40) || fallback;
}

function createOrderDto(order, amountInRupees) {
  return {
    orderId: order.id,
    amountInPaise: Number(order.amount),
    amountInRupees,
    currency: order.currency,
    receipt: order.receipt,
    status: order.status,
    createdAt: order.created_at,
  };
}

function toTransactionDto(doc) {
  return {
    id: String(doc._id),
    orderId: doc.orderId,
    paymentId: doc.paymentId || null,
    amountInPaise: doc.amountInPaise,
    amountInRupees: doc.amountInRupees,
    currency: doc.currency,
    receipt: doc.receipt || null,
    status: doc.status,
    source: doc.source,
    verifiedAt: doc.verifiedAt || null,
    createdAt: doc.createdAt,
    updatedAt: doc.updatedAt,
  };
}

function buildSafeNotes(notes) {
  if (!notes || typeof notes !== "object" || Array.isArray(notes)) {
    return {};
  }

  const safeNotes = {};
  Object.keys(notes)
    .slice(0, 15)
    .forEach((key) => {
      safeNotes[String(key).slice(0, 40)] = String(notes[key]).slice(0, 120);
    });

  return safeNotes;
}

async function createPaymentOrder({
  user,
  amountInRupees,
  currency,
  receipt,
  notes,
  source,
}) {
  const normalizedAmountInRupees = asPositiveNumber(
    amountInRupees,
    "amountInRupees",
  );

  const amountInPaise = Math.round(normalizedAmountInRupees * 100);
  if (!Number.isInteger(amountInPaise) || amountInPaise < 100) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      "amountInRupees must be at least 1.00.",
    );
  }

  const order = await getRazorpayClient().orders.create({
    amount: amountInPaise,
    currency: (currency || "INR").trim().toUpperCase(),
    receipt: normalizeReceipt(receipt),
    notes: {
      ...buildSafeNotes(notes),
      dmUserId: user?._id ? String(user._id) : "",
      dmSource: String(source || "customer_monthly_due"),
    },
  });

  const transaction = await PaymentTransactionModel.findOneAndUpdate(
    { orderId: order.id },
    {
      $set: {
        userId: user?._id || null,
        source: String(source || "customer_monthly_due"),
        amountInPaise,
        amountInRupees: Number(normalizedAmountInRupees.toFixed(2)),
        currency: order.currency,
        receipt: order.receipt || null,
        status: mapRazorpayStatus(order.status),
        notes: buildSafeNotes(notes),
      },
      $setOnInsert: {
        provider: "razorpay",
        paymentId: null,
      },
    },
    { new: true, upsert: true },
  );

  return {
    ...createOrderDto(order, normalizedAmountInRupees),
    transaction: toTransactionDto(transaction),
  };
}

async function verifyPaymentSignature({
  user,
  razorpayOrderId,
  razorpayPaymentId,
  razorpaySignature,
}) {
  const orderId = String(razorpayOrderId || "").trim();
  const paymentId = String(razorpayPaymentId || "").trim();
  const signature = String(razorpaySignature || "").trim();

  if (!orderId || !paymentId || !signature) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      "razorpayOrderId, razorpayPaymentId and razorpaySignature are required.",
    );
  }

  if (!hasUsableSecret(env.razorpayKeySecret)) {
    throw new AppError(
      500,
      "PAYMENT_GATEWAY_NOT_CONFIGURED",
      "Razorpay secret is not configured on the server.",
    );
  }

  const digest = crypto
    .createHmac("sha256", env.razorpayKeySecret)
    .update(`${orderId}|${paymentId}`)
    .digest("hex");

  const isValid = digest === signature;

  if (!isValid) {
    throw new AppError(
      400,
      "INVALID_PAYMENT_SIGNATURE",
      "Payment signature verification failed.",
    );
  }

  const existing = await PaymentTransactionModel.findOne({ orderId });
  if (
    existing?.userId &&
    user?._id &&
    String(existing.userId) !== String(user._id)
  ) {
    throw new AppError(
      403,
      "FORBIDDEN",
      "This payment order does not belong to the authenticated user.",
    );
  }

  const transaction = await PaymentTransactionModel.findOneAndUpdate(
    { orderId },
    {
      $set: {
        userId: existing?.userId || user?._id || null,
        paymentId,
        razorpaySignature: signature,
        status: "verified",
        verificationMethod: "client_signature",
        verifiedAt: new Date(),
      },
      $setOnInsert: {
        provider: "razorpay",
        source: "customer_monthly_due",
        amountInPaise: 0,
        amountInRupees: 0,
        currency: "INR",
        receipt: null,
        notes: {},
      },
    },
    { new: true, upsert: true },
  );

  return {
    verified: true,
    razorpayOrderId: orderId,
    razorpayPaymentId: paymentId,
    transaction: toTransactionDto(transaction),
  };
}

function getPaymentConfig() {
  if (!hasUsableSecret(env.razorpayKeyId)) {
    throw new AppError(
      500,
      "PAYMENT_GATEWAY_NOT_CONFIGURED",
      "Razorpay key id is not configured on the server.",
    );
  }

  return {
    razorpayKeyId: String(env.razorpayKeyId).trim(),
  };
}

function verifyWebhookSignature(rawBody, signature) {
  if (!hasUsableSecret(env.razorpayWebhookSecret)) {
    throw new AppError(
      500,
      "PAYMENT_GATEWAY_NOT_CONFIGURED",
      "Razorpay webhook secret is not configured on the server.",
    );
  }

  const provided = String(signature || "").trim();
  if (!provided) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      "Missing x-razorpay-signature header.",
    );
  }

  const expected = crypto
    .createHmac("sha256", String(env.razorpayWebhookSecret).trim())
    .update(rawBody)
    .digest("hex");

  const providedBuffer = Buffer.from(provided, "utf8");
  const expectedBuffer = Buffer.from(expected, "utf8");

  const isValid =
    providedBuffer.length === expectedBuffer.length &&
    crypto.timingSafeEqual(providedBuffer, expectedBuffer);

  if (!isValid) {
    throw new AppError(
      400,
      "INVALID_WEBHOOK_SIGNATURE",
      "Webhook signature verification failed.",
    );
  }
}

async function processWebhookEvent({ rawBody, signature, eventId }) {
  verifyWebhookSignature(rawBody, signature);

  let payload;
  try {
    payload = JSON.parse(rawBody.toString("utf8"));
  } catch (_error) {
    throw new AppError(400, "VALIDATION_ERROR", "Invalid webhook payload.");
  }

  const eventName = String(payload?.event || "").trim();
  const normalizedEventId = String(eventId || "").trim();
  if (!normalizedEventId) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      "Missing x-razorpay-event-id header.",
    );
  }

  const payloadHash = crypto.createHash("sha256").update(rawBody).digest("hex");

  let webhookEventRecord;
  try {
    webhookEventRecord = await PaymentWebhookEventModel.create({
      provider: "razorpay",
      eventId: normalizedEventId,
      eventName: eventName || null,
      payloadHash,
      status: "processing",
    });
  } catch (error) {
    if (error?.code === 11000) {
      return {
        processed: true,
        duplicate: true,
        eventId: normalizedEventId,
        event: eventName || null,
        reason: "Duplicate webhook event ignored.",
      };
    }
    throw error;
  }

  const paymentEntity = payload?.payload?.payment?.entity || null;
  const orderEntity = payload?.payload?.order?.entity || null;

  const orderId = String(
    paymentEntity?.order_id || orderEntity?.id || "",
  ).trim();
  const paymentId = String(paymentEntity?.id || "").trim();

  if (!orderId && !paymentId) {
    await PaymentWebhookEventModel.findByIdAndUpdate(webhookEventRecord._id, {
      $set: {
        status: "processed",
        processedAt: new Date(),
      },
    });

    return {
      processed: false,
      duplicate: false,
      eventId: normalizedEventId,
      reason: "No order id or payment id found in webhook payload.",
      event: eventName,
    };
  }

  const amountInPaise = Number(
    paymentEntity?.amount || orderEntity?.amount || 0,
  );
  const normalizedAmountInPaise = Number.isFinite(amountInPaise)
    ? Math.max(0, Math.round(amountInPaise))
    : 0;
  const amountInRupees = Number((normalizedAmountInPaise / 100).toFixed(2));

  const status = mapWebhookEventStatus(
    eventName,
    paymentEntity?.status,
    orderEntity?.status,
  );

  const query = orderId ? { orderId } : { paymentId };

  try {
    const transaction = await PaymentTransactionModel.findOneAndUpdate(
      query,
      {
        $set: {
          orderId: orderId || `unknown_order_${Date.now()}`,
          paymentId: paymentId || null,
          amountInPaise: normalizedAmountInPaise,
          amountInRupees,
          currency: String(
            paymentEntity?.currency || orderEntity?.currency || "INR",
          ).toUpperCase(),
          receipt: orderEntity?.receipt || null,
          status,
          verificationMethod: "webhook",
          verifiedAt: status === "failed" ? null : new Date(),
          webhookLastEventId: normalizedEventId,
          webhookLastEvent: eventName || null,
          webhookLastReceivedAt: new Date(),
          metadata: {
            event: eventName,
            orderStatus: orderEntity?.status || null,
            paymentStatus: paymentEntity?.status || null,
            method: paymentEntity?.method || null,
            fee: paymentEntity?.fee || null,
            tax: paymentEntity?.tax || null,
          },
        },
        $setOnInsert: {
          provider: "razorpay",
          source: "customer_monthly_due",
          notes: {},
        },
      },
      { new: true, upsert: true },
    );

    await PaymentWebhookEventModel.findByIdAndUpdate(webhookEventRecord._id, {
      $set: {
        status: "processed",
        processedAt: new Date(),
        transactionId: transaction._id,
      },
    });

    return {
      processed: true,
      duplicate: false,
      eventId: normalizedEventId,
      event: eventName,
      transaction: toTransactionDto(transaction),
    };
  } catch (error) {
    await PaymentWebhookEventModel.findByIdAndUpdate(webhookEventRecord._id, {
      $set: {
        status: "failed",
        processedAt: new Date(),
        errorMessage: String(error?.message || "Webhook processing failed."),
      },
    });

    throw error;
  }
}

module.exports = {
  createPaymentOrder,
  verifyPaymentSignature,
  getPaymentConfig,
  processWebhookEvent,
};
