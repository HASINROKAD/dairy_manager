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
  mongoUri: process.env.MONGO_URI || "Mongo DB connection string not found",
  firebaseServiceAccountPath:
    process.env.FIREBASE_SERVICE_ACCOUNT_PATH ||
    "Firebase service account path not found",
  firebaseProjectId:
    process.env.FIREBASE_PROJECT_ID || "Firebase project ID not found",
  geocodeUserAgent:
    process.env.GEOCODE_USER_AGENT ||
    "dairy-manager/1.0 (contact: email not provided)",
  allowRoleSwitch: process.env.ALLOW_ROLE_SWITCH === "true",
};

module.exports = { env };
