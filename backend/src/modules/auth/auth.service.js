const { UserModel } = require("../user/user.model");

async function syncUserFromFirebase(authContext) {
  const firebaseUid = authContext.firebaseUid;

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

    return { user: existing, createdNow: false };
  }

  const user = await UserModel.create({
    firebaseUid,
    ...baseData,
    profileCompleted: false,
  });

  return { user, createdNow: true };
}

module.exports = { syncUserFromFirebase };
