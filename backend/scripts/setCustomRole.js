const path = require("path");

const { initializeFirebase } = require("../src/config/firebase");

async function main() {
  const uid = process.argv[2];
  const role = process.argv[3];

  if (!uid || !role || !["seller", "customer"].includes(role)) {
    console.error(
      "Usage: node scripts/setCustomRole.js <firebaseUid> <seller|customer>",
    );
    process.exit(1);
  }

  const admin = initializeFirebase();
  await admin.auth().setCustomUserClaims(uid, { role });

  console.log(`Set custom claim role=${role} for uid=${uid}`);
  console.log(
    "Ask the user to re-login or force token refresh so new role appears in ID token.",
  );
}

main().catch((error) => {
  console.error("Failed to set custom claim:", error.message);
  process.exit(1);
});
