const { app } = require("./app");
const { env } = require("./config/env");
const { connectDb } = require("./config/db");
const { initializeFirebase } = require("./config/firebase");

async function bootstrap() {
  try {
    initializeFirebase();
    await connectDb();

    app.listen(env.port, () => {
      console.log(`Backend server running on port ${env.port}`);
    });
  } catch (error) {
    console.error("Failed to start server:", error);
    process.exit(1);
  }
}

bootstrap();
