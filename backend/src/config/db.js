const mongoose = require("mongoose");
const { env } = require("./env");

async function connectDb() {
  if (!env.mongoUri) {
    throw new Error("Missing MONGO_URI in environment.");
  }

  await mongoose.connect(env.mongoUri, {
    autoIndex: true,
  });
  console.log("Connected to MongoDB database.");
}

module.exports = { connectDb };
