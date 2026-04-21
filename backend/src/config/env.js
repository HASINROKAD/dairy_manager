const path = require("path");
const dotenv = require("dotenv");

dotenv.config({
  path: process.env.ENV_FILE
    ? path.resolve(process.cwd(), process.env.ENV_FILE)
    : path.resolve(process.cwd(), ".env"),
});

const env = {
  nodeEnv: process.env.NODE_ENV || "development",
  port: Number(process.env.PORT || 5000),
  host: process.env.HOST || "0.0.0.0",
  mongoUri: process.env.MONGO_URI || "",
  firebaseServiceAccountPath: process.env.FIREBASE_SERVICE_ACCOUNT_PATH || "",
  firebaseProjectId: process.env.FIREBASE_PROJECT_ID || "",
  geocodeUserAgent:
    process.env.GEOCODE_USER_AGENT ||
    "dairy-manager/1.0 (contact: email not provided)",
  allowRoleSwitch: process.env.ALLOW_ROLE_SWITCH === "true",
  razorpayKeyId: process.env.RAZORPAY_KEY_ID || "",
  razorpayKeySecret: process.env.RAZORPAY_KEY_SECRET || "",
  razorpayWebhookSecret: process.env.RAZORPAY_WEBHOOK_SECRET || "",
  authCheckTokenRevoked: process.env.AUTH_CHECK_TOKEN_REVOKED === "true",
  authVerifyCacheTtlMs: Number(process.env.AUTH_VERIFY_CACHE_TTL_MS || 15000),
  attachUserCacheTtlMs: Number(process.env.ATTACH_USER_CACHE_TTL_MS || 15000),
  roadRouteEnabled: process.env.ROAD_ROUTE_ENABLED === "true",
};

module.exports = { env };
