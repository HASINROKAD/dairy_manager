const { UserModel } = require("../user/user.model");
const { initializeFirebase } = require("../../config/firebase");

/**
 * Updates Firebase custom claims asynchronously without blocking the response.
 * This prevents timeout issues on slow Firebase operations.
 */
async function updateFirebaseClaimsAsync(firebaseUid, role) {
  if (!role) {
    return;
  }

  try {
    const admin = initializeFirebase();
    // Fire and forget - don't await this operation
    // This prevents blocking the login response on slow Firebase operations
    admin
      .auth()
      .setCustomUserClaims(firebaseUid, { role })
      .catch((error) => {
        console.error(
          `Failed to update Firebase claims for ${firebaseUid}:`,
          error.message,
        );
        // Log but don't throw - this is a background operation
      });
  } catch (error) {
    console.error(
      `Error updating Firebase claims for ${firebaseUid}:`,
      error.message,
    );
    // Silently fail - don't block the user login
  }
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
    const nextEmail = baseData.email || existing.email;
    let needsSave = false;

    if (nextEmail !== existing.email) {
      existing.email = nextEmail;
      needsSave = true;
    }

    if (!existing.mobileNumber && baseData.mobileNumber) {
      existing.mobileNumber = baseData.mobileNumber;
      needsSave = true;
    }

    if (needsSave) {
      await existing.save();
    }

    // Update Firebase claims asynchronously without blocking the response
    if (existing.role && tokenRole !== existing.role) {
      updateFirebaseClaimsAsync(firebaseUid, existing.role);
    }

    return { user: existing, createdNow: false, roleClaimUpdated: false };
  }

  const user = await UserModel.create({
    firebaseUid,
    ...baseData,
    profileCompleted: false,
  });

  return { user, createdNow: true, roleClaimUpdated: false };
}

module.exports = { syncUserFromFirebase };
