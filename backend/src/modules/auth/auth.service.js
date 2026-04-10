const { UserModel } = require("../user/user.model");
const { initializeFirebase } = require("../../config/firebase");

async function ensureRoleClaim(firebaseUid, role) {
  if (!role) {
    return false;
  }

  const admin = initializeFirebase();
  await admin.auth().setCustomUserClaims(firebaseUid, { role });
  return true;
}

async function syncUserFromFirebase(authContext) {
  const firebaseUid = authContext.firebaseUid;
  const tokenRole = authContext.token?.role;

  const baseData = {
    email: authContext.email || "",
    mobileNumber: authContext.phoneNumber || "",
  };

  const existing = await UserModel.findOne({ firebaseUid });
  if (existing) {
    existing.email = baseData.email || existing.email;
    if (!existing.mobileNumber && baseData.mobileNumber) {
      existing.mobileNumber = baseData.mobileNumber;
    }
    await existing.save();

    const roleClaimUpdated =
      !!existing.role && tokenRole !== existing.role
        ? await ensureRoleClaim(firebaseUid, existing.role)
        : false;

    return { user: existing, createdNow: false, roleClaimUpdated };
  }

  const user = await UserModel.create({
    firebaseUid,
    ...baseData,
    profileCompleted: false,
  });

  return { user, createdNow: true, roleClaimUpdated: false };
}

module.exports = { syncUserFromFirebase };
