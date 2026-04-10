const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");
const { env } = require("./env");

let initialized = false;

function initializeFirebase() {
  if (initialized) {
    return admin;
  }

  if (admin.apps.length) {
    initialized = true;
    return admin;
  }

  if (env.firebaseServiceAccountPath) {
    const absolutePath = path.resolve(
      process.cwd(),
      env.firebaseServiceAccountPath,
    );
    const serviceAccount = JSON.parse(fs.readFileSync(absolutePath, "utf8"));
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: env.firebaseProjectId || serviceAccount.project_id,
    });
  } else {
    admin.initializeApp({
      projectId: env.firebaseProjectId || undefined,
    });
  }

  initialized = true;
  return admin;
}

module.exports = { initializeFirebase };
