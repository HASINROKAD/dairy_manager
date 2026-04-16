const { asyncHandler } = require("../../common/utils/asyncHandler");
const {
  createPaymentOrder,
  verifyPaymentSignature,
  getPaymentConfig,
  processWebhookEvent,
} = require("./payment.service");

const getRazorpayConfig = asyncHandler(async (_req, res) => {
  const data = getPaymentConfig();

  res.status(200).json({
    success: true,
    data,
  });
});

const postCreateOrder = asyncHandler(async (req, res) => {
  const data = await createPaymentOrder({
    user: req.user,
    amountInRupees: req.body.amountInRupees,
    currency: req.body.currency,
    receipt: req.body.receipt,
    notes: req.body.notes,
    source: req.body.source,
  });

  res.status(201).json({
    success: true,
    data,
  });
});

const postVerifyPayment = asyncHandler(async (req, res) => {
  const data = await verifyPaymentSignature({
    user: req.user,
    razorpayOrderId: req.body.razorpayOrderId,
    razorpayPaymentId: req.body.razorpayPaymentId,
    razorpaySignature: req.body.razorpaySignature,
  });

  res.status(200).json({
    success: true,
    data,
  });
});

const postRazorpayWebhook = asyncHandler(async (req, res) => {
  const rawBody = Buffer.isBuffer(req.body)
    ? req.body
    : Buffer.from(JSON.stringify(req.body || {}));

  const signatureHeader = req.headers["x-razorpay-signature"];
  const eventIdHeader = req.headers["x-razorpay-event-id"];

  const signature = Array.isArray(signatureHeader)
    ? signatureHeader[0]
    : signatureHeader;
  const eventId = Array.isArray(eventIdHeader)
    ? eventIdHeader[0]
    : eventIdHeader;

  const data = await processWebhookEvent({
    rawBody,
    signature,
    eventId,
  });

  res.status(200).json({
    success: true,
    data,
  });
});

module.exports = {
  getRazorpayConfig,
  postCreateOrder,
  postVerifyPayment,
  postRazorpayWebhook,
};
