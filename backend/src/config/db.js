const mongoose = require("mongoose");
const { env } = require("./env");

async function connectDb() {
  if (!env.mongoUri) {
    throw new Error("Missing MONGO_URI in environment.");
  }

  const isProduction = env.nodeEnv === "production";

  await mongoose.connect(env.mongoUri, {
    autoIndex: !isProduction,
    maxPoolSize: 20,
    minPoolSize: isProduction ? 5 : 1,
    serverSelectionTimeoutMS: 5000,
    socketTimeoutMS: 45000,
  });
  console.log("Connected to MongoDB database.");
}

module.exports = { connectDb };
