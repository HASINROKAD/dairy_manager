const express = require("express");

const { authenticate } = require("../../middleware/authenticate");
const { attachUser } = require("../../middleware/attachUser");
const {
  getRazorpayConfig,
  postCreateOrder,
  postVerifyPayment,
  postRazorpayWebhook,
} = require("./payment.controller");

const paymentRouter = express.Router();

paymentRouter.post("/payments/webhook", postRazorpayWebhook);

paymentRouter.use(authenticate, attachUser);
paymentRouter.get("/payments/config", getRazorpayConfig);
paymentRouter.post("/payments/orders", postCreateOrder);
paymentRouter.post("/payments/verify", postVerifyPayment);

module.exports = { paymentRouter };
