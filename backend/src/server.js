const { app } = require("./app");
const { env } = require("./config/env");
const { connectDb } = require("./config/db");
const { initializeFirebase } = require("./config/firebase");
const os = require("os");

function getLocalNetworkIp() {
  const interfaces = os.networkInterfaces();

  for (const ifaceList of Object.values(interfaces)) {
    if (!ifaceList) continue;

    for (const iface of ifaceList) {
      const isIpv4 = iface.family === "IPv4";
      if (isIpv4 && !iface.internal) {
        return iface.address;
      }
    }
  }

  return null;
}

async function bootstrap() {
  try {
    initializeFirebase();
    await connectDb();

    app.listen(env.port, env.host, () => {
      const localIp = getLocalNetworkIp();
      const hostForDisplay = env.host === "0.0.0.0" ? "localhost" : env.host;
      const localUrl = `http://${hostForDisplay}:${env.port}`;
      const networkUrl = localIp ? `http://${localIp}:${env.port}` : null;

      console.log(`Backend server running on ${env.host}:${env.port}`);
      console.log(`Local:   ${localUrl}`);
      if (networkUrl) {
        console.log(`Network: ${networkUrl}`);
      }
    });
  } catch (error) {
    console.error("Failed to start server:", error);
    process.exit(1);
  }
}

bootstrap();
